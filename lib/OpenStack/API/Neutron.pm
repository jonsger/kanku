package OpenStack::API::Neutron;

use Moose;
with 'OpenStack::API::Role::Service';
with 'OpenStack::API::Role::Client';

use Carp;
use JSON::XS;

sub floating_ip_list {
  my ($self,%filters) = @_;

  my $filter_string = "";

  if ( %filters ) {
    my @parts;
    while ( my ($k,$v) = each(%filters) ) { push @parts, "$k=$v" }
    $filter_string = "?" .join('&',@parts);
  }

  my $uri = $self->endpoint->{publicURL}."/v2.0/floatingips$filter_string";

  $self->get($uri)->{floatingips};
}




1;
__END__
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
