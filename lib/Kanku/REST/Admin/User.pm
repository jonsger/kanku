package Kanku::REST::Admin::User;

use Moose;
use JSON::MaybeXS;

with 'Kanku::Roles::RESTClass';

sub list {
  my ($self) = @_;
  my @users = $self->schema->resultset('User')->search();
  my $result = [];

  foreach my $user (@users) {
    my $rs = {
      id       => $user->id,
      username => $user->username,
      name     => $user->name,
      deleted  => $user->deleted,
      email    => $user->email,
      roles    => [],
    };
    my @roles = $user->user_roles;
    for my $role (@roles) {
      push @{$rs->{roles}}, $role->role->role;
    }
    push @{$result}, $rs;
  }
  return $result;
}

sub details {
  my ($self)   = @_;
  my $username = $self->params->{username};
  my $user     = $self->current_user;

  if (! ($self->has_role('Admin') || $username eq $user->{username} )) {
    return {error => 'Permission denied!'};
  }

  my $user_o  = $self->schema->resultset('User')->find({username=>$username});
  return { error => "No such user '$username' found!" } unless $user_o;

  my $rs = {
      id       => $user_o->id,
      username => $user_o->username,
      name     => $user_o->name,
      deleted  => $user_o->deleted,
      email    => $user_o->email,
      roles    => [],
  };
  my @all_roles = $self->schema->resultset('Role')->search();
  my @roles = $user_o->user_roles;
  for my $role (@all_roles) {
    my $rd = {
      id       => $role->id,
      role     => $role->role,
      checked  => scalar grep { $role->role eq $_->role->role } @roles,
    };
    push @{$rs->{roles}}, $rd;
  }
  return $rs;
}

sub update {
  my ($self) = @_;
  my $args     = decode_json($self->app->request->body);
  my $username = $self->params->{username};
  my $user     = $self->current_user;

  if (! ($self->has_role('Admin') || $username eq $user->{username} )) {
    return {error => 'Permission denied!'};
  }
  my $user_o = $self->schema->resultset('User')->find({id => $self->params->{user_id}});
  if (! $user_o ) {
    return {
      'state'         => 'danger',
      'msg' => 'User with id '.$self->params->{user_id}.' not found!',
    };
  }

  my $data = {
    name  => $args->{name},
    email => $args->{email},
  };

  if ($self->has_role('Admin')) {
    $data->{roles} = $args->{roles};
  }

  $user_o->update($data);

  return {
      'state'         => 'success',
      'msg' => 'Updated data successfully!',
  };
}

sub remove {
  my ($self, $user_id) = @_;
  my $user = $self->schema->resultset('User')->find({id => $user_id});
  if (! $user ) {
    return {
      'state'         => 1,
      'message' => "User with id $user_id not found!",
    };
  }

  $user->delete;

  return {
    'state'   => 0,
    'message' => "Deleting user with id $user_id succeed!",
  };
}

__PACKAGE__->meta->make_immutable();

1;
