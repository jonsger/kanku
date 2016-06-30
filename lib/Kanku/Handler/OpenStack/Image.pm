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
package Kanku::Handler::OpenStack::Image;

use Moose;
use Data::Dumper;
use OpenStack::API;
use URI;
use File::Basename;

with 'Kanku::Roles::Handler';
with 'Kanku::Roles::Logger';

has [qw/import_from_format/ ] => (is=>'rw',isa=>'Str',required => 1);
has [qw/image_properties/ ] => (is=>'rw',isa=>'HashRef',required => 1);

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

  die "No obs_project set!\n"			      unless $ctx->{obs_project};
  die "No obs_package set!\n"			      unless $ctx->{obs_package};
  die "No container_format set in image_properties\n" unless $self->image_properties->{container_format};
  die "No disk_format set in image_properties\n"      unless $self->image_properties->{disk_format};

  return {
    state => 'succeed',
    message => "Preparation finished successfully"
  };
}

sub execute {
  my $self = shift;
  my $ctx  = $self->job()->context();

  my $osa = $self->osa;
  my $images = $osa->service(type => 'image');

  unshift (@{$self->image_properties->{tags}},'kanku');
  $self->image_properties->{name} = "Kanku/".$ctx->{obs_project}."/".$ctx->{obs_package};
  $self->image_properties->{description} = $self->get_filename();

  my $response;

  $response = $images->image_list( name => $self->image_properties->{name} );

  if (@{$response}) {
    $self->logger->debug(Dumper($response));
    my @images2check;
    foreach my $img (@{$response}) {
      my $arr_my  = join("\0", sort @{$self->image_properties->{tags}});
      my $arr_got = join("\0", sort @{$img->{tags}});

      if ( $arr_my eq $arr_got ) {
	$self->logger->debug("Checking for description " . $self->image_properties->{description} . ". Got: $img->{description}");
	if ($img->{description} eq $self->image_properties->{description}) {
	  $ctx->{os_image_id} = $img->{id};
	  return {
	    state => 'succeed',
	    message => "Found already uploaded image " . $img->{description}
	  };
	}
      } else {
	$self->logger->debug("Deleting image with id $img->{id}");
	$images->image_delete($img->{id});
      }
    }
  }

  my %data = (
    import_from		=>	$self->import_from,
    import_from_format	=>	$self->import_from_format,
    image_properties	=>	$self->image_properties
  );

  $response = $images->task_create_image_import(%data);

  $ctx->{os_image_import_task_id} = $response->{id};

  return {
    state => 'succeed',
    message => "Sucessfully created image import task with id $response->{id}"
  };
}

sub finalize {
  my ($self) = @_;

  my $ctx     = $self->job()->context();
  my $images  = $self->osa->service(type => 'image');
  my $task_id = $ctx->{os_image_import_task_id} ;
  my $logger  = $self->logger;
  my $delay   = 10;

  if ( $task_id ) {
    while (1) {
      my $task = $images->task_detail($task_id);

      die "Got no task details\n" unless $task; 
      
      if ( $task->{status} eq 'success' ) {
	 $ctx->{os_image_id} = $task->{result}->{image_id};
	 last;
      }

      die $task->{message} if ( $task->{status} eq 'failure' );
      print ".";
      sleep($delay);
    }
  }

  if ( $ctx->{os_image_id} ) {
    my $img_id = $ctx->{os_image_id};
    while (1) {
      my $img = $images->image_detail($img_id);
      last if ( $img->{status} eq 'active');
      sleep($delay);
    }
  }

  return {
    state => 'succeed',
    message => "Image with id $ctx->{os_image_id} in status active now"
  };
}

sub get_filename {
  my ($self) = @_;

  my $uri = URI->new($self->import_from);
  basename($uri->path);
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
