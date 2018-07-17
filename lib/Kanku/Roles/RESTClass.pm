package Kanku::Roles::RESTClass;

use Moose::Role;
use Data::Dumper;

has schema => (
  is => 'ro',
  isa => 'Object',
);

has app => (
  is => 'ro',
  isa => 'Object',
);

has params => (
  is   => 'ro',
  isa  => 'HashRef',
  lazy => 1,
  default => sub { $_[0]->app->request->params },
);

has current_user => (
  is => 'ro',
  isa => 'HashRef',
);

sub has_role {
  my ($self, $role) = @_;
  return scalar grep { $role } keys %{$self->current_user->{role_id}};
}

sub log {    ## no critic (Subroutines::ProhibitBuiltinHomonyms)
  my ($self, $level, $msg) = @_;
  return $self->app->log($level, (ref $msg) ? Dumper($msg) : $msg);
}

1;
