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
package Kanku::Handler::ImageDownload;

use Moose;
use Kanku::Util::CurlHttpDownload;
use feature 'say';
use Data::Dumper;

extends 'Kanku::Handler::HTTPDownload';

with 'Kanku::Roles::Handler';
with 'Kanku::Roles::Logger';

has ['vm_image_file','url'] => (is=>'rw',isa=>'Str');
has ['use_cache','offline'] => (is=>'rw',isa=>'Bool',default=>0);

sub prepare {
  my $self = shift;
  my $ctx  = $self->job()->context();


  $self->offline(1)   if ($ctx->{offline});
  $self->use_cache(1) if ($ctx->{use_cache});

  return {
    state => 'succeed',
    message => "Preparation finished successfully"
  };
}
sub execute {
  my $self = shift;
  my $ctx  = $self->job()->context();

  if ( $ctx->{vm_image_url} ) {
    $self->url($ctx->{vm_image_url});
  }

  my $curl =  Kanku::Util::CurlHttpDownload->new(
                url           => $self->url,
              );

  $curl->output_file($self->_calc_output_file());

  if ( $self->offline ) {
    $self->use_cache(1);
    $curl->offline(1);
  }

  if ( $self->use_cache ) {
    $ctx->{use_cache} = 1;
    $curl->use_cache(1);
  } else {
    $curl->use_temp_file(1);
  }

  $self->logger->debug("Using output file: ".$curl->output_file);
  
  $ctx->{vm_image_file} = $curl->output_file;

  my $tmp_file = $curl->download();

  push(
    @{$ctx->{"Kanku::Handler::FileMove"}->{files_to_move}},
    [$tmp_file,$ctx->{vm_image_file}]
  );

  return {
    state => 'succeed',
    message => "Sucessfully downloaded image to $tmp_file"
  };
}

sub _calc_output_file {
  my $self        = shift;
  my $ctx         = $self->job()->context();
  my $output_file;
  if ( $self->use_cache ) {
    $output_file =  $self->url;
    $output_file =~ s#.*/(.*)$#$1#;
  } else {
    # TODO: this is hardcoded and only quick and dirty
    # should be more flexible
    # needs introduction of a file suffix which is set by OBSCheck
    $output_file =  $ctx->{vm_image_dir}."/".$ctx->{domain_name}.".qcow2";
  } 
  
  return $output_file;
}

1;

__END__

=head1 NAME

Kanku::Handler::ImageDownload

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

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

  vm_image_dir

  domain_name

=head2 setters

  vm_image_file

=head1 DEFAULTS

NONE

=cut
