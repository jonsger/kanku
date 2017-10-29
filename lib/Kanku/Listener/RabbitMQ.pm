package Kanku::Listener::RabbitMQ;

use Moose;
use Net::AMQP::RabbitMQ;
use Data::Dumper;
use JSON::XS;
use Log::Log4perl;
use Kanku::Config;
use FindBin;

with 'Kanku::Roles::Logger';


has config => ( is => 'rw', isa => 'HashRef');

has daemon => ( is => 'rw', isa => 'Object');


sub connect_listener {
  my ($self) = @_;
  my $config = $self->config;

  my $logger = $self->daemon->logger;

  $logger->info("Starting ...");
  my $lcfg = $config;
  my $host           = $lcfg->{host} || 'localhost';
  my $port           = $lcfg->{port} || 5671;
  my $user           = $lcfg->{user};
  my $password       = $lcfg->{password};
  my $heartbeat      = $lcfg->{heartbeat} || 5;
  my $channel        = $lcfg->{channel} ||1;
  my $exchange_name  = $lcfg->{exchange_name} || 'pubsub';
  my $routing_key    = $lcfg->{routing_key} || '#';
  my $routing_prefix = $lcfg->{routing_prefix} || "opensuse.obs";
  my $ssl            = exists($lcfg->{ssl}) ? $lcfg->{ssl} : 1;
  my $ssl_cacert;
  my $ssl_verify_host;
  if ($ssl) {
    $ssl_cacert      = $lcfg->{ssl_cacert} || '/usr/share/pki/trust/DigiCert_High_Assurance_EV_Root_CA.pem';
    $ssl_verify_host = 0;
  };
  my $mq = Net::AMQP::RabbitMQ->new();

  $logger->debug("Connecting to $host");
  my $c_opts = [
    $host,
    {
       port            => $port,
       user            => $user,
       password        => $password,
       heartbeat       => $heartbeat,
       ssl             => $ssl,
       ssl_verify_host => $ssl_verify_host,
       ssl_cacert      => $ssl_cacert
    }
  ];
  $logger->debug(Dumper($c_opts));

  $mq->connect(@$c_opts);

  $SIG{TERM} = $SIG{KILL} = sub {
    $mq->disconnect;
    exit 0;
  };

  $logger->debug("Opening channel '$channel'");
  $mq->channel_open($channel);

  $logger->debug("Declaring exchange '$exchange_name'");
  $mq->exchange_declare(
    $channel,
    $exchange_name,
    {
      exchange_type => 'topic',
      passive       => 1,
      durable       => 1,
    }
  );

  $logger->debug("Declaring queue");
  my $qname = $mq->queue_declare($channel, undef, { exclusive => 1 });

  $logger->debug("Binding queue '$qname'");
  $mq->queue_bind($channel, $qname, $exchange_name, $routing_key);

  return ($mq, $qname);
};

sub normalize_trigger_config {
  my ($self) = @_;
  my $config = $self->config;

  my $t_cfg={
    'package.build_success' => {},
    'repo.publish'          => {}
  };

  my $triggers = $config->{triggers};

  for my $t_tmp (@{$triggers}) {
    my $package_key = $t_tmp->{project}.'/'.$t_tmp->{package}.'/'.$t_tmp->{repository}.'/'.$t_tmp->{arch};
    my $repo_key    = $t_tmp->{project}.'/'.$t_tmp->{repository};

    $t_cfg->{'package.build_success'}->{$package_key} = {
       jobs =>  $t_tmp->{jobs},
       wait_for_publish => exists($t_tmp->{wait_for_publish}) ? $t_tmp->{wait_for_publish} : 1
    };
    $t_cfg->{'repo.publish'}->{$repo_key} = { jobs => $t_tmp->{jobs}};
  }
  return $t_cfg;
}

sub wait_for_events {
  my ($self, $mq, $qname) = @_;
  my $config = $self->config;
  my $logger = $self->daemon->logger;

  my $channel = $config->{channel} || 1;
  my $routing_prefix = $config->{routing_prefix} || 'opensuse.obs';
  my $wait_for_publisher = {};
  my $triggers = $self->normalize_trigger_config();

  $logger->info("Waiting for events.");

  $mq->consume($channel, $qname);


  while (1) {
    my $message = $mq->recv(1000);
    if ($message) {
      if ( $message->{routing_key} eq "$routing_prefix.package.build_success" ) {
	 my $body = decode_json($message->{body});
	 my $package_key = $body->{project}.'/'.$body->{package}.'/'.$body->{repository}.'/'.$body->{arch};
	 $logger->debug("package_key: $qname - $package_key");
	 my $cfg = $triggers->{'package.build_success'}->{$package_key};
	 if ($cfg) {
	   $logger->debug(" - found in cfg");

	   if ($cfg->{wait_for_publish}) {
	     $logger->debug(" -- adding to wait_for_publish");
	     my $repo_key = $body->{project}.'/'.$body->{repository};
	     $wait_for_publisher->{$repo_key} ||= [];
	     push(@{$wait_for_publisher->{$repo_key}},@{$cfg->{jobs}});
	   } else {
	     $self->trigger_jobs($cfg->{jobs});
	   }
	}
      }
      if ( $message->{routing_key} eq "$routing_prefix.repo.published" ) {
	my $body = decode_json($message->{body});
	my $repo_key = $body->{project}.'/'.$body->{repo};
	$logger->debug("repo_key: $qname - $repo_key");
	if ($wait_for_publisher->{$repo_key}) {
	  $logger->debug(" - found in wait_for_publisher");
	  $self->trigger_jobs($wait_for_publisher->{$repo_key});
	  $wait_for_publisher->{$repo_key}=undef;
	}
      }
    }
    last if $self->daemon->detect_shutdown;
  }
}

sub trigger_jobs {
  my ($self, $jcfg) = @_;
  my $logger = $self->logger();
  my $schema = $self->daemon->schema;

  foreach my $job_name (@$jcfg) {
    my $trigger = 1;
    my $jl = Kanku::JobList->new(schema=>$schema);

    if (! $jl->get_job_active($job_name) ) {
      $logger->debug(" - Triggering job '".$job_name."'");
      $schema->resultset('JobHistory')->create(
        {
          name => $job_name,
          creation_time => time(),
          last_modified => time(),
          state => 'triggered'
        }
      );
    }
  }
}

1;
