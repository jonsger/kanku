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
use Path::Class qw/dir file/;
use feature 'say';
use Data::Dumper;
use File::Copy;
use Try::Tiny;
use Archive::Cpio;
extends 'Kanku::Handler::HTTPDownload';

with 'Kanku::Roles::Handler';
with 'Kanku::Roles::Logger';

has ['vm_image_file','url'] => (is=>'rw',isa=>'Str');
has ['use_cache','offline'] => (is=>'rw',isa=>'Bool',default=>0);
has ['cache_dir'] => (is=>'rw',isa=>'Str');

sub distributable { 1 }

sub prepare {
  my $self = shift;
  my $ctx  = $self->job()->context();

  $self->offline(1)   if ($ctx->{offline});
  $self->use_cache(1) if ($ctx->{use_cache});
  $self->cache_dir($ctx->{cache_dir}) if ($ctx->{cache_dir});

  return {
    state => 'succeed',
    message => "Preparation finished successfully"
  };
}

sub execute {
  my $self   = shift;
  my $ctx    = $self->job()->context();
  my $logger = $self->logger;

  if ( $self->offline ) {
    return $self->get_from_history();
  }

  if (! $self->url ) {
    if ( $ctx->{vm_image_url} ) {
      $self->url($ctx->{vm_image_url});
    } elsif ( $ctx->{obs_direct_url} ) {
      $self->url($ctx->{obs_direct_url});
    } else {
      die "Neither vm_image_url nor obs_direct_url found in context"
    }
  }

  my $curl =  Kanku::Util::CurlHttpDownload->new(url => $self->url);

  $curl->output_file($self->_calc_output_file());

  if ( $self->use_cache ) {
    $ctx->{use_cache} = 1;
    $curl->use_cache(1);
    if ( $self->cache_dir ) {
      $curl->cache_dir(Path::Class::Dir->new($self->cache_dir));
    } else {
      $ctx->{cache_dir} |= $curl->cache_dir();
    }
  } else {
    $curl->use_temp_file(1);
  }

  $logger->debug("Using output file: ".$curl->output_file);

  $ctx->{vm_image_file} = $curl->output_file;
  
  my $tmp_file;

  try {
    $logger->debug(" - use_cache: ".$curl->use_cache);
    $tmp_file = $curl->download();
  } catch {
    my $e = $_;

    die $e if ( $e !~ /'404'$/);
    die $e if ( ! $ctx->{obs_direct_url} );

    $logger->warn("Failed to download: ".$curl->url);

    $logger->debug("obs_direct_url = $ctx->{obs_direct_url}");
    $curl->url($ctx->{obs_direct_url});
  
    $curl->output_file($self->_calc_output_file($ctx->{public_api}));

    $logger->info("Trying alternate url ".$curl->url);

    if (! $ctx->{public_api} ) {
      $curl->username($ctx->{obs_username}) if $ctx->{obs_username};
      $curl->password($ctx->{obs_password}) if $ctx->{obs_password};
    }
    $tmp_file = $curl->download();


    if ($ctx->{public_api} ) {
      my $cpio = Archive::Cpio->new;
      my $out_file = file(file($tmp_file)->parent, $ctx->{obs_filename})->stringify;

      $logger->debug("extracting from $tmp_file to $out_file");

      open(INFILE,  '<',$tmp_file) || die "Could not open $tmp_file: $!";
      open(OUTFILE, '>',$out_file) || die "Could not open $out_file: $!";
      $cpio->read_with_handler(\*INFILE,
        sub {
          my ($e) = @_;
          if ($e->name eq $ctx->{obs_filename}) {
            print OUTFILE $e->get_content;
          }
        }
      );
      close INFILE  || die "Could not close $tmp_file: $!";
      close OUTFILE || die "Could not close $out_file: $!";
      unlink($tmp_file);
      $tmp_file = $out_file;
      $ctx->{vm_image_file} = $ctx->{obs_filename};
    }
  };

  push(
    @{$ctx->{"Kanku::Handler::FileMove"}->{files_to_move}},
    [$tmp_file,$ctx->{vm_image_file}]
  );

  $self->update_history($tmp_file);

  return {
    state => 'succeed',
    message => "Sucessfully downloaded image to $tmp_file"
  };
}

sub _calc_output_file {
  my ($self,$use_public_api) = shift;
  my $ctx                    = $self->job()->context();
  my $output_file;

  $self->logger->trace("job->context:\n".Dumper($ctx));
  if ($use_public_api) {
    $output_file = $ctx->{obs_project}."-".$ctx->{obs_package} . '.cpio';
  } elsif ( $self->use_cache ) {
    $output_file =  $self->url;
    $output_file =~ s#.*/(.*)$#$1#;
  } else {
    # TODO: this is hardcoded and only quick and dirty
    # should be more flexible
    # needs introduction of a file suffix which is set by OBSCheck
    for my $var (qw/images_dir domain_name/) {
      if (! $ctx->{$var} ) {
      	die "Variable $var not set in job context.".
	  " Please check your job configuration.\n"
      }
    }

    $output_file =  $ctx->{images_dir}."/".$ctx->{domain_name}.".qcow2";
  }

  return $output_file;
}

sub update_history {
  my $self = shift;

  my $rs = $self->schema->resultset('ImageDownloadHistory')->update_or_create(
    {
      vm_image_url    => $self->url,
      vm_image_file   => shift,
      download_time   => time()
    },
    { key => 'primary' }
  );

}

sub get_from_history {
  my $self = shift;
  my $ctx = $self->job->context;

  my $rs = $self->schema->resultset('ImageDownloadHistory')->find(
    {
      vm_image_url    => $self->url,
    }
  );

  die "Could not find result for vm_image_url: $ctx->{vm_image_url}\n" unless $rs;


  $ctx->{use_cache} = 1;
  $ctx->{vm_image_file} |= $rs->vm_image_file;

  return {
    state => 'succeed',
    message => "Sucessfully found vm_image_file '$ctx->{vm_image_file}' in database"
  };

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

  domain_name

=head2 setters

  vm_image_file

=head1 DEFAULTS

NONE

=cut
