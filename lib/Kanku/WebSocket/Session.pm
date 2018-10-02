package Kanku::WebSocket::Session;
use Moose;

use Session::Token;
use Kanku::WebSocket::Notification;

has schema => (is=>'rw',isa=>'Object');

has session_token => (
  is=>'rw',
  isa=>'Str',
  lazy => 1,
  default => sub {
    return Session::Token->new(entropy => 256)->get;
  }
);

has auth_token => (
  is=>'rw',
  isa=>'Str',
  lazy => 1,
  default => sub {
    my ($self) = @_;
    my $at = Session::Token->new(entropy => 256)->get;
    $self->schema->resultset("WsToken")->create({
      auth_token=>$at,
      user_id => $self->user_id
    });
    return $at;
  }
);

has user_id => (is=>'rw', isa=>'Int', default => 0);
has perms => (is=>'rw', isa=>'Int', default => 0);

my $role_to_points = {
   Admin => 30,
   User  => 20,
   Guest => 10
};


#  my ($self) = @_;

sub close_session {
  my ($self) = @_;
  my $session = $self->schema->resultset('WsSession')->find({session_token=> $self->session_token});
  if ($session) {
    $session->permissions(-2);
    $session->update;
  } else {
    $self->schema->resultset('WsSession')->create(
      {
        session_token => $self->session_token,
        user_id       => $self->user_id,
        permissions   => -2,
        filters       => '',
      }
    );

  }
}

sub cleanup_session {
  my ($self) = @_;
  my $session = $self->schema->resultset('WsSession')->find({session_token=> $self->session_token});
  if ($session) {
    $session->delete;
    $session->update;
  }
}

sub get_permissions {
  my ($self) = @_;
  my $session = $self->schema->resultset('WsSession')->find({session_token=> $self->session_token});
  return $session->permissions if ($session);
  return 0;
}

sub authenticate {
  my ($self) = @_;

  my $session = $self->schema->resultset('WsSession')->find({session_token=> $self->session_token});

  return -1 if ($session);

  $self->schema->resultset('WsSession')->create({
    session_token => $self->session_token,
    user_id       => $self->user_id,
    permissions   => 0,
    filters       => '',
  });

  $session = $self->schema->resultset('WsSession')->find({session_token=> $self->session_token});

  my $rs = $self->schema->resultset('WsToken')->find({auth_token=> $self->auth_token});

  if ( $rs ) {
    $self->user_id($rs->user_id);
    $session->user_id($rs->user_id);
    my $user = $rs->user;
    my $roles = $rs->user->user_roles;
    my $perms=0;
    while ( my $role = $roles->next ) {
      my $rn = $role->role->role;
      $perms = $role_to_points->{$rn} if ( $role_to_points->{$rn} > $perms);
    }

    $session->permissions($perms);
    $rs->delete;
  } else {
    $session->permissions(-1);
  }
  $session->update;

  return $session->permissions;
}

sub filters {
  my ($self, $filters) = @_;
  my $session = $self->schema->resultset('WsSession')->find({session_token=> $self->session_token});
  if ($session) {
    if ($filters) {
      $session->filters($filters);
      $session->update;
    }
    return $session->filters
  }
};

__PACKAGE__->meta->make_immutable;
1;
