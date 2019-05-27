package OpenStack::API::Glance;

use Moose;
with 'OpenStack::API::Role::Service';
with 'OpenStack::API::Role::Client';

use Carp;
use JSON::XS;

sub image_list {
  my ($self,%filters) = @_;

  my $filter_string = "";

  if ( %filters ) {
    my @parts;
    while ( my ($k,$v) = each(%filters) ) { push @parts, "$k=$v" }
    $filter_string = "?" .join('&',@parts);
  }

  my $uri = $self->endpoint->{publicURL}."/v2/images$filter_string";

  $self->get($uri)->{images};
}

sub image_detail {
  my ($self,$id) = @_;

  my $uri = $self->endpoint->{publicURL}."/v2/images/$id";

  $self->get($uri);
}

sub image_delete {
  my ($self,$id) = @_;

  confess "No image id given\n" unless $id;

  my $uri = $self->endpoint->{publicURL}."/v2/images/$id";

  $self->delete($uri);
}

sub task_list {
  my ($self,%filters) = @_;

  my $filter_string = "";

  if ( %filters ) {
    my @parts;
    while ( my ($k,$v) = each(%filters) ) { push @parts, "$k=$v" }
    $filter_string = "?" .join('&',@parts);
  }

  my $uri = $self->endpoint->{publicURL}."/v2/tasks$filter_string";

  $self->get($uri);
}

sub task_detail {
  my ($self,$id) = @_;

  my $uri = $self->endpoint->{publicURL}."/v2/tasks/$id";

  $self->get($uri);
}

sub task_create_image_import {
  my ($self,%input) = @_;

# { "type": "import",
#   "input": {
#      "import_from": "swift://cloud.foo/myaccount/mycontainer/path",
#      "import_from_format": "qcow2",
#      "image_properties" : {
#          "name": "GreatStack 1.22",
#          "tags": ["lamp", "custom"]
#       }
#    }
# }

  my $uri = $self->endpoint->{publicURL}."/v2/tasks";

  my $data = {
	type 	=> 'import',
	input 	=> \%input,
  };
  my $json = encode_json($data);

  $self->post($uri,{},$json);
}


sub schemas_tasks_list {
  my ($self,%data) = @_;
  my $uri = $self->endpoint->{publicURL}."/v2/schemas/tasks";

  $self->get($uri);
}

1;
