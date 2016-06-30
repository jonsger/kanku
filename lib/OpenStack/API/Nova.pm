package OpenStack::API::Nova;

use Moose;
with 'OpenStack::API::Role::Service';
with 'OpenStack::API::Role::Client';

use Carp;
use Data::Dumper;
use JSON::XS;

sub instance_list {
  my ($self,%filters) = @_;

  my $filter_string = "";

  if ( %filters ) {
    my @parts;
    while ( my ($k,$v) = each(%filters) ) { push @parts, "$k=$v" }
    $filter_string = "?" .join('&',@parts);
  }

  my $uri = $self->endpoint->{publicURL}."/servers$filter_string";

  $self->get($uri)->{servers};
}

sub instance_detail {
  my ($self,$id) = @_;

  die "Got no id\n" unless $id;

  my $uri = $self->endpoint->{publicURL}."/servers/$id";

  $self->get($uri)->{server};
}

sub instance_delete {
  my ($self,$id) = @_;

  my $uri = $self->endpoint->{publicURL}."/servers/$id";

  $self->delete($uri);
}

sub instance_create {
  my ($self,$data) = @_;

  die "Got no data\n" unless $data;

  my $json = encode_json({server => $data});

  my $uri = $self->endpoint->{publicURL}."/servers";

  $self->post($uri,{},$json);
}

sub instance_add_floating_ip {
  my ($self,$server_id,$ip) = @_;
#  EQ: curl -g -i -X POST https://dashboard.p1.cloud.suse.de:8774/v2.1/9c2adc08a22d46b0a0291cd82b2519d7/servers/5d3458c6-fe96-48f5-a040-2360c6b53535/action -H "User-Agent: python-novaclient" -H "Content-Type: application/json" -H "Accept: application/json" -H "X-Auth-Token: {SHA1}0f759e28d0375794ba6a843a9bfdba3d87280312" -d '{"addFloatingIp": {"address": "10.162.162.38"}}'

  die "Got no server_id\n" unless $server_id;
  die "Got no ip address\n" unless $ip;
  #
  my $json = encode_json({addFloatingIp=>{address=>$ip}});

  my $uri = $self->endpoint->{publicURL}."/servers/$server_id/action";

  $self->post($uri,{},$json);

}


1;

