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

use Kanku::REST::Admin::User;
use Kanku::REST::Admin::Task;
use Kanku::REST::Admin::Role;
use Kanku::REST::JobComment;
use Kanku::REST::Guest;
use Kanku::REST::Job;

prepare_serializer_for_format;

Kanku::Config->initialize();

################################################################################
# Functions
################################################################################
sub app_opts {
  return 'app'=> app, 'current_user' => ( logged_in_user || {} ), 'schema' => schema;
}

################################################################################
# Routes
################################################################################

# ROUTES FOR JOBS
get '/jobs/list.:format' => sub {
  my $jo = Kanku::REST::Job->new(app_opts());
  return $jo->list;
};

get '/job/:id.:format' => sub {
  my $jo = Kanku::REST::Job->new(app_opts());
  return $jo->details;
};

post '/job/trigger/:name.:format' => require_any_role [qw/Admin User/] =>  sub {
  my $jo = Kanku::REST::Job->new(app_opts());
  return $jo->trigger;
};

get '/job/config/:name.:format' => require_any_role [qw/Admin User/] =>  sub {
  my $jo = Kanku::REST::Job->new(app_opts());
  return $jo->config;
};

# ROUTES FOR JOB COMMENTS
get '/job/comments/:job_id.:format' => require_any_role [qw/Admin User/] =>  sub {
  my $jco = Kanku::REST::JobComment->new(app_opts());
  return $jco->list();
};

post '/job/comment/:job_id.:format' => require_any_role [qw/Admin User/] =>  sub {
  my $jco = Kanku::REST::JobComment->new(app_opts());
  return $jco->create;
};

put '/job/comment/:comment_id.:format' => require_any_role [qw/Admin User/] =>  sub {
  my $jco = Kanku::REST::JobComment->new(app_opts());
  return $jco->update;
};

del '/job/comment/:comment_id.:format' => require_any_role [qw/Admin User/] =>  sub {
  my $jco = Kanku::REST::JobComment->new(app_opts());
  return $jco->remove;
};

# ROUTES FOR GUESTS
get '/guest/list.:format' => sub {
  my $go = Kanku::REST::Guest->new(app_opts());
  return $go->list;
};

# ROUTES FOR TASKS
get '/admin/task/list.:format' => requires_role Admin => sub {
  my ($self) = @_;
  my $to = Kanku::REST::Admin::Task->new(app_opts());
  return $to->list;
};

post '/admin/task/resolve.:format' => requires_role Admin => sub {
  my ($self) = @_;
  my $to = Kanku::REST::Admin::Task->new(app_opts());
  return $to->resolve;
};

post '/request_roles.:format' => require_login sub {
  my ($self) = @_;
  my $to = Kanku::REST::Admin::Task->new(app_opts());
  return $to->create_role_request;
};

# ROUTES FOR USERS
get '/admin/user/list.:format' => requires_role Admin => sub {
  my ($self) = @_;
  my $uo = Kanku::REST::Admin::User->new(app_opts());
  return $uo->list;
};

get '/user/:username.:format' => sub {
  my ($self) = @_;
  my $uo = Kanku::REST::Admin::User->new(app_opts());
  return $uo->details;
};

put '/user/:user_id.:format' => sub {
  my ($self) = @_;
  my $uo = Kanku::REST::Admin::User->new(app_opts());

  return $uo->update();
};

del '/admin/user/:user_id.:format' => requires_role Admin => sub {
  my $uo = Kanku::REST::Admin::User->new(app_opts());
  return $uo->remove(params->{user_id});
};

# ROUTES FOR ROLES
get '/admin/role/list.:format' => requires_role Admin => sub {
  my $ro = Kanku::REST::Admin::Role->new(app_opts());
  return $ro->list;
};

# ROUTES FOR AUTH
post '/login.:format' => sub {
  if ( session 'logged_in_user' ) {
    # user is authenticated by valid session
    return { authenticated => 1 };
  }
  my $username = params->{username};
  my $password = params->{password};

  if (! $username || ! $password) {
    # could not get username/password combo
    return { authenticated => 0 };
  }

  my ($success, $realm) = authenticate_user($username, $password);

  if ($success) {
    # user successfully authenticated by username/password
    session logged_in_user       => $username;
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

# ROUTES FOR MISC STUFF
get '/gui_config/job.:format' => sub {
  my $cfg = Kanku::Config->instance();
  my @config = ();
  my @jobs = $cfg->job_list;

  foreach my $job_name (sort @jobs) {
    my $job_config = { job_name => $job_name, sub_tasks => []};
    push @config , $job_config;
    my $job_cfg = $cfg->job_config($job_name);

    next if (ref($job_cfg) ne 'ARRAY');

    foreach my $sub_tasks ( @{$job_cfg}) {
        my $mod = $sub_tasks->{use_module};
        my $defaults = {};
        my $mod2require = $mod;
        $mod2require =~ s{::}{/}smxg;
        $mod2require = "$mod2require.pm";
        require "$mod2require";    ## no critic (Modules::RequireBarewordIncludes)
        my $tmp = [];
        my $can = $mod->can('gui_config');
        $tmp = $can->();

        foreach my $opt (@{$tmp}) {
          $defaults->{$opt->{param}} = $sub_tasks->{options}->{$opt->{param}};
        }
        push @{$job_config->{sub_tasks}},
            {
              use_module => $mod,
              gui_config => $tmp,
              defaults   => $defaults,
            },
        ;
    }
  }

  return {config => \@config};
};

get '/test.:format' => sub {  return {test=>'success'} };


__PACKAGE__->meta->make_immutable();

1;
