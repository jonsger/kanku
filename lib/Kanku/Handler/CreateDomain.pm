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
use Kanku::Config;
use Kanku::Util::VM;
use Kanku::Util::IPTables;

use IO::Uncompress::AnyUncompress qw(anyuncompress $AnyUncompressError) ;
use File::Copy qw/copy/;

use Data::Dumper;
with 'Kanku::Roles::Handler';

has [qw/
      domain_name           vm_image_file
      login_user            login_pass
      images_dir            ipaddress
      management_interface  management_network
      forward_port_list     images_dir
/] => (is => 'rw',isa=>'Str');

has [qw/memory vcpu/] => (is => 'rw',isa=>'Int');

has [qw/use_9p/] => (is => 'rw',isa=>'Bool');

has "+images_dir" => (default=>"/var/lib/libvirt/images");

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
      ];
  }
);

sub prepare {
  my $self = shift;
  my $ctx  = $self->job()->context();

  $self->domain_name($ctx->{domain_name}) if ( ! $self->domain_name && $ctx->{domain_name});
  $self->login_user($ctx->{login_user})   if ( ! $self->login_user  && $ctx->{login_user});
  $self->login_pass($ctx->{login_pass})   if ( ! $self->login_pass  && $ctx->{login_pass});

  return {
    code    => 0,
    message => "Nothing todo"
  };
}

sub execute {
  my $self = shift;
  my $ctx  = $self->job()->context();

  my $cfg  = Kanku::Config->instance()->config();

  my $vm = Kanku::Util::VM->new(
      vcpu                  => $self->vcpu                  || 1,
      memory                => $self->memory                || 1024 * 1024,
      domain_name           => $self->domain_name,
      images_dir            => $self->images_dir,
      login_user            => $self->login_user,
      login_pass            => $self->login_pass,
      use_9p                => $self->use_9p                || 0,
      management_interface  => $self->management_interface  || '',
      management_network    => $self->management_network    || ''
  );

  if ( $ctx->{use_cache} ) {
    my $final_file = $self->_create_image_file_from_cache();
    $ctx->{vm_image_file} = $final_file;
  }

  $vm->image_file($ctx->{vm_image_file});

  if ( $ctx->{vm_template_file} ) {
    $vm->template_file($ctx->{vm_template_file});
  }

  $vm->create_domain();

  my $con = $vm->console();

  $con->login();

  my $ip;
  my %opts = ();

  %opts = (mode => 'console') if $self->management_interface;

  $ip = $vm->get_ipaddress(%opts);
  die "Could not get ipaddress from VM" unless $ip;
  $ctx->{ipaddress} = $ip;

  if ($self->use_9p) {
    $con->cmd(
      "mkdir -p /tmp/kanku",
      'echo "kankushare /tmp/kanku 9p trans=virtio,version=9p2000.L 1 1" >> /etc/fstab',
      "mount -a"
    );
  }

  $con->logout();

  if ( $self->forward_port_list ) {
      my $ipt = Kanku::Util::IPTables->new(
        domain_name     => $self->domain_name,
        host_interface  => $ctx->{host_interface},
        guest_ipaddress => $ip
      );

      $ipt->add_forward_rules_for_domain(
        start_port => $cfg->{'Kanku::Util::IPTables'}->{start_port},
        forward_rules => [ split(/,/,$self->forward_port_list) ]
      );
  }


  return {
    code    => 0,
    message => "Create domain " . $self->domain_name ." ($ip) successfully"
  };
}

sub _create_image_file_from_cache {
  my $self = shift;
  my $ctx  = $self->job()->context();

    my $final_file;
    if ( $ctx->{vm_image_file} =~ /\.(qcow2|raw|img)\.(gz|bz2|xz)$/ ) {
      my $in = $ENV{HOME}."/.kanku/cache/". $ctx->{vm_image_file};
      $final_file = $self->images_dir . "/" . $self->domain_name .".$1";

      $self->logger->info("Uncompressing $in");
      $self->logger->info("  to $final_file");

      unlink $final_file;

      anyuncompress $in => $final_file
        or die "anyuncompress failed: $AnyUncompressError\n";;


    } elsif( $ctx->{vm_image_file} =~ /\.(qcow2|raw|img)$/ ) {
      my $in = $ENV{HOME}."/.kanku/cache/". $ctx->{vm_image_file};
      $final_file = $self->images_dir . "/" . $self->domain_name .".$1";

      $self->logger->info("Copying $in");
      $self->logger->info("  to $final_file");


      unlink $final_file;

      copy($in,$final_file) or die "Copy failed: $!\n";

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


=head1 CONTEXT

=head2 getters

 domain_name

 login_user

 login_pass

 use_cache

 vm_template_file

 vm_image_file

 host_interface

=head2 setters

 vm_image_file

 ipaddress

=head1 DEFAULTS

 images_dir     /var/lib/libvirt/images

 vcpu           1

 memory         1024 MB

 use_9p         0


=cut

