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
package Kanku::Util::CurlHttpDownload;

use Moose;
use Data::Dumper;
use HTTP::Request;
use Template;
use LWP::UserAgent;
use File::Temp qw/ :mktemp /;
use File::Copy;
use Path::Class::File;
use Path::Class::Dir;
use Kanku::Config;

with 'Kanku::Roles::Logger';

use feature 'say';

# http://download.opensuse.org/repositories/OBS:/Server:/Unstable/images/
#


has output_dir => (
  is        => 'rw',
  isa       => 'Str',
);

has output_file => (
  is        => 'rw',
  isa       => 'Str',
);

has url => (
  is        =>'rw',
  isa       =>'Str',
  required  => 1
);

has use_temp_file => (
  is        =>'rw',
  isa       =>'Bool',
  default   => 0
);

has [ qw/use_cache use_temp_file offline/ ] => (
  is        =>'rw',
  isa       =>'Bool',
  default   => 0
);

has cache_dir => (
  is        =>'rw',
  isa       =>'Object',
  lazy      => 1,
  default   => sub { Path::Class::Dir->new($ENV{HOME},".kanku","cache") }
);

sub download {
  my $self  = shift;
  my $url   = $self->url;


  my $file  = undef;

  if ( $self->output_file ) {
    if ( $self->output_dir ) {
      $self->logger("ATTENTION: You have set output_dir _and_ output_file - output_file will be preferred");
    }
    if ( $self->use_cache ) {
      $file = Path::Class::File->new($self->cache_dir,$self->output_file);
    } else {
      $file = Path::Class::File->new($self->output_file);
    }
  }
  elsif ( $self->output_dir )
  {
    # combine filename from url with output_dir
    my $od = $self->output_dir;
    die "output_dir is not an absolute path" if ( $od !~ /^\// );
    my @parts = split(/\//,$url);
    my $fn    = pop @parts;
    my @od_parts = split(/\//,$od);
    $file     = Path::Class::File->new('/',@od_parts,$fn);
  }
  else
  {
    die "Neither output_dir nor output_file given";
  }

  $| = 1;  # autoflush

  if ( $self->use_temp_file ) {
      $file = Path::Class::File->new(mktemp($file->stringify."-XXXXXXXX"));
  };

  ( -d $file->parent ) || $file->parent->mkpath;

  if ( $self->offline ) {
    $self->logger->warn("Skipping download from $url in offline mode");
  } else {
      $self->logger->debug("Downloading $url");
      $self->logger->debug("  to file ".$file->stringify);

      my $ua    = LWP::UserAgent->new();

      my $res = $ua->mirror ($url, $file->stringify);

      if ( $res->code == 200 ) {
        $self->logger->debug("  download succeed");
      } elsif ( $res->code == 304 ) {
        $self->logger->debug("  skipped download because file not modified");
      } else {
        die "Download failed from $url: '".$res->code."'\n";
      }
  }

  my $user = Kanku::Config->instance->config()->{qemu}->{user} || 'qemu';

  my ($login,$pass,$uid,$gid) = getpwnam($user)
        or die "$user not in passwd file";

  chown $uid, $gid, $file->stringify;

  return $file->stringify;
}

__PACKAGE__->meta->make_immutable;

1;
