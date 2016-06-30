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
package Kanku::Handler::OpenStack::RemoveInstance;

use Moose;
use Data::Dumper;
use OpenStack::API;
use URI;
use File::Basename;

with 'Kanku::Roles::Handler';
with 'Kanku::Roles::Logger';

has [qw/name/]		  => ( is => 'rw', isa => 'Str');

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

  my $list = $servers->instance_list(name => $self->name);

  for my $instance (@$list) {
    $servers->instance_delete($instance->{id});
  }

  return {
    state => 'succeed',
    message => "Sucessfully removed new instance named " . $self->name
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
