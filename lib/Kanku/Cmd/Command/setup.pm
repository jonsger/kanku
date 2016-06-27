# Copyright (c) 2016 SUSE LLC
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
package Kanku::Cmd::Command::setup;

use Moose;
use Template;
use FindBin;
use Path::Class qw/file dir/;
use FindBin;
use File::HomeDir;
use Term::ReadKey;
use Template;
use Kanku::Schema;
use Cwd;
use DBIx::Class::Migration;

extends qw(MooseX::App::Cmd::Command);
with "Kanku::Cmd::Roles::Schema";

has server => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'Run setup in server mode',
);

has devel => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'Run setup in developer mode',
);

has user => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'User who will be running kanku',
);

has images_dir => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'directory where vm images will be stored',
    default       => "/var/lib/libvirt/images"
);

has apiurl => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'url to your obs api',
);

has osc_user => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'login user for obs api',
);

has osc_pass => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'login password obs api',
);

has dsn => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'dsn for global database',
    default       => sub {
      # dbi:SQLite:dbname=/home/frank/Projects/kanku/share/kanku-schema.db
      return "dbi:SQLite:dbname=".$_[0]->_dbfile;
    }
);

has _dbfile => (
	isa 	=> 'Str',
	is  	=> 'rw',
	lazy	=> 1,
	default => sub { $_[0]->homedir."/.kanku/kanku-schema.db" }
);

has homedir => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'home directory for user',
    lazy          => 1,
    default       => sub {
      # dbi:SQLite:dbname=/home/frank/Projects/kanku/share/kanku-schema.db
      return File::HomeDir->users_home($ENV{SUDO_USER});
    }
);

has logger => (
  isa   => 'Object',
  is    => 'rw',
  lazy  => 1,
  default => sub { Log::Log4perl->get_logger }
);

sub abstract { "Setup local environment to work as server or developer mode." }

sub description { "
Setup local environment to work as server or developer mode.
Installation wizard which asks you several questions,
how to configure your machine.

";
}

sub execute {
  my $self    = shift;
  my $logger  = $self->logger;

  # effective user id
  if ( $> != 0 ) {
    $logger->fatal("Please start setup as root");
    exit 1;
  }


  ### Get information
  # ask for mode
  $self->_ask_for_install_mode() if ( ! $self->devel and ! $self->server );

  # ask for user
  $self->_ask_for_user if ( ! $self->user );

  #
  ###


  ### Running selected mode
  #

  $self->_execute_server_setup() if ($self->server );

  $self->_execute_devel_setup() if ($self->devel );

  #
  ###
}

sub _execute_server_setup {
  my $self    = shift;
  my $logger  = $self->logger;

  $logger->debug("Running server setup");

}

sub _execute_devel_setup {
  my $self    = shift;
  my $logger  = $self->logger;

  $logger->debug("Running developer setup");

  $self->_create_local_settings_dir();

  $self->_set_sudoers();

  $self->_chown_images_dir();

  $self->_configure_libvirtd_access();

  $self->_setup_database();

  $self->_modify_path_in_bashrc();

  $self->_create_osc_rc();
  #system("osc api about");

  # add user to group libvirt
  system("usermod -G libvirt ".$self->user);

  # enable libvirtd
  system("chkconfig libvirtd on");

  # start and set autostart for default network
  system("virsh net-autostart default 1>/dev/null");

  die if $?;

  $logger->info("Setup successfully finished!");
  $logger->info("Please reboot to make sure, libvirtd is coming up properly");  

}

sub _create_osc_rc {
  my $self  = shift;
  my $rc	= file($self->homedir,".oscrc");

  return if ( -f $rc );

  if ( ! $self->apiurl ) {
     my $default = "https://api.opensuse.org";
     print "Please enter the apiurl of your obs server [$default]\n";
     my $read = <STDIN>;
     chomp($read);
     $self->apiurl($read || $default);
  }

  while ( ! $self->osc_user ) {

     print "Please enter your login user for obs server:\n";
     my $read = <STDIN>;
     chomp($read);
     $self->osc_user($read || '');
   
  }

  while ( ! $self->osc_pass ) {

     print "Please enter your password for obs server:\n";
     ReadMode('noecho');
     my $read = <STDIN>;
     chomp($read);

     ReadMode(0);
     print "Please repeat your password\n";
     ReadMode('noecho');
     my $read2 = <STDIN>;
     chomp($read2);
     ReadMode(0);

     $self->osc_pass($read || '') if ( $read eq $read2 );
   
  }


  my $rc_txt = "[general]
apiurl = ".$self->apiurl."

[".$self->apiurl."]
user = ".$self->osc_user."
pass = ".$self->osc_pass."
";

  $rc->spew($rc_txt);
  
  $self->_chown($rc);

}

sub _modify_path_in_bashrc {
  my $self	= shift;
  my $rc 	= file($self->homedir,".bashrc");
  my @lines = $rc->slurp;
  my $found = 0;

 
  foreach my $line (@lines) { 
    if ( $line =~ m#^\s*(export\s)?\s*PATH=.*$FindBin::Bin# ) { 
      $found = 1 
    }
  }
 
  if ( ! $found ) {
  	$self->logger->debug("modifying " . $rc->stringify);
    push(@lines,"export PATH=$FindBin::Bin\:\$PATH\n");
  	$rc->spew(\@lines); 
  }

}

sub _setup_database {
  my $self = shift;

  my $base_dir = dir($FindBin::Bin)->parent;

  my $config = {
    INCLUDE_PATH => $FindBin::Bin."/../etc/templates/cmd/",
    INTERPOLATE  => 1,               # expand "$var" in plain text
  };

  # create Template object
  my $template  = Template->new($config);

  # define template variables for replacement
  my $vars = {
    dsn		  => $self->dsn,
    start_tag     => '[%',
    end_tag       => '%]'
  };

  my $output = '';
  my $cfg_file = "$FindBin::Bin/../config.yml";

  # process input template, substituting variables
  $template->process('setup.config.yml.tt2', $vars, $cfg_file)
               || die $template->error()->as_string();

  $self->logger->info("Created config file $cfg_file");

  # prepare database setup
  my $migration = DBIx::Class::Migration->new(
    schema_class   => 'Kanku::Schema',
    schema_args	   => [$self->dsn],
    target_dir	   => "$FindBin::Bin/../share"
  );

  # setup database if needed
  $migration->install_if_needed(
    default_fixture_sets => ['all_tables']
  );

  $self->_chown($self->_dbfile);

}

sub _configure_libvirtd_access {
  my $self    = shift;
  my $logger  = $self->logger;

  my $user = $self->user;

  my $conf = file("/etc/libvirt/qemu.conf");

  $logger->debug("Setting user ".$user." in ". $conf->stringify);

  my @lines = $conf->slurp;

  foreach my $line ( splice(@lines) ) {
    $line =~ s/^#?(user\s*=\s*).*/$1"$user"/;
    push(@lines,$line);
  }

  $conf->spew(\@lines);

  my $dconf = file("/etc/libvirt/libvirtd.conf");

  $logger->debug("Setting user ".$user." in ". $conf->stringify);

  @lines = $dconf->slurp;
  my $defaults = {
    unix_sock_group	    => 'libvirt',
    unix_sock_ro_perms	    => '0777',
    unix_sock_rw_perms	    => '0770',
    unix_sock_admin_perms   => '0700',
    auth_unix_ro	    => 'none',
    auth_unix_rw	    => 'none'
  };
  my $seen={};
  foreach my $line ( splice(@lines) ) {
    if ( $line =~ s/^#?((unix_sock_group|unix_sock_ro_perms|unix_sock_rw_perms|unix_sock_admin_perms|auth_unix_ro|auth_unix_rw).*)/$1/ ) {
      $seen->{$2} = 1;
    }
    push(@lines,$line);
  }

  for my $key (keys(%{$defaults})) {
    push(@lines,"$key = \"$defaults->{$key}\"\n") unless $seen->{$key};
  }

  $dconf->spew(\@lines);

  system("service libvirtd restart");

  return undef;
}

sub _setup_local_schema {
  my $self    = shift;
  my $logger  = $self->logger;

  $logger->warn("_setup_local_schema not implemented yet");

  return undef;
}

sub _chown_images_dir {
  my $self    = shift;
  my $logger  = $self->logger;

  $logger->info("Changing ownership of ".$self->images_dir." to user ". $self->user);

  my ($login,$pass,$uid,$gid) = getpwnam($self->user)
        or die $self->user." not in passwd file\n";

  $self->_chown($self->images_dir);

  return undef;
}

sub _ask_for_user {
  my $self = shift;

  while ( ! $self->user ) {

    print "Please enter the username of the user who will run kanku [".($ENV{SUDO_USER} || '')."]\n";

    my $answer = <STDIN>;
    chomp($answer);

    $self->user( $answer || $ENV{SUDO_USER} );
  }

  return undef;
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

sub _ask_for_install_mode {
  my $self  = shift;

  print "
Please select installation mode :

(1) server

(2) devel

(9) Quit setup
";

  while (1) {
    my $answer = <STDIN>;
    chomp($answer);
    exit 0 if ( $answer == 99 );

    if ( $answer == 1 ) {
      $self->server(1);
      last;
    }

    if ( $answer == 2 ) {
      $self->devel(1);
      last;
    }

  }

}

sub _create_local_settings_dir {
  my $self = shift;

  my $dir  = dir($self->homedir,".kanku");

  (-d $dir ) || $dir->mkpath();

  $self->_chown($dir);
}

sub _chown {
  my  $self = shift;

  my ($login,$pass,$uid,$gid) = getpwnam($self->user)
        or die $self->user." not in passwd file\n";

  while (my $fn = shift(@_)) {
    
    chown $uid, $gid, $fn;

  }
}

__PACKAGE__->meta->make_immutable();

1;
