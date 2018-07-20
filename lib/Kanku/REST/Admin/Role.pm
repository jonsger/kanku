package Kanku::REST::Admin::Role;

use Moose;

with 'Kanku::Roles::REST';

sub list {
  my ($self) = @_;
  my @roles  = $self->schema->resultset('Role')->search();
  my $result = [];

  foreach my $role (@roles) {
    my $rs = {
      id       => $role->id,
      role     => $role->role,
    };
    push @{$result}, $rs;
  }
  return $result;
}

__PACKAGE__->meta->make_immutable();

1;
