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

has query_delay => (is => 'rw', isa => 'Int' , default => 10);

has [qw/os_auth_url os_tenant_name os_username os_password/ ] => (
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

  my $osa = $self->osa;

  $osa->os_auth_url($self->os_auth_url)	      if $self->os_auth_url;
  $osa->os_username($self->os_username)	      if $self->os_username;
  $osa->os_password($self->os_password)	      if $self->os_password;
  $osa->os_tenant_name($self->os_tenant_name) if $self->os_tenant_name;

  $self->name($ctx->{os_instance_name})	      if ( $ctx->{os_instance_name} && ! $self->name );

  die "No name for instance set!\n" unless $self->name;

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

  # mandatory parameters
  my $data = {
    name              => $self->name,
    min_count	      => $self->min_count,
    max_count	      => $self->max_count,
    flavorRef	      => $self->flavorRef,
    imageRef	      => $ctx->{os_image_id},
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

  my $status  = '';

  if ( $server_id ) {
    while (1) {
      my $instance = $nova->instance_detail($server_id);

      die "Got no task details\n" unless $instance;

      $status = $instance->{status};
      last if ( $status eq 'ACTIVE' );

      sleep($self->query_delay);
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

Kanku::Handler::OpenStack::CreateInstance

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile
  -
    use_module: Kanku::Handler::OpenStack::CreateInstance
    options:
      networks:
        -
          uuid: 8cce38fd-443f-4b87-8ea5-ad2dc184064f
      security_groups:
        -
          name: kanku
      flavorRef: 5
      key_name: admin
      floating_network_id: 0d00a5bd-d07c-4206-b87d-807ca98b44b4
      availability_zone: nova

=head1 DESCRIPTION

This handler creates a new server instance in openstack. It uses the image from $job->context->{os_image_id}

=head1 OPTIONS


=head1 CONTEXT

=head2 getters

  os_instance_name

  os_image_id

  os_instance_id

=head2 setters

  ipaddress: only set if floating_network_id is given


=head1 DEFAULTS

NONE

=cut
