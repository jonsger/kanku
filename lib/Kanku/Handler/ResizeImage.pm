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
package Kanku::Handler::ResizeImage;

use Moose;
use Kanku::Config;
use Kanku::Util::VM;
use Kanku::Util::VM::Image;
use Kanku::Util::IPTables;

use Path::Class::File;
use Data::Dumper;

with 'Kanku::Roles::Handler';

has [qw/
      vm_image_file
      disk_size
/] => (is => 'rw',isa=>'Str');

=head1 disk_size

new size of disk in GB

=cut

has 'disk_size'         => ( is => 'rw',isa => 'Str' );


has gui_config => (
  is => 'ro',
  isa => 'ArrayRef',
  lazy => 1,
  default => sub {
      [
        {
          param => 'disk_size',
          type  => 'text',
          label => 'New disk size'
        },
      ];
  }
);
has "+distributable" => ( default => 0 );

sub execute {
  my $self = shift;
  my $ctx  = $self->job->context();
  
  if ( $ctx->{use_cache} ) {
    $self->vm_image_file(Path::Class::File->new($ctx->{cache_dir},$ctx->{vm_image_file})->stringify);
  } else {
    $self->vm_image_file($ctx->{vm_image_file});
  }



  if ( $self->vm_image_file =~ /\.qcow2$/ ) {
    if ( $self->disk_size ) {
	my $img  = $self->vm_image_file;
        my $size = $self->disk_size; 
        `qemu-img resize $img $size`
    }
  } else {
    die "Image file has wrong suffix '".$self->vm_image_file."'.\nOnly qcow2 supported at the moment!\n";
  } 

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
    "echo $hostname > /etc/hostname",
    "hostname $hostname",
  );

}

sub _create_image_file_from_cache {
  my $self = shift;
  my $ctx  = $self->job()->context();

  my $suffix2format = {
     qcow2 => 'qcow2',
     raw   => 'raw',
     img   => 'img'
  };

  my $final_file;
  my $in = Path::Class::File->new($self->cache_dir,$ctx->{vm_image_file});
  if ( $ctx->{vm_image_file} =~ /\.(qcow2|raw|img)(\.(gz|bz2|xz))?$/ ) {
    my $vol_name = $self->domain_name .".$1";

    $self->_root_disk(
      Kanku::Util::VM::Image->new(
	format		=> $suffix2format->{$1},
	vol_name 	=> $vol_name,
	source_file 	=> $in->stringify,
	final_size	=> $self->root_disk_size || 0
      )
    );

    $self->logger->info("Uploading $in via libvirt to $vol_name");

    $final_file = $self->_root_disk->create_volume()->get_path();

    $self->logger->info(" -- final file $final_file");

  } else {

    die "Unknown extension for disk file ".$ctx->{vm_image_file}."\n";

  }

  return $final_file;
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
      api_url: https://api.opensuse.org
      ....

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

    memory                : memory in KB to be used by VM

    vcpu                  : number of cpus for VM

    use_9p                : create a share folder between host and guest using 9p

    cache_dir		  : set directory for caching images

    mnt_dir_9p		  : set diretory to mount current working directory in vm. Only used if use_9p is set to true. (default: '/tmp/kanku')

    noauto_9p		  : set noauto option for 9p directory in fstab.

    root_disk_size        : define size of root disk - ONLY FOR RAW IMAGES


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

