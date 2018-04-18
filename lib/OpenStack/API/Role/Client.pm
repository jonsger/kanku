package OpenStack::API::Role::Client;

use Moose::Role;

use LWP::UserAgent;
use HTTP::Request;
use Data::Dumper;
use JSON::XS;

has ua => (
  is	  => 'rw',
  isa	  => 'Object',
  lazy	  => 1,
  default => sub { LWP::UserAgent->new() },
);

has token_id => (
  is	  => 'rw',
  isa	  => 'Str',
  lazy	  => 1,
  default => sub { $_[0]->access->authenticate}
);

has content_type => (
  is	  => 'rw',
  isa	  => 'Str',
  lazy	  => 1,
  default => 'application/json'
);

has access => (
  is	  => 'rw',
  isa	  => 'Object',
);

has __already_tried_authentication => (
  is	  => 'rw',
  isa	  => 'Bool',
  default => 0,
);


sub get	   { shift->request('GET',@_) }
sub put	   { shift->request('PUT',@_) }
sub post   { shift->request('POST',@_) }
sub delete { shift->request('DELETE',@_) }
sub patch  { shift->request('PATCH',@_) }

sub request {
  my ($self,$method,$uri,$header,$content) = @_;

  my @auth_header;


  if ( $self->token_id ) {
    if ( !  $self->__already_tried_authentication ) {
      #print "Using token:\n".$self->token_id."\n";
      $header = [
	%{$header || {}} ,
	'X-Auth-Token' => $self->token_id,
	'Content-Type' => $self->content_type,
	'Accept'=>$self->content_type
      ];
    }
  } else {
    #print "Using without token\n";
    $header = [%{$header || {}}];
  }

  my $request  = HTTP::Request->new($method,$uri,$header,$content);
  my $response = $self->ua->request($request);

  if (! $response->is_success ) {
    if ( $response->code == 401 ) {
      if ( ! $self->__already_tried_authentication ) {
	my $token_id = $self->access->authenticate;
	die "Could not authenticate\n" unless $token_id;
	$self->token_id($token_id);
	$self->__already_tried_authentication(1);
	return $self->request($method,$uri,$header,$content);
      } else {
	die "Error while accessing '$uri'\n" .
	  $response->status_line . "\n".
	  "Already tried authentication: " . $self->__already_tried_authentication . "\n";
      }
    } else {
      print Dumper($method,$uri,$header,$content);
      die "Error while accessing '$uri'\n".$response->status_line . "\n";
    }
  }

  if ( $self->content_type eq 'application/json' ) {
    my $content = $response->decoded_content;
    return decode_json($content) if ($content);
    return undef;
  } else {
    die "Unknown Content-Type: ".($self->content_type || '')."\nCannot decode";
  }
}

1;
