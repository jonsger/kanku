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

with 'Kanku::Roles::Logger';

use feature 'say';

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

has login_url => (
  is        => 'rw',
  isa       => 'Str',
  required  => 1,
  default   => sub { $_[0]->apiurl . "/rest/login.json" }
);

has logout_url => (
  is        => 'rw',
  isa       => 'Str',
  required  => 1,
  default   => sub { $_[0]->apiurl . "/rest/logout.json" }
);

has ua => (
  is        => 'rw',
  isa       => 'Object',
  default   => sub {
    return LWP::UserAgent->new(
        cookie_jar => $_[0]->cookie_jar,
        ssl_opts => {
          verify_hostname => 0, 
          SSL_verify_mode => 0x00
        }
    );
  }
);


sub login {
  my $self = shift;

  my $data = { username=>$self->user,password=>$self->password };
  my $content = encode_json($data);
  my $response = $self->ua->post( $self->login_url, Content => $content);

  if ($response->is_success) {
    my $result = decode_json($response->decoded_content);
    if ( $result->{authenticated} ) {
      $self->cookie_jar->extract_cookies($response);
      $self->cookie_jar->save("$ENV{'HOME'}/.kanku_cookiejar");
      return 1;
    } else {
      return 0;
    }
  } else {
     die $response->status_line;
  }

}

sub logout {
  my $self = shift;

  $self->ua->cookie_jar->load();

  if ( ! $self->session_valid ) {
    $self->logger->warn("No valid session found");
    $self->logger->warn("Could not proceed with logout");

    return 1;
  }

  my $request = HTTP::Request->new(GET => $self->logout_url);
  $self->cookie_jar->add_cookie_header( $request );

  my $response = $self->ua->request($request);

  if ($response->is_success) {
    unlink $self->_cookie_jar_file;
    return 1;
  } else {
     die $response->status_line;
  }

}

sub session_valid {
  my $self = shift;
  return 0 if ( ! -f $self->_cookie_jar_file );

  $self->ua->cookie_jar->load();

  my $request = HTTP::Request->new(POST => $self->login_url);
  $self->cookie_jar->add_cookie_header( $request );

  my $response = $self->ua->request($request);

  if ($response->is_success) {
    my $result = decode_json($response->decoded_content);
    return $result->{authenticated};
  } else {
     die $response->status_line;
  }

}

sub get_json {
  my $self = shift;
  my %opts = @_;

  die "No path given!\n" if ( ! $opts{path} );

  return 0 if ( ! -f $self->_cookie_jar_file );

  $self->ua->cookie_jar->load();

  my $url = $self->apiurl.'/rest/'. $opts{path} .".json";


  my $request = HTTP::Request->new(GET => $url);

  $self->cookie_jar->add_cookie_header( $request );

  
  $self->logger->debug("Sending reques to url: $url");
  $self->logger->debug("\n".$request->as_string);

  my $response = $self->ua->request($request);

  if ($response->is_success) {
    my $result = decode_json($response->decoded_content);
    return $result;
  } else {
     die $response->status_line ."\n";
  }

}

__PACKAGE__->meta->make_immutable;

1;
__END__
