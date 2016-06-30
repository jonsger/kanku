package OpenStack::API;

use Moose;
use JSON::XS;
use HTTP::Request;
use LWP::UserAgent;
use Data::Dumper;

use OpenStack::API::Cinder;
use OpenStack::API::EC2;
use OpenStack::API::Glance;
use OpenStack::API::Nova;
use OpenStack::API::Quantum;
use OpenStack::API::Neutron;

has os_auth_url => (
  is	  => 'rw',
  isa	  => 'Str',
  default => $ENV{OS_AUTH_URL} || '',
);

has os_tenant_name => (
  is	  => 'rw',
  isa	  => 'Str',
  default => $ENV{OS_TENANT_NAME} || '',
);

has os_username => (
  is	  => 'rw',
  isa	  => 'Str',
  default => $ENV{OS_USERNAME} || '',
);

has os_password => (
  is	  => 'rw',
  isa	  => 'Str',
  default => $ENV{OS_PASSWORD} || '',
);

has __access => (
  is	  => 'rw',
  isa	  => 'HashRef',
);

has __api_versions => (
  is	  => 'ro',
  isa	  => 'HashRef',
  default => sub  {
    {
      '2.0' => {
	tokens_url => 'tokens'
      },
      '3' => {
	tokens_url => 'auth/tokens'
      }
    }
  }

);

has os_auth_api_version => (
  is	  => 'rw',
  isa	  => 'Str',
  lazy	  => 1,
  default => sub {
    $_[0]->os_auth_url =~ m#/v([0-9\.]+)/$#;
    return $1 || "2.0"
  }
);

sub tokens_url {
  my ($self) = @_;
  return $self->__api_versions->{$self->os_auth_api_version}->{tokens_url};
}

# curl -X POST $OS_AUTH_URL/tokens  -H "Content-Type: application/json"   -d '{"auth": {"tenantName": "'"$OS_TENANT_NAME"'", "passwordCredentials": {"username": "'"$OS_USERNAME"'", "password": "'"$OS_PASSWORD"'"}}}'
sub authenticate {
  my ($self) = @_;


  die "No os_auth_url given\n" unless $self->os_auth_url;

  my $uri	= $self->os_auth_url.$self->tokens_url;
  my $ua	= LWP::UserAgent->new();
  my $content	= $self->_auth_json_string;
  my $response  = $ua->post($uri,'Content-Type' => 'application/json', 'Content' => $content); 

  if (! $response->is_success) {
    die "Error while accessing uri '$uri'\n"
      . $response->status_line . "\n";
  }

  my $json = decode_json($response->decoded_content);

  $self->__access($json->{access});

  return $self->__access->{'token'}->{'id'}
}

sub _auth_json_string {
  my ($self) = @_;

  my $struct = {
    auth => {
      tenantName	  => $self->os_tenant_name,
      passwordCredentials => {
	username  => $self->os_username,
	password  => $self->os_password,
      }
    }
  };

  return encode_json($struct);

}

sub service {
  my ($self,$key,$value) = @_;

  $self->authenticate if (! $self->__access );

  my @service = grep { $_->{$key} eq $value } @{$self->__access->{serviceCatalog}};

  die "Cannot find service with $key is $value!" if (! @service);
  die "Ambiguous result for service with $key is $value!" if (@service > 1);

  my $mod = "OpenStack::API::" . ucfirst($service[0]->{name});
#print "$mod -> new\n";
  return $mod->new(%{$service[0]},access => $self);

}

1;
