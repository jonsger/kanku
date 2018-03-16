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
package Kanku::Handler::CreateDomain;

use Moose;
use Try::Tiny;
use IO::Uncompress::AnyUncompress qw(anyuncompress $AnyUncompressError) ;
use File::Copy qw/copy/;
use Path::Class::File;
use Data::Dumper;

use Kanku::Config;
use Kanku::Util::VM;
use Kanku::Util::VM::Image;
use Kanku::Util::IPTables;

with 'Kanku::Roles::Handler';

has [qw/
      domain_name           vm_image_file
      login_user            login_pass
      images_dir            ipaddress
      management_interface  management_network
      forward_port_list     images_dir
      short_hostname	    memory
      network_name          network_bridge
/] => (is => 'rw',isa=>'Str');

has '+memory'         => ( default => 1024*1024 );

has '+management_interface' => ( default => '');

has '+management_network'   => ( default => '');

has [qw/vcpu/] => (is => 'rw',isa=>'Int');

has '+vcpu'           => ( default => 1 );

has [qw/
        use_9p
        skip_network
        skip_login
/]                    => (is => 'rw',isa=>'Bool',default=>0);

has "+images_dir"     => (default=>"/var/lib/libvirt/images");

has ['cache_dir']     => (is=>'rw',isa=>'Str');

has ['mnt_dir_9p']    => (is => 'rw', isa => 'Str', default => '/tmp/kanku');

has ['host_dir_9p']    => (is => 'rw', isa => 'Str');

has [qw/
  noauto_9p
  wait_for_systemd
/]                    => (is => 'rw', isa => 'Bool');

has ['_root_disk']    => (is => 'rw', isa => 'Object');

has 'root_disk_size'  => (is => 'rw', isa => 'Int');

has empty_disks => (
  is => 'rw',
  isa => 'ArrayRef',
  lazy => 1,
  default => sub {[]}
);

has additional_disks => (
  is => 'rw',
  isa => 'ArrayRef',
  lazy => 1,
  default => sub {[]}
);

has gui_config => (
  is => 'ro',
  isa => 'ArrayRef',
  lazy => 1,
  default => sub {
      [
        {
          param => 'forward_port_list',
          type  => 'text',
          label => 'List of Forwarded Ports'
        },
        {
          param => 'network_name',
          type  => 'text',
          label => 'Name of libvirt network'
        },
        {
          param => 'network_bridge',
          type  => 'text',
          label => 'Name of network bridge'
        },
      ];
  }
);

has installation => (
  is      => 'rw',
  isa     => 'ArrayRef',
  lazy    => 1,
  default => sub { [] }
);

sub distributable { 1 };

sub prepare {
  my $self = shift;
  my $ctx  = $self->job()->context();

  $self->domain_name($ctx->{domain_name}) if ( ! $self->domain_name && $ctx->{domain_name});
  $self->login_user($ctx->{login_user})   if ( ! $self->login_user  && $ctx->{login_user});
  $self->login_pass($ctx->{login_pass})   if ( ! $self->login_pass  && $ctx->{login_pass});
  $self->cache_dir($ctx->{cache_dir})     if ($ctx->{cache_dir});

  return {
    code    => 0,
    message => "Nothing todo"
  };
}

sub execute {
  my $self = shift;
  my $ctx  = $self->job()->context();

  my $cfg  = Kanku::Config->instance()->config();

  my $mem;

  if ( $self->memory =~ /^\d+$/ ) {
    $mem = $self->memory;
  } elsif ( $self->memory =~ /^(\d+)([kKmMgG])[bB]?$/ ) {
    my $factor = lc($2);
    my $ft = {k => 1, m => 1024, g => 1024*1024};
    $mem = $1 * $ft->{$factor};
  } else {
    die "Option memory has wrong format! Allowed formats: INT[kKmMgG].\n";
  }

  $self->logger->debug("Using memory: '$mem'");

  if ( ! $self->network_name ) {
    $self->network_name($cfg->{'Kanku::Handler::CreateDomain'}->{name} || 'default'),
  }

  if ( ! $self->network_bridge ) {
    $self->network_bridge($cfg->{'Kanku::Handler::CreateDomain'}->{bridge} || 'virbr0'),
  }

  $self->logger->debug("additional_disks:".Dumper($self->additional_disks));


  my $final_file = $ctx->{vm_image_file};
  my $image;


  my $vol;
  ($vol, $image) = $self->_create_image_file_from_cache({file=>$final_file}, $self->root_disk_size, $self->domain_name);
  $final_file = $vol->get_path();
  for my $file(@{$self->additional_disks}) {
      my ($avol,$aimage) = $self->_create_image_file_from_cache($file);
      $self->logger->debug("additional_disk: - before: $file->{file}");
      $file->{file} = $avol->get_path();
      $self->logger->debug("additional_disk: - after: $file->{file}");
  }

  my $vm = Kanku::Util::VM->new(
      vcpu                  => $self->vcpu,
      memory                => $mem,
      domain_name           => $self->domain_name,
      images_dir            => $self->images_dir,
      login_user            => $self->login_user,
      login_pass            => $self->login_pass,
      use_9p                => $self->use_9p,
      management_interface  => $self->management_interface,
      management_network    => $self->management_network,
      empty_disks           => $self->empty_disks,
      additional_disks      => $self->additional_disks,
      job_id                => $self->job->id,
      network_name          => $self->network_name,
      image_file            => $final_file,
      root_disk             => $image
  );

  $vm->host_dir_9p($self->host_dir_9p) if ($self->host_dir_9p);

  if ( $ctx->{vm_template_file} ) {
    $vm->template_file($ctx->{vm_template_file});
  }

  $vm->create_domain();

  my $con = $vm->console();

  if (@{$self->installation}) {
    $self->_handle_installation($con);
  }

  if ($self->skip_login) {
    $con->wait_for_login_prompt;
  } else {
    $self->_prepare_vm_via_console($con, $vm);
  }

  return {
    code    => 0,
    message => "Create domain " . $self->domain_name ." (".( $ctx->{ipaddress} || 'no ip found' ).") successfully"
  };
}

sub _handle_installation {
  my ($self, $con) = @_;
  my $exp          = $con->_expect_object();
  my $logger       = $self->logger;

  $logger->debug("Handling installation");

  for my $step (@{$self->installation}) {
    my ($expect,$send) = ($step->{expect}, $step->{send});
    my $timeout = $step->{timeout} || 300;
    $logger->debug("Waiting for '$expect' on console (timeout: $timeout)");
    $exp->expect(
      $timeout,
      [ $expect =>
        sub {
          my $exp = shift;
          $logger->debug("SEEN '$expect' on console");
          if ($send) {
            $logger->debug("Sending '$send'");
            $exp->send($send);
          }
          if ($step->{send_enter}) {
            $logger->debug("Sending <enter>");
            $exp->send("\r");
          }
          if ($step->{send_ctrl_c}) {
            $logger->debug("Sending <CTRL>+C");
            $exp->send("\cC");
          }
        }
      ],
    );
    $exp->clear_accum();
  }
}


sub _prepare_vm_via_console {
  my ($self, $con, $vm) = @_;

  my $ctx    = $self->job()->context();
  my $logger = $self->logger;
  my $cfg    = Kanku::Config->instance()->config();

  $con->login();

  my $ip;
  my %opts = ();

  $self->_setup_9p($con);

  $self->_setup_hostname($con);

  # make sure that dhcp server gets updated
  if ( $self->management_interface ) {
    $con->cmd(
      "ifdown " . $self->management_interface,
      "ifup " . $self->management_interface,
    );
  } else {
    $logger->warn("No management_interface set. Your dhcp-server will not get updated hostname");
  };


  if ( ! $self->skip_network ) {
    %opts = (mode => 'console') if $self->management_interface;

    $ip = $vm->get_ipaddress(%opts);
    die "Could not get ipaddress from VM" unless $ip;
    $ctx->{ipaddress} = $ip;

    if ( $self->forward_port_list ) {
	my $ipt = Kanku::Util::IPTables->new(
	  domain_name     => $self->domain_name,
	  host_interface  => $ctx->{host_interface},
	  guest_ipaddress => $ip,
	  iptables_chain  => $cfg->{'Kanku::Util::IPTables'}->{iptables_chain}
	);

	$ipt->add_forward_rules_for_domain(
	  start_port => $cfg->{'Kanku::Util::IPTables'}->{start_port},
	  forward_rules => [ split(/,/,$self->forward_port_list) ]
	);
    }

  }
  if ( $self->wait_for_systemd ) {
    $logger->info("Waiting for system to come up!");
    $con->cmd(
      'while [ "$s" != "No jobs running." ];do s=`systemctl list-jobs`;logger "systemctl list-jobs: $s";sleep 1;done'
    );
  }

  $con->logout();
}

sub _setup_9p {
  my ($self,$con) = @_;

  return if (! $self->use_9p);

  my $mp = $self->mnt_dir_9p;

  $con->cmd(
    "mkdir -p $mp",
    "echo \"kankushare $mp 9p trans=virtio,version=9p2000.L".( $self->noauto_9p && ',noauto')." 1 0\" >> /etc/fstab",
    "mount -a",
    "echo 'force_drivers+=\"9p 9pnet 9pnet_virtio\"' >> /etc/dracut.conf.d/98-kanku.conf",
    "dracut --force",
    # Be aware of the two spaces after delimiter
    'grub2-install `cut -f2 -d\  /boot/grub2/device.map |head`',
    'id kanku || { useradd -m -s /bin/bash kanku && { echo kanku:kankusho | chpasswd ; } ; echo "Added user"; }'
  );
}

sub _setup_hostname {
  my ($self,$con) = @_;
  my $hostname;

  if ($self->short_hostname) {
    $hostname = $self->short_hostname;
  } else {
    $hostname = $self->domain_name;
    $hostname =~ s/\./-DOT-/g;
  }

  # set hostname unique to avoid problems with duplicate in dhcp
  $con->cmd(
    "echo \"$hostname\" > /etc/hostname",
    "hostname \"$hostname\"",
  );

}

sub _create_image_file_from_cache {
  my $self       = shift;
  my $file_data  = shift;
  my $file       = $file_data->{file};
  my $size       = shift || 0;
  my $vol_prefix = shift;
  my $ctx  = $self->job()->context();
  my $image;
  my $vol;

  my $suffix2format = {
     qcow2    => 'qcow2',
     raw      => 'raw',
     img      => 'raw',
     vmdk     => 'vmdk',
     vhdfixed => 'raw',
     iso      => 'iso'
  };

  my $in = Path::Class::File->new($self->cache_dir,$file);
  if ( $file =~ /\.(qcow2|raw|img|vmdk|vhdfixed|iso)(\.(gz|bz2|xz))?$/ ) {
    my $vol_name = $file;

    $vol_name = $self->domain_name .".$1" if ($vol_prefix);

    $image =
      Kanku::Util::VM::Image->new(
	format		=> $suffix2format->{$1},
	vol_name 	=> $vol_name,
	source_file 	=> $in->stringify,
	final_size	=> $size
    );

    if ($file_data->{reuse}) {
      $self->logger->info("Uploading '$vol_name' skipped because of reuse flag");
      my $vm = Kanku::Util::VM->new();
      $vol = $vm->search_volume(name=>$vol_name);
      die "No volume with name '$vol_name' found" if ! $vol;
    } else {
      $self->logger->info("Uploading $in via libvirt to $vol_name");
      try {
        $vol = $image->create_volume();
      } catch {
        my $e = $_;
        $self->logger->error("Error while uploading $in to $vol_name");
        if ($e) {
          $self->logger->error($e->stringify);
          die $e->stringify;
        }
      };
    }
  } else {
    die "Unknown extension for disk file $file\n";
  }

  return ($vol, $image);
}
1;

__END__

=head1 NAME

Kanku::Handler::CreateDomain

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::CreateDomain
    options:
      domain_name: kanku-vm-1
      ....
      installation:
        -
          expect: Install
          send: yes
          send_enter: 1
        -
          expect: Next Step
          send_ctrl_c: 1

=head1 DESCRIPTION

This handler creates a new VM from the given template file and a qcow2 image file.

It will login into the VM and try to find out the ipaddress of the interface connected to the default route.

If configured a port_forward_list, it tries to find the next free port and configure a port forwarding with iptables.


=head1 OPTIONS


    domain_name           : name of domain to create

    vm_image_file         : file to qcow2 image to be used for domain

    login_user            : user to be used to login via console

    login_pass            : password to be used to login via console

    images_dir            : directory where the images can be found

    management_interface  :

    management_network    :

    forward_port_list     : list of ports to forward from host_interface`s IP to VM
                            DONT USE IN DISTRIBUTED ENV - SEE Kanku::Handler::PortForward

    memory                : memory in KB to be used by VM

    vcpu                  : number of cpus for VM

    use_9p                : create a share folder between host and guest using 9p

    cache_dir		  : set directory for caching images

    mnt_dir_9p		  : set diretory to mount current working directory in vm. Only used if use_9p is set to true. (default: '/tmp/kanku')

    noauto_9p		  : set noauto option for 9p directory in fstab.

    root_disk_size        : define size of root disk - ONLY FOR RAW IMAGES

    empty_disks           : Array of empty disks to be created

                            * name   - name of disk (required)

                            * size   - size of disk (required)

                            * pool   - name of pool (default: 'default')

                            * format - format of new disk (default: 'qcow2')

    installation          : array of expect commands for installation process


=head1 CONTEXT

=head2 getters

 domain_name

 login_user

 login_pass

 use_cache

 vm_template_file

 vm_image_file

 host_interface

 cache_dir

=head2 setters

 vm_image_file

 ipaddress

=head1 DEFAULTS

 images_dir     /var/lib/libvirt/images

 vcpu           1

 memory         1024 MB

 use_9p         0

 mnt_dir_9p	/tmp/kanku

=cut

