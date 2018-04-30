package Kanku::REST;

use Moose;

use Dancer2;
use Dancer2::Plugin;
use Dancer2::Plugin::REST;
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Auth::Extensible;
use Dancer2::Plugin::WebSocket;

use Sys::Virt;
use Try::Tiny;
use Session::Token;
use Carp qw/longmess/;

use Data::Dumper;

use Kanku::Config;
use Kanku::Schema;
use Kanku::Util::IPTables;
use Kanku::LibVirt::HostList;

our $VERSION = '0.0.2';

prepare_serializer_for_format;

Kanku::Config->initialize();

sub get_defaults_for_views {
  my $messagebar = session "messagebar";
  session  messagebar => undef;
  my $logged_in_user = logged_in_user();
  my $roles;
  if ($logged_in_user)  {
    $roles = {Guest=>1};
    map { $roles->{$_} = 1 } @{user_roles()};
  }

  return {
    roles           => $roles,
    logged_in_user  => $logged_in_user ,
    messagebar      => $messagebar,
    ws_url          => websocket_url()
  };
};

sub messagebar {
  return "<div id=messagebar class=\"alert alert-".shift.'" role=alert>'.
                      shift .
                    '</div>';
}

get '/test.:format' => sub {  return {test=>'success'} };

any '/jobs/list.:format' => sub {
  my $limit = param('limit') || 10;

  my %opts = (
    rows => $limit,
    page => param('page') || 1,
  );

  my $search = {};
  if (param('state')) {
    $search->{state} = param('state')

  } else {
    $search->{state} = [qw/succeed running failed dispatching/]
  }

  if ( param("job_name") ) {
	my $jn = param("job_name");
	$jn =~ s/^\s*(.*)\s*$/$1/;
	$search->{name}= { like => $jn }
  }

  my $rs = schema('default')->resultset('JobHistory')->search(
		  $search,
                  {
                    order_by =>{
                      -desc  =>'id'
                    },
                    %opts
                  }
              );

  my $rv = [];

  my @roles_found;
  if (logged_in_user()) {
    @roles_found = grep { /^(User|Admin)$/ } @{user_roles()};
  }

  while ( my $ds = $rs->next ) {
    my $data = $ds->TO_JSON();

    if (@roles_found) {
      $data->{comments} = [];
      my @comments = $ds->comments;
      for my $comment (@comments) {
        push(@{$data->{comments}}, $comment->TO_JSON);
      }
    }
    push(@$rv,$data);
  }

  return {
    limit => $limit,
    jobs  => $rv
  };
};

get '/job/:id.:format' => sub {
  my $job = schema('default')->resultset('JobHistory')->find(param 'id');

  my $subtasks = [];

  my $job_history_subs = $job->job_history_subs();

  while (my $job_history_sub = $job_history_subs->next ) {
    push(
      @$subtasks,
      $job_history_sub->TO_JSON()
    );
  }

  # workerinfo:
  # kata.suse.de:23108:job-3878-340a157a-d27d-4138-97ab-bb8f49b5bef7
  my ($workerhost, $workerpid, $workerqueue) = split(/:/,$job->workerinfo);

  return {
      id          => $job->id,
      name        => $job->name,
      state       => $job->state,
      subtasks    => $subtasks,
      result      => $job->result || "{}",
      workerhost  => $workerhost,
      workerpid   => $workerpid,
      workerqueue => $workerqueue,
  }
};

post '/job/trigger/:name.:format' => require_any_role [qw/Admin User/] =>  sub {
  my $self = shift;
  my $name = param('name');

  debug("active jobs:\n");
  # search for active jobs
  my @active = schema('default')->resultset('JobHistory')->search({
    name  => $name,
    state => {
      'not in' => [qw/skipped succeed failed/]
    }
  });

  if (@active) {
    return {
      state => 'warning',
      msg   => "Skipped triggering job '$name'."
               . " Another job is already running"
    };
  }

  my $args = $self->app->request->body;

  my $jd = {
    name => param('name'),
    state => 'triggered',
    creation_time => time(),
    args => $args
  };

  my $job = schema('default')->resultset('JobHistory')->create($jd);

  return {state => 'success', msg => "Successfully triggered job with id ".$job->id};
};

get '/job/config/:name.:format' => require_any_role [qw/Admin User/] =>  sub {

  my $cfg = Kanku::Config->instance();
  my $rval;

  try {
    $rval = $cfg->job_config_plain(param('name'));
  }
  catch {
    $rval = $_;
  };

  return { config => $rval }
};

get '/job/comments/:job_id.:format' => require_any_role [qw/Admin User/] =>  sub {
  my $job_id = param('job_id');
  my $job = schema('default')->resultset('JobHistory')->find($job_id);
  if (! $job) {
    return {
      result  => 'failed',
      code    => 404,
      message => "job not found with id ($job_id)"
    };
  }
  my $comments = $job->comments;
  my @cl;
  while (my $cm = $comments->next) {
    push(@cl, $cm->TO_JSON);
  }
  return { comments => \@cl }
};

post '/job/comment/:job_id.:format' => require_any_role [qw/Admin User/] =>  sub {

  my $job_id  = param 'job_id';
  my $message = param 'message';
  my $ul      = logged_in_user();
  my $user_id = $ul->{id};

  if ($message && $user_id && $job_id) {
    schema('default')
      ->resultset('JobHistoryComment')
      ->create({
        job_id  => $job_id,
        user_id => $user_id,
        comment => $message,
      });

    return {
      result => 'succeed',
      code   => 200
    };
  }

  return { result => 'failed' };
};

put '/job/comment/:comment_id.:format' => require_any_role [qw/Admin User/] =>  sub {

  my $comment_id  = param 'comment_id';
  my $comment = schema('default')
                  ->resultset('JobHistoryComment')
                  ->find($comment_id);
  if (! $comment) {
    return {
      result  => 'failed',
      code    => 404,
      message => "comment not found with id ($comment_id)"
    };
  }
  my $message = param('message');
  my $ul      = logged_in_user();
  my $user_id = $ul->{id};
  if ($message && $user_id) {

    if ($comment->user_id != $user_id) {
      return {
        result  => 'failed',
        code    => 403,
        message => "user with id ($user_id) is not allowed to change comments of user (".$comment->user_id.")"
      };
    }
    $comment->update({comment=>$message});

    return {
      result => 'succeed',
      code   => 200
    };
  }

  return { result => 'failed' };
};

del '/job/comment/:comment_id.:format' => require_any_role [qw/Admin User/] =>  sub {

  my $comment_id  = param('comment_id');
  my $comment = schema('default')
                  ->resultset('JobHistoryComment')
                  ->find($comment_id);
  if (! $comment) {
    return {
      result  => 'failed',
      code    => 404,
      message => "comment not found with id ($comment_id)"
    };
  }
  my $ul      = logged_in_user();
  my $user_id = $ul->{id};
  if ($comment->user_id != $user_id) {
    return {
      result  => 'failed',
      code    => 403,
      message => "user with id ($user_id) is not allowed to change comments of user (".$comment->user_id.")"
    };
  }
  $comment->delete;

  return {
    result => 'succeed',
    code   => 200
  }
};

get '/gui_config/job.:format' => sub {
  my $cfg = Kanku::Config->instance();
  my @config = ();
  my @jobs = $cfg->job_list;

  foreach my $job_name (sort(@jobs)) {
    my $job_config = { job_name => $job_name, sub_tasks => []};
    push @config , $job_config;
    my $job_cfg = $cfg->job_config($job_name);

    next if (ref($job_cfg) ne 'ARRAY');

    foreach my $sub_tasks ( @{$job_cfg}) {
        my $mod = $sub_tasks->{use_module};
        my $defaults = {};
        my $mod2require = $mod;
        $mod2require =~ s|::|/|g;
        $mod2require = $mod2require . ".pm";
        require "$mod2require";
        my $tmp = [];
        my $can = $mod->can("gui_config");
        $tmp = $can->();

        foreach my $opt (@$tmp) {
          $defaults->{$opt->{param}} = $sub_tasks->{options}->{$opt->{param}};
        }
        push(@{ $job_config->{sub_tasks} },
            {
              use_module => $mod,
              gui_config => $tmp,
              defaults   => $defaults
            }
        );
    }
  }

  return {
      config => \@config,
  }
};

get '/guest/list.:format' => sub {
  my $result = {errors=>[]};
  my $guests = {};

  my $hl = Kanku::LibVirt::HostList->new();
  $hl->calc_remote_urls();

  foreach my $host (@{$hl->cfg || []}) {
    my $vmm;
    try {
      $vmm = Sys::Virt->new(uri => $host->{remote_url});
    } catch {
      my $error = "ERROR while connecting '$host->{remote_ip}' " .$_->message;
      error($error);
      debug(Dumper($host));
      push @{$result->{errors}}, $error;
    };
    next if (!$vmm);
    my @domains = $vmm->list_all_domains();

    foreach my $dom (@domains) {
	my $dom_name          = $dom->get_name;
	my ($state, $reason)  = $dom->get_state();
	my $ipt = Kanku::Util::IPTables->new(
	    domain_name     => $dom_name
	);

	$guests->{$dom_name}= {
          host		  => $host->{hostname},
	  domain_name     => $dom_name,
	  state           => $state,
	  forwarded_ports => $ipt->get_forwarded_ports_for_domain(),
	  nics            => [],
	};

	if ($state == 1 ) {
	  my @t = $dom->get_interface_addresses(Sys::Virt::Domain::INTERFACE_ADDRESSES_SRC_LEASE);
	  $guests->{$dom_name}->{nics} = \@t ;
	}
    }
  }
  $result->{guest_list} = $guests;
  return $result;
};

post '/login.:format' => sub {
  if ( session 'logged_in_user' ) {
    # user is authenticated by valid session
    return { authenticated => 1 };
  }

  if ( ! params->{username} || ! params->{password} ) {
    # could not get username/password combo
    return { authenticated => 0 };
  }

  my ($success, $realm) = authenticate_user(
    params->{username}, params->{password}
  );

  if ($success) {
    # user successfully authenticated by username/password
    session logged_in_user => params->{username};
    session logged_in_user_realm => $realm;

    return { authenticated => 1 };
  } else {
    # could not authrenticate user
    return { authenticated => 0 };
  }

};

get '/logout.:format' => sub {

    app->destroy_session;

    return { authenticated => 0 };
};

post '/request_roles.:format' => require_login sub {
  my ($self) = @_;
  my $args = decode_json($self->app->request->body);

  my $result = schema->resultset('RoleRequest')->create(
    {
      user_id          => logged_in_user->{id},
      comment          => $args->{comment},
      roles            => join(',', @{$args->{roles}}),
      creation_time    => time(),
      decision         => 0,
      decision_comment => ""
    }
  );

  return { state => 'success', msg => 'Role request submitted successfully' }
};

get '/admin/task/list.:format' => requires_role Admin => sub {
  my @requests = schema->resultset('RoleRequest')->search({decision => 0});
  my @req;

  foreach my $r (@requests) {
    my $role_changes = calc_changes($r);
    push(@req,
      {
        req_id      => $r->id,
        roles       => $role_changes,
        comment     => $r->comment,
        user_id     => $r->user_id,
        user_name   => $r->user->name,
        user_login  => $r->user->username,
      }
    );
  }
  return \@req
};

del '/admin/user/:user_id.:format' => requires_role Admin => sub {
  my $user = schema->resultset('User')->find({id => param('user_id')});
  if (! $user ) {
    return {
      'state'         => 1,
      'message' => 'User with id '.param('user_id').' not found!'
    }
  }

  $user->delete;

  return {
      'state'         => 0,
      'message' => 'Deleting user with id '.param('user_id').' succeed!'
    }
};

sub calc_changes {
  my ($r) = @_;
    debug "RoleRequest: " . $r->roles;
    my @ur_rs = schema->resultset('UserRole')->search({user_id => $r->user_id});
    my $requested_roles = {};
    my $user_roles      = {};
    my @all_roles;
    $requested_roles->{$_}     = 1 for (split(/,/, $r->roles));
    $user_roles->{$_->role_id} = 1 for (@ur_rs);
    my $ar_rs = schema->resultset('Role')->search();
    while (my $ar = $ar_rs->next) {
      my $already_exists = $user_roles->{$ar->id};
      my $requested      = $requested_roles->{$ar->id};
      my $action;
      my $class;

      if (
	( $already_exists && $requested ) ||
	( ! $already_exists && ! $requested )
      ) {
	$action = 'unchanged';
        $class  = 'default';
      } elsif ($already_exists && ! $requested) {
	$action = 'remove';
        $class  = 'danger';
      } elsif (! $already_exists && $requested) {
	$action = 'add';
        $class  = 'success';
      } else {
	$action = 'unknown';
        $class  = '';
      }
      push(@all_roles,
        {
          role_id => $ar->id,
          role    => $ar->role,
          action  => $action,
          class   => $class,
          checked => (($requested) ? 'checked' : ''),
        }
      );
    }
    return \@all_roles;
}

post '/admin/task/resolve.:format' => requires_role Admin => sub {
  my ($self) = @_;
  my $args = decode_json($self->app->request->body);
  debug "request_id: ". $args->{req_id};
  debug "decision ". $args->{decision};
  debug "comment ". $args->{comment};

  my $req = schema->resultset('RoleRequest')->find($args->{req_id});

  if (!$req) {
    return {
      result => 'failed',
      class  => 'danger',
      msg    => "Request with id $args->{req_id} not found!"
    };
  }

  if ($args->{decision} == 1) {
    my $role_changes = calc_changes($req);
    my $user_id = $req->user_id;
    for my $chg (@{$role_changes}) {
      my $role_id = $chg->{role_id};
      if ($chg->{action} eq 'add') {
        debug "Role to add: ($user_id, $role_id)";
        schema->resultset('UserRole')->create({
          user_id => $user_id,
          role_id => $role_id
        });
      } elsif ($chg->{action} eq 'remove') {
        debug "Role to remove: ($user_id, $role_id)";
        schema->resultset('UserRole')->find({
          user_id => $user_id,
          role_id => $role_id
        })->delete;
      } elsif ($chg->{action} eq 'unchanged') {
        debug "Role unchanged: ($user_id, $role_id)";
      } else {
        error "Something wicked happend - action '$chg->{action}' is unknown";
      }
    }
  }

  $req->update({
    decision => $args->{decision},
    comment  => $args->{comment}
  });

  return {
    result => 'success',
    class  => 'success',
    msg    => "Request '$args->{req_id}' processed successfully!"
  };
};

get '/admin/user/list.:format' => requires_role Admin => sub {
  my @users = schema('default')->resultset('User')->search();
  my $result = [];

  foreach my $user (@users) {
    my $rs = {
      id       => $user->id,
      username => $user->username,
      name     => $user->name,
      deleted  => $user->deleted,
      email    => $user->email,
      roles    => []
    };
    my @roles = $user->user_roles;
    for my $role (@roles) {
      push(@{$rs->{roles}}, $role->role->role);
    }
    push @{$result}, $rs;
  }
  return $result;
};

get '/admin/role/list.:format' => requires_role Admin => sub {
  my @roles = schema('default')->resultset('Role')->search();
  my $result = [];

  foreach my $role (@roles) {
    my $rs = {
      id       => $role->id,
      role     => $role->role,
    };
    push @{$result}, $rs;
  }
  return $result;
};

__PACKAGE__->meta->make_immutable();

1;
