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
use Kanku::MQ;
use Kanku::Task;
use Kanku::Task::Local;
use Kanku::Task::Remote;
use Kanku::Task::RemoteAll;
use Try::Tiny;

with 'Kanku::Roles::Dispatcher';
with 'Kanku::Roles::ModLoader';

has 'max_processes' => (is=>'rw',isa=>'Int',default=>5);

has kmq => (is=>'rw',isa=>'Object');

has job => (is=>'rw',isa=>'Object');

has job_queue => (is=>'rw',isa=>'Object');

has wait_for_workers => (is=>'ro',isa=>'Int',default=>1);

sub run_job {
  my ($self, $job) = @_;

  $self->job($job);

  $self->start_job($job);
  $job->masterinfo($$);

  my $logger       = $self->logger();
  my $queue        = "scheduler-task-".$job->id;

  my $kmq          = Kanku::MQ->new(dispatcher  => 1);

  die "Could not get kmq" if (! $kmq);

  $logger->info("Starting new job '".$job->name."' with id ".$job->id." (Running as pid $$)");

  $self->kmq($kmq);

  my $applications = $self->advertise_job( 
    $kmq,
    {
       answer_queue	  => $queue,
       job_id	  	  => $job->id,
    }
  );

 

  $logger->trace("List of all applications:\n" . Dumper($applications));

  # pa = prefered_application
  my ($pa,$declined_applications) = $self->score_applications($applications);

  $self->decline_applications($declined_applications);

  my $result = $self->send_job_offer($pa);

  my $aq = $pa->{answer_queue};

  $self->kmq(
    Kanku::MQ->new(
      dispatcher  => 1,
      queue_name  => $aq,
      routing_key => $aq
    )
  );

  $job->workerinfo($pa->{worker_fqhn}.":".$pa->{worker_pid}.":".$aq);
  $logger->trace("Result of job offer:\n".Dumper($result));

  my $job_definition = $self->load_job_definition($job);

  if ( ! $job_definition) {
    $logger->error("No job definition found!");
    return "failed";
  }

  my $args              = $self->prepare_job_args($job);

  return 1 if (! $args);

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
          kmq       => $kmq,
          queue     => $aq
        );

        last if ( $last_task->state eq 'failed' or $job->skipped);
      }
  } catch {
    $job->state('failed');
    $job->result(encode_json({error_msg=>$_}));
  };

  $self->send_finished_job($aq,$job->id);

  $self->end_job($job,$last_task);

  $job->state($last_task->state);

  $self->run_notifiers($job,$last_task);

  $kmq->mq->disconnect;

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
    options   => $opts{options} || {},
    schema    => $self->schema,
    scheduler => $opts{scheduler},
    args      => $opts{args},
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
      kmq => $self->kmq,
      job_queue => $self->job_queue,
      queue           => $opts{queue},
    );

  } elsif ( $distributable == 2 ) {

    $tr = Kanku::Task::RemoteAll->new(
      %defaults,
      kmq             => $self->kmq,
      job_queue       => $self->job_queue,
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
  
  foreach my $queue( keys(%$declined_applications) ) {
	$self->kmq->mq->publish(
      $self->kmq->channel,
      $queue,
      encode_json({action => 'decline_application'}),
      {}
    );
  }

}

sub send_job_offer {
  my ($self,$prefered_application)=@_;
  my $kmq    = $self->kmq;
  my $logger = $self->logger;

  die "Could not get kmq" if (! $kmq);

  $logger->debug("Offering job for prefered_application");
  $logger->trace(Dumper($prefered_application));

  $kmq->mq->publish(
	$kmq->channel,
	$prefered_application->{answer_queue},
	encode_json(
		{
		  action			=> 'offer_job',
		  answer_queue		=> $self->job_queue->queue_name
		}
	)
  );
}

sub send_finished_job {
  my ($self, $aq, $job_id)=@_;
  my $kmq    = $self->kmq;
  my $logger = $self->logger;

  die "Could not get kmq" if (! $kmq);

  $logger->debug("Offering job for prefered_application");
  $logger->trace($aq);

  $kmq->mq->publish(
	$kmq->channel,
    $aq,
	encode_json(
		{
		  action  => 'finished_job',
          job_id  => $job_id
		}
	)
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
  my ($kmq,$opts)           = @_;
  my $all_applications      = {};

  my $data = encode_json({action => 'advertise_job', %$opts});

  $self->logger->debug("creating new queue: ".$opts->{answer_queue});
  $self->job_queue(Kanku::MQ->new());
  $self->job_queue->queue_name($opts->{answer_queue});
  $self->job_queue->connect();
  $self->job_queue->create_queue(exchange_name=>'kanku_to_dispatcher'); 
  my $mq = $self->job_queue->mq; 
  while(! %$all_applications ) {

    $kmq->mq->publish(
      $kmq->channel, 
      '',
      $data, 
      { exchange => 'kanku_to_all_workers' }
    );

    sleep($self->wait_for_workers);

    #$kmq = Kanku::MQ->new(queue_name=>'applications');
    while ( my $msg = $mq->recv(100) ) {
      if ($msg ) {
          my $data;
          $self->logger->debug("Incomming application");
          $self->logger->trace(Dumper($msg));
          my $body = $msg->{body};
          try { 
            $data = decode_json($body);
            $all_applications->{$data->{answer_queue}} = $data;
          } catch {
            $self->logger->debug("Error in JSON:\n$_\n$body\n");
          };
      }
    }

    #if ( ! %$all_applications ){
      #$self->logger->warn("Got no appliacations - waiting for another $wait_for_applications second(s)");
    #}
  }

  return $all_applications;
}

1;
