package Kanku::Dispatch::RabbitMQ;


=head1 NAME

Kanku::Dispatch::RabbitMQ - TODO: comment

=head1 SYNOPSIS

|scheduler.pl <required-options> [optional options]

=head1 DESCRIPTION

FIXME: add a useful description

=head1 AUTHORS

Frank Schreiner, <fschreiner@suse.de>

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use Moose;

our $VERSION = "0.0.1";

use Data::Dumper;
use JSON::XS;
use Kanku::RabbitMQ;
use Kanku::Task;
use Kanku::Task::Local;
use Kanku::Task::Remote;
use Kanku::Task::RemoteAll;
use Try::Tiny;

with 'Kanku::Roles::Dispatcher';
with 'Kanku::Roles::ModLoader';
with 'Kanku::Roles::Daemon';

has 'max_processes' => (
  is      => 'rw',
  isa     => 'Int',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    return $self->config->{max_processes} || 2
  }
);

has kmq => (is=>'rw',isa=>'Object');

has job => (is=>'rw',isa=>'Object');

has job_queue => (is=>'rw',isa=>'Object');

has wait_for_workers => (is=>'ro',isa=>'Int',default=>1);

has config => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  default => sub { Kanku::Config->instance->config->{ref($_[0])} || {}; }
);

has rabbit_config => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  default => sub { Kanku::Config->instance->config->{"Kanku::RabbitMQ"} || {}; }
);

sub run_job {
  my ($self, $job) = @_;

  $self->job($job);

  $job->masterinfo($$);
  $job->state('dispatching');
  $job->update_db();

  $self->notify_queue->send({
    type           => 'job_change',
    event          => 'dispatching',
    message        => "Dispatching job (".$job->name."/".$job->id.")",
    name           => $job->name,
    id             => $job->id
  });

  my $logger       = $self->logger();
  my $queue        = "job-queue-".$job->id;

  # job definition should be parsed before advertising job
  # if no valid job definition it should not be advertised
  my $job_definition = $self->load_job_definition($job);
  my $args           = $self->prepare_job_args($job);

  my $rmq = Kanku::RabbitMQ->new(%{$self->rabbit_config});
  $rmq->shutdown_file($self->shutdown_file);
  $rmq->connect() || die "Could not connect to rabbitmq\n";
  $rmq->queue_name($queue);
  $rmq->exchange_name('kanku.to_dispatcher');
  $rmq->create_queue();
  $self->job_queue($rmq);

  my $applications={};;

  while (! keys(%{$applications})) {
    $applications = $self->advertise_job(
      $rmq,
      {
	 answer_queue	  => $queue,
	 job_id	  	  => $job->id,
      }
    );
    die "shutdown detected while waiting for applications" if ($self->detect_shutdown);
    sleep 1;
  }

  $logger->trace("List of all applications:\n" . Dumper($applications));

  # pa = prefered_application
  my ($pa,$declined_applications) = $self->score_applications($applications);

  $self->decline_applications($declined_applications);

  my $result = $self->send_job_offer($rmq,$pa);

  $self->notify_queue->send({
    type          => 'job_change',
    event         => 'sending',
    message       => "Sending job (".$job->name."/".$job->id.") to worker ($pa->{worker_fqhn},$pa->{worker_pid})",
    name           => $job->name,
    id             => $job->id
  });

  my $aq = $pa->{answer_queue};

  $self->start_job($job);

  $job->workerinfo($pa->{worker_fqhn}.":".$pa->{worker_pid}.":".$aq);
  $logger->trace("Result of job offer:\n".Dumper($result));
  $logger->trace("  -- args:\n".Dumper($args));

  my $last_task;

  try {
    foreach my $sub_task (@{$job_definition}) {
      my $task_args = shift(@$args) || {};
      $last_task = $self->run_task(
	job       => $job,
	options   => $sub_task->{options} || {},
	module    => $sub_task->{use_module},
	scheduler => $self,
	args      => $task_args,
	kmq       => $rmq,
	queue     => $aq
      );

      last if ( $last_task->state eq 'failed' or $job->skipped);
    }
    $job->state($last_task->state);
  } catch {
    $job->state('failed');
    $job->result(encode_json({error_message=>$_}));
  };

  $self->notify_queue->send({
    type          => 'job_change',
    event         => 'finished',
    result        => $job->state,
    message       => "Finished job (".$job->name."/".$job->id.") with result: ".$job->state,
    name          => $job->name,
    id            => $job->id
  });

  $self->send_finished_job($aq,$job->id);

  $self->end_job($job,$last_task);

  $self->run_notifiers($job,$last_task);

  $rmq->queue->disconnect;

  return $job->state;
}

sub run_task {
  my $self = shift;
  my %opts = @_;
  my $mod  = $opts{module};
  my $distributable = $self->check_task($mod);

  $self->logger->debug("Starting with new task");

  $self->logger->trace(Dumper(\%opts));

  my %defaults = (
    job         => $opts{job},
    module      => $opts{module},
    final_args  => {%{$opts{options} || {}},%{$opts{args} || {}}},
  );

  my $task = Kanku::Task->new(
    %defaults,
    options      => $opts{options} || {},
    schema       => $self->schema,
    scheduler    => $opts{scheduler},
    args         => $opts{args},
    notify_queue => $self->notify_queue
  );

  my $tr;

  if ( $distributable == 0 ) {
    $tr = Kanku::Task::Local->new(
      %defaults,
      schema          => $self->schema
    );


  } elsif ( $distributable == 1 ) {
    $tr = Kanku::Task::Remote->new(
      %defaults,
      job_queue => $self->job_queue,
      queue     => $opts{queue},
      daemon	=> $self,
    );

  } elsif ( $distributable == 2 ) {

    $tr = Kanku::Task::RemoteAll->new(
      %defaults,
      kmq => $opts{kmq},
      local_job_queue_name => $opts{kmq}->queue_name,
    );

  } else {
    die "Unknown distributable value '$distributable' for module $mod\n"
  }

  return $task->run($tr);
}

sub check_task {
  my ($self,$mod) = @_;

  $self->load_module($mod);

  return $mod->distributable();
}

sub decline_applications {
  my ($self, $declined_applications) = @_;
  my $rmq = Kanku::RabbitMQ->new(%{$self->rabbit_config});
  $rmq->shutdown_file($self->shutdown_file);
  $rmq->connect() || die "Could not connect to rabbitmq\n";

  foreach my $queue( keys(%$declined_applications) ) {
    $rmq->queue_name($queue);
    $rmq->publish(
      $queue,
      encode_json({action => 'decline_application'}),
    );
  }

}

sub send_job_offer {
  my ($self,$rmq,$prefered_application)=@_;
  my $logger = $self->logger;

  $logger->debug("Offering job for prefered_application");
  $logger->trace(Dumper($prefered_application));

  $rmq->publish(
    $prefered_application->{answer_queue},
	encode_json(
		{
		  action			=> 'offer_job',
		  answer_queue		=> $prefered_application->{answer_queue}
		}
	),
    { exchange => 'amq.direct' }
  );
}

sub send_finished_job {
  my ($self, $aq, $job_id)=@_;
  my $logger = $self->logger;


  $logger->debug("Sending finished_job for job_id $job_id to queue $aq");

  $self->job_queue->publish(
    $aq,
	encode_json(
		{
		  action  => 'finished_job',
          job_id  => $job_id
		}
	),
    { exchange => 'amq.direct' }
  );
}

sub score_applications {
  my ($self,$applications) = @_;

  my $pref;

  my @keys = keys(%$applications);

  $self->logger->debug("Keys of applications: '@keys'");

  my $key = shift(@keys);

  my $ret = $applications->{$key};
  delete $applications->{$key};

  return ($ret,$applications);

}

sub advertise_job {
  my $self                  = shift;
  my ($rmq,$opts)           = @_;
  my $all_applications      = {};
  my $logger                = $self->logger;

  my $data = encode_json({action => 'advertise_job', %$opts});

  $logger->debug("creating new queue: ".$opts->{answer_queue});

  my $wcnt = 0;

  while(! %$all_applications ) {

    $rmq->publish(
      '',
      $data,
      { exchange => 'kanku.to_all_workers' }
    );

    sleep($self->wait_for_workers);

    while ( my $msg = $rmq->recv(1000) ) {
      if ($msg ) {
          my $data;
          $logger->debug("Incomming application");
          $logger->trace(Dumper($msg));
          my $body = $msg->{body};
          try {
            $data = decode_json($body);
            $all_applications->{$data->{answer_queue}} = $data;
          } catch {
            $logger->debug("Error in JSON:\n$_\n$body\n");
          };
      }
    }

    # log only every 60 seconds
    $logger->debug("No application so far (wcnt: $wcnt)") if (! $wcnt % 60);
    $wcnt++;
  }

  return $all_applications;
}

sub cleanup_on_startup {
  my ($self) = @_;
}

sub cleanup_on_exit {
  my ($self) = @_;
  my $rmq = Kanku::RabbitMQ->new(%{$self->rabbit_config});
  $rmq->shutdown_file($self->shutdown_file);
  $rmq->connect() || die "Could not connect to rabbitmq\n";

  my $exchange='kanku.to_dispatcher';

  $self->logger->info("Deleting exchange $exchange");

  $rmq->queue->exchange_delete(
    $rmq->channel,
    $exchange
  );
}

sub initialize {
  my ($self) = @_;
  my $rmq = Kanku::RabbitMQ->new(%{$self->rabbit_config});
  $rmq->shutdown_file($self->shutdown_file);
  $rmq->connect() || die "Could not connect to rabbitmq\n";

  my $exchange='kanku.to_dispatcher';

  $self->logger->info("Declaring exchange $exchange");

  $rmq->queue->exchange_declare(
    $rmq->channel,
    $exchange
  );

}

1;
