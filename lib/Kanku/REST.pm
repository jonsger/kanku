package Kanku::REST;

use Moose;

use Dancer2;
use Dancer2::Plugin;
use Dancer2::Plugin::REST;
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Auth::Extensible;
use Dancer2::Plugin::WebSocket;

use Data::Dumper;
use Sys::Virt;
use Try::Tiny;
use Session::Token;
use Carp qw/longmess/;

use Kanku::Config;
use Kanku::Schema;
use Kanku::Util::IPTables;
use Kanku::LibVirt::HostList;
use Kanku::RabbitMQ;
use Kanku::WebSocket::Session;
use Kanku::WebSocket::Notification;

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

  while ( my $ds = $rs->next ) {
    my $data = $ds->TO_JSON();
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

  my $jd = {
    name => param('name'),
    state => 'triggered',
    creation_time => time(),
    args => param("args")
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
  my $guests = {};
  my @sorted = ();

  my $hl = Kanku::LibVirt::HostList->new();
  $hl->calc_remote_urls();

  foreach my $host (@{$hl->cfg || []}) {
    my $vmm = Sys::Virt->new(uri => $host->{remote_url});

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
  return {
      guest_list =>$guests
  }
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

__PACKAGE__->meta->make_immutable();

true;
