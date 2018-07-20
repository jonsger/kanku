package Kanku::REST::Admin::Task;

use Moose;
use JSON::MaybeXS;

with 'Kanku::Roles::REST';

sub list  {
  my ($self) = @_;
  my @requests = $self->schema->resultset('RoleRequest')->search({decision => 0});
  my @req;

  foreach my $r (@requests) {
    my $role_changes = $self->_role_changes($r);
    push @req,
      {
        req_id      => $r->id,
        roles       => $role_changes,
        comment     => $r->comment,
        user_id     => $r->user_id,
        user_name   => $r->user->name,
        user_login  => $r->user->username,
      }
    ;
  }
  return \@req;
}

sub resolve {
  my ($self) = @_;
  my $args   = decode_json($self->app->request->body);
  my $req    = $self->schema->resultset('RoleRequest')->find($args->{req_id});

  if (!$req) {
    return {
      result => 'failed',
      class  => 'danger',
      msg    => "Request with id $args->{req_id} not found!",
    };
  }

  if ($args->{decision} == 1) {
    my $role_changes = $self->_role_changes($req);
    my $user_id = $req->user_id;
    for my $chg (@{$role_changes}) {
      my $role_id = $chg->{role_id};
      if ($chg->{action} eq 'add') {
        $self->log('debug', "Role to add: ($user_id, $role_id)");
        $self->rset('UserRole')->create({
          user_id => $user_id,
          role_id => $role_id,
        });
      } elsif ($chg->{action} eq 'remove') {
        $self->log('debug', "Role to remove: ($user_id, $role_id)");
        $self->rset('UserRole')->find({
          user_id => $user_id,
          role_id => $role_id,
        })->delete;
      } elsif ($chg->{action} eq 'unchanged') {
        $self->log('debug', "Role unchanged: ($user_id, $role_id)");
      } else {
        $self->log('error', "Something wicked happend - action '$chg->{action}' is unknown");
      }
    }
  }

  $req->update({
    decision => $args->{decision},
    comment  => $args->{comment},
  });

  return {
    result => 'success',
    class  => 'success',
    msg    => "Request '$args->{req_id}' processed successfully!",
  };
}

sub create_role_request {
  my ($self) = @_;

  my $args = decode_json($self->app->request->body);
  my $result = $self->schema->resultset('RoleRequest')->create(
    {
      user_id          => $self->current_user->{id},
      comment          => $args->{comment},
      roles            => join(q{,}, @{$args->{roles}}),
      creation_time    => time(),
      decision         => 0,
      decision_comment => q{},
    },
  );

  return { state => 'success', msg => 'Role request submitted successfully' };
}


sub _role_changes {
  my ($self, $r) = @_;
  my @ur_rs = $self->schema->resultset('UserRole')->search({user_id => $r->user_id});
  my $requested_roles = {};
  my $user_roles      = {};
  my @all_roles;
  $requested_roles->{$_}     = 1 for split /,/smx, $r->roles;
  $user_roles->{$_->role_id} = 1 for (@ur_rs);
  my $ar_rs = $self->schema->resultset('Role')->search();
  my $actions = {
    1 => {action => 'add',       class => 'success'},
    2 => {action => 'remove',    class => 'danger' },
    3 => {action => 'unchanged', class => 'default'},
  };
  while (my $ar = $ar_rs->next) {
    my $cur = (($user_roles->{$ar->id} || 0) << 1);
    my $new = ($requested_roles->{$ar->id} || 0);
    my $action_code = $cur | $new;

    push @all_roles,
      {
	role_id => $ar->id,
	role    => $ar->role,
	action  => $actions->{$action_code}->{action} || 'unknown',
	class   => $actions->{$action_code}->{class} || q{},
	checked => (($new) ? 'checked' : q{}),
      }
    ;
  }
  return \@all_roles;
}

1;
