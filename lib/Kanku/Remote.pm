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
package Kanku::Remote;

use Moose;
use Data::Dumper;
use HTTP::Request;
use LWP::UserAgent;
use JSON::XS;
use HTTP::Cookies;
use HTTP::Request;
#use Template;
#use File::Temp qw/ :mktemp /;
#use File::Copy;
#use Path::Class::File;
#use Kanku::Config;

with 'Kanku::Roles::Logger';

use feature 'say';

# http://download.opensuse.org/repositories/OBS:/Server:/Unstable/images/
#


has apiurl => (
  is        => 'rw',
  isa       => 'Str',
  required  => 1
);

has user => (
  is        => 'rw',
  isa       => 'Str',
);

has password => (
  is        =>'rw',
  isa       =>'Str',
);

has cookie_jar => (
  is        =>'rw',
  isa       =>'Object',
  #required  => 1,
  lazy      => 1,
  default   => sub {
    return HTTP::Cookies->new(
      file            => $_[0]->_cookie_jar_file,
      autosave        => 1,
      ignore_discard  => 1,
    );

  }
);

has _cookie_jar_file => (
  is        =>'rw',
  isa       =>'Str',
  required  => 1,
  default   => "$ENV{'HOME'}/.kanku_cookiejar",
);

has url => (
  is        => 'rw',
  isa       => 'Str',
  required  => 1,
  default   => sub { $_[0]->apiurl . "/rest/login.json" }
);

sub login {
  my $self = shift;
  my $ua    = LWP::UserAgent->new();

  $ua->cookie_jar( $self->cookie_jar );

  $ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);

  my $data = { username=>$self->user,password=>$self->password };
  my $content = encode_json($data);
  my $response = $ua->post( $self->url, Content => $content);

  if ($response->is_success) {
    print $response->decoded_content;  # or whatever
    my $result = decode_json($response->decoded_content);
    if ( $result->{authenticated} ) {
      $self->cookie_jar->extract_cookies($response);
      $self->cookie_jar->save("$ENV{'HOME'}/.kanku_cookiejar");
      return 1;
    } else {
      $self->logger->error("Login failed!");;
      return 0;
    }
  } else {
     die $response->status_line;
  }

}


sub session_valid {
  my $self = shift;
  return 0 if ( ! -f $self->_cookie_jar_file );

  my $ua    = LWP::UserAgent->new();

  $ua->cookie_jar( $self->cookie_jar );

  $ua->cookie_jar->load();

  $ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);

  my $request = HTTP::Request->new(POST => $self->url);
  $self->cookie_jar->add_cookie_header( $request );

  my $response = $ua->request($request);

  if ($response->is_success) {
    my $result = decode_json($response->decoded_content);
    return $result->{authenticated};

  } else {
     die $response->status_line;
  }

}

__PACKAGE__->meta->make_immutable;

1;
__END__
sub download {
  my $self  = shift;
  my $url   = $self->url;


  my $file  = undef;

  if ( $self->output_file ) {
    if ( $self->output_dir ) {
      $self->logger("ATTENTION: You have set output_dir _and_ output_file - output_file will be preferred");
    }
    if ( $self->use_cache ) {
      $file = Path::Class::File->new($ENV{HOME},".kanku","cache",$self->output_file);
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
