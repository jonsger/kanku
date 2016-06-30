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
package Kanku::Handler::OpenStack::CreateInstance;

use Moose;
use Data::Dumper;
use OpenStack::API;
use URI;
use File::Basename;
use MIME::Base64;

with 'Kanku::Roles::Handler';
with 'Kanku::Roles::Logger';

has [qw/name  availability_zone key_name floating_network_id/]	  => ( is => 'rw', isa => 'Str');
has [qw/min_count max_count flavorRef/]	  => ( is => 'rw', isa => 'Int', default => 1 );
has [qw/networks security_groups/]	  => ( is => 'rw', isa => 'ArrayRef' );

has [qw/os_auth_url os_tenant_name os_username os_password import_from/ ] => (
  is	  => 'rw',
  isa	  => 'Str',
);

has osa => ( 
  is	  => 'rw',
  isa	  => 'Object',
  lazy	  => 1,
  default => sub { OpenStack::API->new() }
);

sub prepare {
  my $self = shift;
  my $ctx  = $self->job()->context();

  $self->import_from($ctx->{vm_image_url}) if ( $ctx->{vm_image_url} && ! $self->import_from());

  die "No import_from set\n" if ( ! $self->import_from );

  my $osa = $self->osa;

  $osa->os_auth_url($self->os_auth_url)	      if $self->os_auth_url;
  $osa->os_username($self->os_username)	      if $self->os_username;
  $osa->os_password($self->os_password)	      if $self->os_password;
  $osa->os_tenant_name($self->os_tenant_name) if $self->os_tenant_name;

  $self->name($ctx->{os_instance_name})	      if $ctx->{os_instance_name};

  die "No name for instance set!\n" unless $self->name;
#  die "No container_format set in image_properties\n" unless $self->image_properties->{container_format};
#  die "No disk_format set in image_properties\n"      unless $self->image_properties->{disk_format};

  return {
    state => 'succeed',
    message => "Preparation finished successfully"
  };
}

sub execute {
  my $self = shift;
  my $ctx  = $self->job()->context();

  my $osa = $self->osa;
  my $servers = $osa->service(name => 'nova');

  my $script = <<EOF
#!/bin/bash

systemctl enable sshd.service

systemctl start sshd.service

EOF
;
  # mandatory parameters
  my $data = {
    name              => $self->name,
    min_count	      => $self->min_count,
    max_count	      => $self->max_count,
    flavorRef	      => $self->flavorRef,
    imageRef	      => $ctx->{os_image_id},
    user_data	      => encode_base64($script),
  };

  # optional parameters
  $data->{key_name}	      = $self->key_name		  if $self->key_name;
  $data->{networks}	      = $self->networks		  if $self->networks;
  $data->{security_groups}    = $self->security_groups	  if $self->security_groups;
  $data->{availability_zone}  = $self->availability_zone  if $self->availability_zone;
  

  my $response = $servers->instance_create($data);

  $ctx->{os_instance_id} = $response->{server}->{id};

  return {
    state => 'succeed',
    message => "Sucessfully created new instance named " . $self->name
  };
}

sub finalize {
  my ($self) = @_;

  my $ctx	= $self->job()->context();
  my $nova	= $self->osa->service(name => 'nova');
  my $server_id	= $ctx->{os_instance_id};

  my $delay   = 10;
  my $status  = '';
#
  if ( $server_id ) {
    while (1) {
      my $instance = $nova->instance_detail($server_id);

      die "Got no task details\n" unless $instance; 

      $status = $instance->{status};
      last if ( $status eq 'ACTIVE' );

      sleep($delay);
    }
  } else {
    die "No server id found in job context";
  }

  if ( $self->floating_network_id ) {
    my $neutron	= $self->osa->service(name => 'neutron');

    my $list = $neutron->floating_ip_list(
      'floating_network_id' => $self->floating_network_id,
      'status'              => 'DOWN'
    );
    
    die "Could not find a free floating ip address\n" unless (@$list);

    my $ip = $list->[0]->{floating_ip_address};
    $self->logger->debug("Found free floating ip address");
    $nova->instance_add_floating_ip($server_id,$ip);
    $ctx->{ipaddress} = $ip;
  }

  return {
    state => 'succeed',
    message => "Instance with id $server_id in status $status now"
  };
}

1;

__END__

=head1 NAME

Kanku::Handler::OpenStack::Image
=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile
FIXME: This has to be updated
  -
    use_module: Kanku::Handler::ImageDownload
    options:
      use_cache: 1
      url: http://example.com/path/to/image.qcow2
      output_file: /tmp/mydomain.qcow2


=head1 DESCRIPTION

This handler downloads a file from a given url to the local filesystem and sets vm_image_file.

=head1 OPTIONS

  url             : url to download file from

  vm_image_file   : absolute path to file where image will be store in local filesystem

  offline         : proceed in offline mode ( skip download and set use_cache in context)

  use_cache       : use cached files in users cache directory

=head1 CONTEXT

=head2 getters

  vm_image_url

  domain_name

=head2 setters

  vm_image_file

=head1 DEFAULTS

NONE

=cut
