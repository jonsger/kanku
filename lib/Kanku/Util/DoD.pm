# Copyright (c) 2015 SUSE LLC
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
package Kanku::Util::DoD;

use Moose;
use Data::Dumper;
use HTTP::Request;
use Template;
use Net::OBS::Client::BuildResults;
use Net::OBS::Client::Project;
use Net::OBS::Client::Package;
use Kanku::Util::CurlHttpDownload;

with 'Kanku::Roles::Logger';

# http://download.opensuse.org/repositories/OBS:/Server:/Unstable/images/
#

has project => (
  is      => 'rw',
  isa     => 'Str',
);

has repository => (
  is      => 'rw',
  isa     => 'Str',
  default => 'images'
);

has arch => (
  is      => 'rw',
  isa     => 'Str',
  default => 'x86_64'
);

has package => (
  is      => 'rw',
  isa     => 'Str',
  default => ''
);

has images_dir => (
  is      => 'rw',
  isa     => 'Str',
  default => '/var/lib/libvirt/images'
);

has base_url => (
  is      => 'rw',
  isa     => 'Str',
  default => "http://download.opensuse.org/repositories/"
);

has download_url => (
  is      =>'rw',
  isa     =>'Str',
  lazy    => 1,
  default => sub {
    my $self = shift;

    my $prj = $self->project();
    $prj =~ s#:#:/#g;

    return $self->base_url . $prj . "/" . $self->repository . "/";
  }
);

has api_url => (
  is      =>'rw',
  isa     =>'Str',
  lazy    => 1,
  default => "https://api.opensuse.org"
);

has get_image_file_from_url_cb => (
  is      => 'rw',
  isa     => 'CodeRef',
);

has get_image_file_from_url => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  default => sub {
    my $self = shift;
    my $result = [];

    $self->get_image_file_from_url_cb(\&_sub_get_image_file_from_url_cb);

    my $build_results = Net::OBS::Client::BuildResults->new(
      project     => $self->project,
      repository  => $self->repository,
      arch        => $self->arch,
      package     => $self->package,
      apiurl      => $self->api_url,
      use_oscrc   => 1
    );
    my $record = $self->get_image_file_from_url_cb->($self,$build_results->binarylist());
    if ( $record ) {
      $record->{url} = $self->download_url . $record->{filename};
      if ( $self->api_url =~ /\/public\/?$/ ) {
        $record->{bin_url} = $self->api_url ."/build/".$self->project."/".$self->repository."/".$self->arch."/".$self->package."?view=cpio";
        $record->{public_api} = 1;
      } else {
	$record->{bin_url} = $self->api_url . "/build/".$self->project."/".$self->repository."/".$self->arch."/".$self->package."/".$record->{filename};
      }
      $record->{obs_username} = $build_results->user;
      $record->{obs_password} = $build_results->pass;
    }
    $self->logger->trace("\$record:\n".Dumper($record));
    return $record || {};
  }
);

has [qw/skip_all_checks skip_check_project skip_check_package use_cache/ ] => (is => 'ro', isa => 'Bool',default => 0 );

sub download {
  my $self  = shift;
  my $ua    = Net::OBS::Client->new(use_oscrc=>1,apiurl=>$self->api_url)->user_agent();
  my $fn    = $self->get_image_file_from_url()->{filename};
  my $url   = $self->download_url . $fn;
  my $file  = $self->images_dir() . "/" . $fn;

  $self->logger->debug(" -- state of skip_all_checks : ".$self->skip_all_checks);
  $self->logger->debug(" -- use_cache : ".$self->use_cache);


  if (! $self->use_cache ) {
    $self->check_before_download();
  }

  my $curl = Kanku::Util::CurlHttpDownload->new(
      url         => $url,
      output_file => $file,
      use_cache   => $self->use_cache
  );

  return $curl->download();

}

sub check_before_download {
  my $self = shift;

  return if ( $self->skip_all_checks() );
  unless ($self->skip_check_project()) {
      my $prj = Net::OBS::Client::Project->new(
          name     => $self->project,
          repository  => $self->repository,
          arch        => $self->arch,
          apiurl      => $self->api_url,
          use_oscrc   => 1,
      );

      if ( $prj->dirty or $prj->code ne 'published' ) {
        die "Project not ready yet\n";
      }
  }

  unless ($self->skip_check_package()) {
      my $pkg = Net::OBS::Client::Package->new(
          name        => $self->package,
          project     => $self->project,
          repository  => $self->repository,
          arch        => $self->arch,
          apiurl      => $self->api_url,
          use_oscrc   => 1
      );

      if ( $pkg->code ne 'succeeded' ) {
        die "Package not ready yet\n";
      }
  }

}

sub _sub_get_image_file_from_url_cb {
    my $self = shift;
    my $arg = shift;
    foreach my $bin (@$arg) {
      return $bin if $bin->{filename} =~ /\.(qcow2|raw|raw\.xz)$/
    }
}

__PACKAGE__->meta->make_immutable();

1;
