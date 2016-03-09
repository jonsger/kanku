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
package Kanku::Handler::HTTPDownload;

use Moose;
use Kanku::Util::CurlHttpDownload;
use feature 'say';
use Data::Dumper;
with 'Kanku::Roles::Handler';
with 'Kanku::Roles::Logger';

has dod_object => (
  is      =>'rw',
  isa     =>'Object',
  lazy    => 1,
  default => sub  {
    my $self = shift;
    Kanku::Util::CurlHttpDownload->new( url => $self->url );
  },
);

has ['url'] => (is=>'rw',isa=>'Str',required=>1);
has ['output_file','output_dir'] => (is=>'rw',isa=>'Str');

sub prepare {
  my $self = shift;

  my $dod  = $self->dod_object();

  $dod->logger($self->logger)           if $self->logger;
  $dod->output_dir($self->output_dir)   if $self->output_dir;
  $dod->output_file($self->output_file) if $self->output_file;


  # Don`t check for skipping if no last run found
  # or Job was triggered instead of scheduled
  # triggered jobs coming from external
  # and have higher priority
  return {
    code    => 0,
    message => "Preparation successful"
  };
}

sub execute {
  my $self = shift;
  my $dod  = $self->dod_object();


  my $file = $dod->download();

  die "Error while downloading $file " . $self->url if (! -f $file );

  $self->job()->context()->{vm_image_file} = $file;

  return {
    state => 'succeed',
    message => "Sucessfully downloaded image to $file"
  };
}

1;
