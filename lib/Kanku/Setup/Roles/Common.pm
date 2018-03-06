# Copyright (c) 2018 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
package Kanku::Setup::Roles::Common;

use Moose::Role;
use Path::Class qw/file/;
use Sys::Virt;
use IPC::Run qw/run timeout/;
use Path::Class qw/dir file/;

requires 'setup';

has _tt_config => (
  is => 'ro',
  isa => 'HashRef',
  lazy => 1,
  default => sub {
    {
      INCLUDE_PATH => $FindBin::Bin."/../etc/templates/cmd/setup",
      INTERPOLATE  => 1,               # expand "$var" in plain text
    }
  },
);  

has logger => (
  isa   => 'Object',
  is    => 'rw',
  lazy  => 1,
  default => sub { Log::Log4perl->get_logger }
);

has app_root => (
  isa   => 'Object',
  is    => 'rw',
  lazy  => 1,
  default => sub { dir($FindBin::Bin)->parent; }
);

has user => (
  isa   => 'Str|Undef',
  is    => 'rw',
);

has dsn => (
  isa   => 'Str',
  is    => 'rw',
  lazy  => 1,
  default => sub { "dbi:SQLite:dbname=".$_[0]->_dbfile }
);

has _devel => (
  isa   => 'Bool',
  is    => 'ro',
);

has _distributed => (
  isa     => 'Bool',
  is      => 'rw',
  lazy    => 1,
  default => 0
);


sub _configure_libvirtd_access {
  my ($self) = @_;
  my $logger        = $self->logger;

  $self->_configure_qemu_config if $self->_devel;

  my $dconf = file("/etc/libvirt/libvirtd.conf");

  my @lines = $dconf->slurp;
  my $defaults = {
    unix_sock_group         => 'libvirt',
    unix_sock_ro_perms      => '0777',
    unix_sock_rw_perms      => '0770',
    unix_sock_admin_perms   => '0700',
    auth_unix_ro            => 'none',
    auth_unix_rw            => 'none'
  };
  my $seen={};
  my $regex = "^#?((".join('|',keys(%$defaults)).").*)";
  foreach my $line ( splice(@lines) ) {
    if ( $line =~ s/$regex/$1/ ) {
      $seen->{$2} = 1;
    }
    push(@lines,$line);
  }

  for my $key (keys(%{$defaults})) {
    push(@lines,"$key = \"$defaults->{$key}\"\n") unless $seen->{$key};
  }

  $dconf->spew(\@lines);

  system("systemctl enable libvirtd");
  system("systemctl restart libvirtd");

  return undef;
}

sub _configure_qemu_config {
  my ($self) = @_;
  my $logger = $self->logger;
  my $user   = $self->user;

  my $conf = file("/etc/libvirt/qemu.conf");

  $logger->debug("Setting user ".$user." in ". $conf->stringify);

  my @lines = $conf->slurp;

  foreach my $line ( splice(@lines) ) {
    $line =~ s/^#?(user\s*=\s*).*/$1"$user"/;
    push(@lines,$line);
  }

  $conf->spew(\@lines);
}

sub _create_default_pool {
  my $self    = shift;
  my $logger  = $self->logger;
  my $vmm     = Sys::Virt->new(uri => 'qemu:///system');
  my @pools   = $vmm->list_storage_pools();

  for my $pool (@pools) {
    if ($pool->get_name eq 'default') {
      $logger->info("Found pool default - enabling autostart");
      $pool->set_autostart(1);
      return 1;
    }
  }

  $logger->info("No pool named 'default' found - creating");
  my $xml = file($self->_tt_config->{INCLUDE_PATH},"pool-default.xml")->slurp;
  my $pool = $vmm->define_storage_pool($xml);
  $pool->create();
  $pool->set_autostart(1);

}

sub _create_default_network {
  my $self     = shift;
  my $logger   = $self->logger;
  my $vmm      = Sys::Virt->new(uri => 'qemu:///system');
  my @networks = $vmm->list_all_networks;
  my $nn       = ($self->_distributed) ? 'kanku-ovs' : 'default';

  for my $net (@networks) {
    if ($net->get_name eq $nn) {
      $logger->info("Found network '$nn' - enabling autostart");
      $net->set_autostart(1) unless $net->get_autostart;
      $net->create() unless $net->is_active;
      return;
    }
  }

  my $ttf = "net-$nn.xml.tt2";
  $logger->info("No network named '$nn' found - creating using '$ttf'");
  my $sn = int(rand(255));
  my $xml = $self->_create_config_from_template($ttf, undef, {subnet=>$sn});
  my $net = $vmm->define_network($xml);
  $net->set_autostart(1);
  $net->create();
}

sub _create_config_from_template {
  my ($self, $tt_file, $cfg_file, $vars) = @_;
  my $template  = Template->new($self->_tt_config);
  my $output = '';

  # process input template, substituting variables
  if ($cfg_file) {
    $template->process($tt_file, $vars, $cfg_file)
               || die $template->error()->as_string();
    $self->logger->info("Created config file $cfg_file");
  } else {
    $template->process($tt_file, $vars, \$output)
               || die $template->error()->as_string();
    return $output;
  }

}

sub _run_system_cmd {
  my ($self, $cmd, @opts) = @_;
  my $logger = $self->logger;

  $logger->debug("Running command '$cmd @opts'");
  my ($in,$out,$err);
  run [$cmd, @opts] , \$in, \$out , $err;

  if ($?) {
    $logger->error("Execution of command failed: '".( $err || '' )."'");
  }

  return $?
}

sub _chown {
  my  $self = shift;

  my ($login,$pass,$uid,$gid) = getpwnam($self->user)
        or die $self->user." not in passwd file\n";

  while (my $fn = shift(@_)) {
    chown $uid, $gid, $fn;
  }
}

sub _set_sudoers {
  my $self          = shift;
  my $user          = $self->user;
  my $logger        = $self->logger;
  my $sudoers_file  = file("/etc/sudoers.d/kanku");

  $logger->info("Adding commands for user $user in " . $sudoers_file->stringify);

  $sudoers_file->spew("$user ALL=NOPASSWD: /usr/sbin/iptables, /bin/netstat\n");

  return undef;
}

sub _setup_database {
  my $self = shift;

  # create Template object
  my $template  = Template->new($self->_tt_config);

  # define template variables for replacement
  my $vars = {
    dsn           => $self->dsn,
    start_tag     => '[%',
    end_tag       => '%]'
  };

  my $output = '';
  my $cfg_file = "$FindBin::Bin/../config.yml";

  # process input template, substituting variables
  $template->process('config.yml.tt2', $vars, $cfg_file)
               || die $template->error()->as_string();

  $self->logger->info("Created config file $cfg_file");

  $self->logger->debug("Using dsn: ".$self->dsn);
  # prepare database setup
  my $migration = DBIx::Class::Migration->new(
    schema_class   => 'Kanku::Schema',
    schema_args    => [$self->dsn],
    target_dir     => "$FindBin::Bin/../share"
  );

  # setup database if needed
  $migration->install_if_needed(
    default_fixture_sets => ['install']
  );

  $self->_chown($self->_dbfile);

}

1;
