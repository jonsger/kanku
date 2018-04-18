package Kanku;

use Moose;

use FindBin;
use Dancer2;
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Auth::Extensible;
use Dancer2::Plugin::WebSocket;

use Try::Tiny;

use Kanku::Config;
use Kanku::Schema;
use Kanku::RabbitMQ;
use Kanku::WebSocket::Session;
use Kanku::WebSocket::Notification;

our $VERSION = '0.0.2';

Kanku::Config->initialize();

my $sub = "-";

sub get_defaults_for_views {
  my $messagebar = session 'messagebar';
  session  messagebar => undef;
  my $logged_in_user = logged_in_user();
  my $roles;
  my $user_id = 0;
  if ($logged_in_user)  {
    $roles = {Guest=>1};
    map { $roles->{$_} = 1 } @{user_roles()};
    $user_id = $logged_in_user->{id};
  }

  return {
    roles           => $roles,
    logged_in_user  => $logged_in_user ,
    messagebar      => $messagebar,
    ws_url          => websocket_url(),
    user_id         => $user_id
  };
};

sub messagebar {
  return '<div id=messagebar class="alert alert-'.shift.'" role=alert>'.
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
  my @users = schema('default')->resultset('User')->search();
  my @roles = schema('default')->resultset('Role')->search();
  template 'admin', {
      %{get_defaults_for_views()},
      kanku => {module => 'Administration'},
      users => \@users,
      roles => \@roles,
  };
};

get '/settings' => require_login sub {
  my @all_roles = schema('default')->resultset('Role')->search();

  for my $r (@all_roles) { debug 'Role: '.$r->id.' - '.$r->role; }

  my $user_roles;
  map { $user_roles->{$_} = 1 } @{user_roles()};

  for my $r (keys(%$user_roles)) { debug "UserRole: $r"; }
  template 'settings' ,
    {
      %{get_defaults_for_views()},
      kanku => {module => 'Settings'},
      all_roles => \@all_roles,
      user_roles => $user_roles
  };
};

### LOGIN / SIGNIN / SIGNUP

sub email_welcome_send {
    my ( $plugin, %options ) = @_;

    my %message;
    if ( my $welcome_text = $plugin->welcome_text ) {
        no strict 'refs';
        %message = &{$welcome_text}( $plugin, %options );
    }
    else {
        my $site       = $plugin->app->request->base;
        my $host       = $site->host;
        my $appname    = $plugin->app->config->{appname} || '[unknown]';
        my $reset_link = $site . "/login/$options{code}";
        $reset_link =~ s#([^:])//+#$1/#;
        $message{subject} = "Welcome to $host";
        $message{from}    = $plugin->mail_from;
        $message{plain}   = <<__EMAIL;
An account has been created for you at $host. If you would like
to accept this, please follow the link below to set a password:

$reset_link
__EMAIL
    }

    $plugin->_send_email( to => $options{email}, %message );
}


get '/pwreset' => sub {
  template 'pwreset' , { return_url => params->{return_url} , kanku => { module => 'Request Password Reset' } };
};

post '/pwreset' => sub {
  password_reset_send username => params->{username};
  redirect params->{return_url};
};

get qr{/login(/[\w]{32})?} => sub {
  my $code = splat;
  $code =~ s#/## if ($code);
  debug "code $code";
  if ($code) {
    template 'reset_password' ,
      { return_url => params->{return_url} ,
        pw_reset_token => $code,
        kanku => { module => 'Reset Password' }
      };
  } else {
    template 'login' , { return_url => params->{return_url} , kanku => { module => 'Login' } };
  }
};

post qr{/login(/[\w]{32})?} => sub {
  my $username;
  my $password = params->{password};
  my ($code) = splat;
  $code =~ s#/## if ($code);
  $code = $code || params->{pw_reset_token};
  if ($code) {
    debug "using code to reset password $code";
    $username = user_password code => $code, new_password => $password;
    debug "setting password for $username";
    if (! $username) {
      session messagebar => messagebar('danger', 'Password reset failed!');
      redirect params->{return_url};
    } else {
      session messagebar => messagebar('success', 'Password reset succeed!');
    }
  } else {
      $username = params->{username};
  }

  my ($success, $realm) = authenticate_user($username, $password);
  if ($success) {
    session logged_in_user => $username;
    session logged_in_user_realm => $realm;
    params->{username} = '';
    params->{password} = '';
    redirect params->{return_url};
  } else {
    session messagebar => messagebar('danger', 'Authentication failed!');
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

  return;

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
              password      => params->{password},
              email_welcome => 1,
              deleted       => 1,
              role_id    => { Guest => 1 }
  ) {

        session messagebar => messagebar(
          'success',
          'Your account has been created successfully. Please check your emails and activate the account. Finally <a href=settings>request some roles!</a>');
        redirect('/');
  }
  template 'signup' , {
      messagebar => messagebar('danger', 'Could not create user for unkown reason!'),
      %{ params() }
  };
};

get '/signup' => sub {
    template 'signup' , { return_url => params->{return_url} };
};

#
# WebSocket

get '/notify' => requires_any_role [qw(Admin User Guest)] => sub {
  my $self = shift;
  my $cfg = Kanku::Config->instance();
  my $config = $cfg->config->{'Kanku::RabbitMQ'};

  if ($config) {
    my $user = logged_in_user;
    my $ws_session = Kanku::WebSocket::Session->new(
      user_id => $user->{id},
      schema  => schema,
    );
    cookie 'kanku_notify_session' => $ws_session->auth_token, http_only => 0, path => $self->app->request->uri;
    template 'notify' , { %{ get_defaults_for_views() }, kanku => { module => 'Desktop Notifications' } };
  } else {
    template 'notify_disabled' , { %{ get_defaults_for_views() }, kanku => { module => 'Desktop Notifications' } };
  }
};

Log::Log4perl->init("$FindBin::Bin/../etc/log4perl.conf");

sub check_filters {
  my ($filters, $data, $log) = @_;
  my $fd;
  my $dd;
  try {
    $fd = decode_json($filters);
  } catch {
    $log->error($_);
    $log->debug($filters);
  };

  try {
    $dd = decode_json($data);
  } catch {
    $log->error($_);
    $log->debug($data);
  };
  return 1 if ! $fd;

  my $key;
  $key = $dd->{'type'}.'-enable';
  $log->trace("Step 0 $key: $fd->{$key}");
  return 0 if (exists $fd->{$key} && ! $fd->{$key});
  $key = $dd->{'type'}.'-'.$dd->{'event'};
  $log->trace("Step 1 $key $fd->{$key}");
  return 0 if (exists $fd->{$key} && ! $fd->{$key});
  $key = $dd->{'type'}.'-'.$dd->{'event'}.'-'.$dd->{'result'};
  $log->trace("Step 3 $key");
  return 0 if ($dd->{'result'} && exists $fd->{$key} && ! $fd->{$key});

  return 1;
}

websocket_on_open sub {
  my ($conn, $env) = @_;

  debug 'Opening websocket';

  my $notify = Kanku::WebSocket::Notification->new(conn=>$conn);
  my $ws_session;
  my $pid;
  my $qn;
  my $cfg = Kanku::Config->instance();
  my $config = $cfg->config->{'Kanku::RabbitMQ'};

  my $ev_to_role = {
   test_denied   => 99,
   user_change   => 29,
   daemon_change => 19,
   job_change    => 9,
   task_change   => 9
  };

  debug 'Creating new session';
  $ws_session = Kanku::WebSocket::Session->new(
    schema => schema()
  );

  debug 'Setting up WebSocket Connection callbacks';
  $conn->on(
    'close' => sub {
      debug "closing websocket\n";
      if ($ws_session) {
        debug 'closing session '.$ws_session->session_token;
        $ws_session->close_session();
      };
    },
    message => sub {
      my ($conn, $msg) = @_;
      $notify->unblock();
      debug "Server got message on WebSocket connection: $msg";
      my $data = decode_json($msg);
      # Proceed with data sent from client, eg.:
      # * authentication request
      # * filter update
      if ($data->{token}) {
	debug "Got Token $data->{token}";
	$ws_session->auth_token($data->{token});
	my $perms = $ws_session->authenticate;
        my $msg;
        if ($perms == -1) {
          $msg = 'Authentication failed!';
        } else {
          $msg = 'Authentication succeed!';
        }
	debug "$msg ($perms)";
        $notify->send($msg);
      } elsif ($data->{filters}) {
        debug('Got filters');
        $ws_session->filters(encode_json($data->{filters}));
      } elsif ($data->{bounce}) {
        $notify->send($data->{bounce});
      }
      debug 'Returning from message';
    }
  );

  # method session_token must be called before fork to grant a
  # shared token between parent and child
  debug 'Creating session token';
  my $session_token = $ws_session->session_token;

  debug 'Forking away listner for rabbitmq';
  $pid = fork();
  defined $pid or die "Error while forking\n";


  debug "PID is $pid";
  if (!$pid) {
      # prepare rabbitmq
      debug "PID is $pid ---";
      my $mq;
      try {
        $mq = Kanku::RabbitMQ->new(%{$config});
      } catch {
        debug 'ERROR: ' . $_;
        die $_;
      };
      debug 'Create mq object sucessfully';
      my $log = $mq->logger;
      $mq->connect(no_retry=>1);
      debug 'connected successfully';
      $qn = $mq->queue->queue_declare(1,'');
      debug "declared queue $qn successfully";
      $mq->queue_name($qn);
      debug "starting queue bind $qn -> kanku.notify";
      try {
        $mq->queue->queue_bind(1, $qn, 'kanku.notify', '');
      } catch {
        error $_;
        $log->error($_);
        die $_;
      }
      debug "queue bind succeed $qn -> kanku.notify";
      $mq->queue->consume(1, $qn);
      $log->debug("Starting child($$) and waiting for notifications on queue $qn");
      debug "started consuming $qn";
      my $oldperms=10000;
      while (1) {
        my $perms = $ws_session->get_permissions;
        if ($perms != $oldperms) {
          $log->debug("permission change $oldperms -> $perms detected");
          $oldperms = $perms;
        }
        if ($perms < 0) {
          debug 'Perms count less than zero';
          $log->debug("Authentication failed ($perms)") if ($perms == -1);
          $log->debug("Detected connection closed ($perms)") if ($perms == -2);
	  $ws_session->cleanup_session();
          if ($mq->queue->is_connected) {
            $log->debug('Unbinding queue');
	    $mq->queue->queue_unbind(1, $qn, 'kanku.notify', '');
            #$log->debug("Deleting queue");
	    #$mq->queue->queue_delete(1, $qn);
            $log->debug('Disconnecting queue');
	    $mq->queue->disconnect();
          }
          $log->debug("Cleanup and exiting child($$)");
          $mq->queue->disconnect if $mq->queue->is_connected();
          exit 0;
        }
	my $data = $mq->recv(1000);
	if ($data) {
          my $filters = $ws_session->filters;
	  $log->debug("Got message: $data->{body}");
          my $body;
          try {
            $body = decode_json($data->{body});
            my $ev_type = $body->{type};
            $log->debug("recieved event of type: '$ev_type'");

            if (! $ev_to_role->{$ev_type} ) {
              $log->warning("recieved unknown event type: '$ev_type'");
            } elsif( $perms < $ev_to_role->{$ev_type}) {
              $log->debug('User not authorized to get this type of notification');
            } else {
              check_filters($filters, $data->{body}, $log) && $notify->send($body);
            }
          } catch {
            $log->error($_);
            $log->debug($data->{body});
	  };
	} else {
	  if (! $mq->queue->is_connected()) {
            my $msg = 'No longer connected';
            $log->debug($msg);
            die $msg;
          }
	}
      }
    }
};

__PACKAGE__->meta->make_immutable();

true;
