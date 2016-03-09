package Kanku;
use Dancer2;
use Dancer2::Plugin;
use Dancer2::Plugin::REST;
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Auth::Extensible;

use Data::Dumper;
use JSON::XS;
use Sys::Virt;

use Kanku::Config;
use Kanku::Schema;
use Kanku::Util::IPTables;

our $VERSION = '0.0.1';

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
    messagebar      => $messagebar
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
    template 'job_history' , { %{ get_defaults_for_views() } };
};

get '/job' => require_any_role [qw/Admin User/] => sub {
    template 'job' , { %{ get_defaults_for_views() } };
};

get '/guest' => sub {
    template 'guest' , { %{ get_defaults_for_views() } };
};

get '/login/denied' => sub {
    template 'login/denied' , { %{ get_defaults_for_views() } };
};

get '/admin' => requires_role Admin =>  sub {
    template 'admin' , { %{ get_defaults_for_views() } };
};

get '/settings' => requires_role User =>  sub {
    template 'settings' , { %{ get_defaults_for_views() } };
};

get '/request_roles' => require_login sub {
    template 'request_roles' , { %{ get_defaults_for_views() } };
};
### LOGIN / SIGNIN

get '/login' => sub {
    template 'login' , { return_url => params->{return_url} };
};

post '/login' => sub {

    my ($success, $realm) = authenticate_user(
        params->{username}, params->{password}
    );
    if ($success) {
        session logged_in_user => params->{username};
        session logged_in_user_realm => $realm;
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

  my $rs = schema('default')->resultset('JobHistory')->search(
                  {
                    state => param('state') || [qw/succeed running failed/],
                  },
                  {
                    order_by =>{
                      -desc  =>'id'
                    },
                    rows=>$limit
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

  return {
      id => $job->id,
      name => $job->name,
      state => $job->state,
      subtasks => $subtasks,
  }
};

post '/rest/job/trigger/:name.:format' => require_any_role [qw/Admin User/] =>  sub {

  my $jd = {
    name => param('name'),
    state => 'triggered',
    creation_time => time(),
    args => param("args")
  };
  debug(Dumper($jd));
  my $job = schema('default')->resultset('JobHistory')->create($jd);

  return {
      id => $job->id,
  }
};

get '/rest/gui_config/job.:format' => sub {
  my $cfg = Kanku::Config->instance();
  my @config = ();
  my @jobs = $cfg->job_list;

  foreach my $job_name (sort(@jobs)) {
    my $job_config = { job_name => $job_name, sub_tasks => []};
    push @config , $job_config;
    foreach my $sub_tasks ( @{ $cfg->job_config($job_name) }) {
        my $mod = $sub_tasks->{use_module};
        my $defaults = {};
        my $mod2require = $mod;
        $mod2require =~ s|::|/|g;
        $mod2require = $mod2require . ".pm";
        require "$mod2require";
        my $tmp = [];
        my $can = $mod->can("gui_config");
        if ( $can ) {
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
  }

  return {
      config => \@config,
  }
};

get '/rest/guest/list.:format' => sub {
  my $guests = {};
  my @sorted = ();
  my $vmm = Sys::Virt->new(uri => "qemu:///system");

  my @domains = $vmm->list_all_domains();

  foreach my $dom (@domains) {
      my $dom_name          = $dom->get_name;
      my ($state, $reason)  = $dom->get_state();
      my $ipt = Kanku::Util::IPTables->new(
          domain_name     => $dom_name
      );

      $guests->{$dom_name}= {
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

  return {
      guest_list =>$guests
  }
};
true;
