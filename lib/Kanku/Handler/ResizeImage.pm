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
use Path::Class::File;
use Data::Dumper;

with 'Kanku::Roles::Handler';

has [qw/
      vm_image_file
      disk_size
/] => (is => 'rw',isa=>'Str');

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

sub distributable { 1 }

sub execute {
  my $self = shift;
  my $ctx  = $self->job->context();
  my ($img,$size);

  if ( $ctx->{use_cache} ) {
    $self->vm_image_file(Path::Class::File->new($ctx->{cache_dir},$ctx->{vm_image_file})->stringify);
  } else {
    $self->vm_image_file($ctx->{vm_image_file});
  }

  if ( $self->vm_image_file =~ /\.qcow2$/ ) {
    if ( $self->disk_size ) {
	$img  = $self->vm_image_file;
	$size = $self->disk_size;
        `qemu-img resize $img $size`
    }
  } else {
    die "Image file has wrong suffix '".$self->vm_image_file."'.\nOnly qcow2 supported at the moment!\n";
  }

  return "Sucessfully resized image '$img' to $size"
}

1;

__END__

=head1 NAME

Kanku::Handler::ResizeImage

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::ResizeImage
    options:
      disk_size: 100GB

=head1 DESCRIPTION

This handler resizes a downloaded qcow2 image to a given size using 'qemu-img'

=head1 OPTIONS

    disk_size      : new size of disk in GB

=head1 CONTEXT

=head2 getters

 cache_dir

 vm_image_file

=head2 setters

=head1 DEFAULTS

=cut
