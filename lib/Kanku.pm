package Kanku;

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

use Kanku::Config;
use Kanku::Schema;
use Kanku::Util::IPTables;
use Kanku::LibVirt::HostList;
use Kanku::RabbitMQ;

our $VERSION = '0.0.2';

prepare_serializer_for_format;

Kanku::Config->initialize();

sub get_defaults_for_views {
  my $messagebar = session "messagebar";
  session  messagebar => undef;
  my $logged_in_user = logged_in_user();
  my $roles = {};
  if ($logged_in_user)  {
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

get '/' => sub {
    template 'index' , { %{ get_defaults_for_views() } };
};

get '/job_history' => sub {
    template 'job_history' , { %{ get_defaults_for_views() }, page => ( param('page') || 1 ), kanku => { module => 'History'} };
};

get '/job_result/:id' => sub {
    template 'job_result' , { %{ get_defaults_for_views() }, id => param('id'), kanku => { module => 'History'} };
};

get '/job' => require_any_role [qw/Admin User/] => sub {
    template 'job' , { %{ get_defaults_for_views() } , kanku => { module => 'Job' }  };
};

get '/guest' => sub {
    template 'guest' , { %{ get_defaults_for_views() }, kanku => { module => 'Guest' } };
};

get '/login/denied' => sub {
    template 'login/denied' , { %{ get_defaults_for_views() } };
};

get '/admin' => requires_role Admin =>  sub {
    template 'admin' , { %{ get_defaults_for_views() }, kanku => { module => 'Administration' } };
};

get '/settings' => requires_role User =>  sub {
    template 'settings' , { %{ get_defaults_for_views() }, kanku => { module => 'Settings' } };
};

get '/request_roles' => require_login sub {
    template 'request_roles' , { %{ get_defaults_for_views() }, kanku => { module => 'Request Roles' } };
};

get '/notify' => requires_role User =>  sub {
    template 'notify' , { %{ get_defaults_for_views() }, kanku => { module => 'Notifications' } };
};

### LOGIN / SIGNIN

get '/login' => sub {
    template 'login' , { return_url => params->{return_url} , kanku => { module => 'Login' } };
};

post '/login' => sub {

    my ($success, $realm) = authenticate_user(
        params->{username}, params->{password}
    );
    if ($success) {
        session logged_in_user => params->{username};
        session logged_in_user_realm => $realm;
        params->{username}="";
        params->{password}="";
        redirect params->{return_url};
    } else {

      session messagebar => messagebar('danger',"Authentication failed!");

      redirect params->{return_url};
      # authentication failed
    }
};

get '/logout' => sub {
    app->destroy_session;
    redirect '/';
};

### LOGIN / SIGNIN/

### SIGNUP
sub verify_signup_params {

  return "No username given\n" if ! params->{username};
  return "No email given\n" if ! params->{email};
  return "Password do not match\n" if ( params->{password} ne params->{password_repeat} );
  return "Username already exists\n" if ( get_user_details params->{username} );

  return undef;

}
post '/signup' => sub {

  my $error_msg = verify_signup_params();

  if ( $error_msg ) {
    debug $error_msg;
    return template('signup',{
      %{ params() },
      messagebar => messagebar('danger',$error_msg),
    });
  }

  if ( create_user username => params->{username},
              name          => params->{name},
              email         => params->{email},
              email_welcome => 1,
              deleted       => 1
  ) {

    user_password
          username      => params->{username},
          password      => '',
          new_password  => params->{password};

    my ($success, $realm) = authenticate_user(
        params->{username}, params->{password}
    );
    if ($success) {
        session logged_in_user => params->{username};
        session logged_in_user_realm => $realm;
        session messagebar => messagebar('success',"Your account has been created successfully. Please be aware to request some roles!");
        redirect('/request_roles');
    }
    session messagebar => messagebar('danger',"Your account creation failed!");
    redirect ( params->{return_url} || '/' );
  }

  template 'signup' , {
      messagebar => messagebar('danger',"Could not create user for unkown reason!"),
      %{ params() }
  };

};

get '/signup' => sub {
    template 'signup' , { return_url => params->{return_url} };
};

### SIGNUP/


any '/rest/jobs/list.:format' => sub {
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

get '/rest/job/:id.:format' => sub {
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

post '/rest/job/trigger/:name.:format' => require_any_role [qw/Admin User/] =>  sub {

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

get '/rest/job/config/:name.:format' => require_any_role [qw/Admin User/] =>  sub {

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


get '/rest/gui_config/job.:format' => sub {
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

get '/rest/guest/list.:format' => sub {
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

post '/rest/login.:format' => sub {

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

get '/rest/logout.:format' => sub {

    app->destroy_session;

    return { authenticated => 0 };
};

#
# WebSocket
Log::Log4perl->init("$FindBin::Bin/../etc/log4perl.conf");

websocket_on_open sub {
  my ($conn, $env) = @_;
  setup_mq($conn);
};

sub setup_mq {
  my ($conn) = @_;
  my $pid;
  my $cfg = Kanku::Config->instance();
  my $config = $cfg->config->{'Kanku::RabbitMQ'};

  try {
    my $mq = Kanku::RabbitMQ->new(%{$config});
    $mq->connect(no_retry=>1);

    my $log = $mq->logger;

    my $qn = $mq->queue->queue_declare(1,'');
    $mq->queue_name($qn);
    $mq->queue->queue_bind(1, $qn, 'kanku.notify', '');
    $mq->queue->consume(1, $qn);

    $conn->on(
      'close' => sub {
	if (!$pid) {
	  $log->debug("Cleaning  queue $qn and exiting $pid");
	  $mq->queue->queue_unbind(1, $qn, 'kanku.notify', '');
	  $mq->queue->queue_delete(1, $qn);
	  $mq->queue->disconnect();
	  exit 0;
	}
      },
      message => sub {
	my ($conn, $msg) = @_;
	$log->debug("Server got message on WebSocket connection: $msg");
        # Simply bounce the message back
	$conn->send($msg);
      }
    );


    $pid = fork();
    defined $pid or die "Error while forking\n";

    if (!$pid) {
      $log->debug("starting delayed");

      while (1) {
	my $data = $mq->recv(1000);
	if ($data) {
	  $log->debug("Got message: $data->{body}");
          my $body;
          try {
            $body = decode_json($data->{body});
	    $conn->send($body->{message});
          } catch {
            error $_;
            debug $data->{body};
	  };
	} else {
	  die "No connection any longer\n" if ! $mq->queue->is_connected();
	}
      }
    }
  } catch {
    error $_;
  };
}

__PACKAGE__->meta->make_immutable();

true;
