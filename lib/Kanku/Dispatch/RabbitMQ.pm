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

use FindBin;
use lib "$FindBin::Bin/lib";
use Data::Dumper;
use POSIX;
use JSON::XS;
use Kanku::MQ;
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

  my $state             = '';
  my $args              = $self->prepare_job_args($job);

  return 1 if (! $args);

  $logger->trace("  -- args:\n".Dumper($args));

  my $last_task;

  foreach my $sub_task (@{$job_definition}) {
    my $task_args = shift(@$args) || {};
    my $task = $self->run_task(
      job       => $job,
      options   => $sub_task->{options} || {},
      module    => $sub_task->{use_module},
      scheduler => $self,
      args      => $task_args,
      kmq       => $kmq,
      queue     => $aq
    );
    $last_task = $task;

    last if ( $task eq 'failed' or $job->skipped);
  }

  $self->end_job($job,$state);

  $self->send_finished_job($aq,$job->id);

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

  if ( $distributable == 0 ) {
    return $self->run_task_locally(\%opts);
  } elsif ( $distributable == 1 ) {
    return $self->run_task_remote(\%opts);
  } elsif ( $distributable == 2 ) {
    return $self->run_task_on_all_workers(\%opts);
  } else {
    die "Unknown distributable value '$distributable' for module $mod\n"
  }
}

sub run_task_locally {
  my ($self,$opts) = @_;

  $self->logger->debug("Starting new local task");

  my $task = Kanku::Task->new(
    job       => $opts->{job},
    options   => $opts->{options} || {},
    module    => $opts->{module},
    schema    => $self->schema,
    scheduler => $opts->{scheduler},
    args      => $opts->{args},
  );

  return $task->run();
}

sub run_task_remote {
  my ($self,$opts) = @_;
  my $kmq = $self->kmq;
  my $all_workers = {};
  my $logger      = $self->logger;

  $self->logger->debug("Starting new remote task");


  my $data = encode_json(
    {
      action => 'task',
      answer_queue => $self->job_queue->queue_name,
      job_id => $opts->{job}->id,
      task_args => {
        job       => {
          context    => $opts->{job}->context,
          name       => $opts->{job}->name,
          id         => $opts->{job}->id,
        },
        module    => $opts->{module},
        final_args      => {%{$opts->{options}},%{$opts->{args}}}
      }
    }
  );

  $logger->debug("Sending remote job: ".$opts->{module});
  $logger->debug(" - channel: ".$kmq->channel);
  $logger->debug(" - routing_key ".$kmq->routing_key);
  $logger->debug(" - opts queue_name ".$opts->{queue});
  $logger->trace(Dumper($data));

  $kmq->mq->publish(
	$kmq->channel, 
	$opts->{queue},
	$data, 
  );

  $self->logger->debug("Waiting for result on queue: ".$self->job_queue->queue_name());
  # Wait for task results from worker
  while ( my $msg = $self->job_queue->recv() ) {
        my $data;
        $self->logger->debug("Incomming task result");
        $self->logger->trace(Dumper($msg));
        my $body = $msg->{body};

        try { 
          $data = decode_json($body);
        } catch {
          $self->logger->debug("Error in JSON:\n$_\n$body\n");
        };
    if ( $data->{action} eq 'finished_task' ) { 
        $logger->trace(Dumper($data));
        my $job = decode_json($data->{job});
        $self->job->context(${job}->{context});
        last;
    }
  }
}

sub run_task_on_all_workers {
  my ($self,$opts) = @_;
  my $kmq = $self->kmq;
  my $all_workers = {};
  my $logger      = $self->logger;

  $self->logger->debug("Starting new remote-all task");

  my $data = encode_json(
    {
      action => 'send_task_to_all_workers',
      answer_queue => $self->job_queue->queue_name,
      task_args => {
        job       => {
          context    => $opts->{job}->context,
          name       => $opts->{job}->name,
          id         => $opts->{job}->id,
        },
        module    => $opts->{module},
        final_args      => {%{$opts->{options}},%{$opts->{args}}}
      }
    }
  );

  $kmq->mq->publish(
	$kmq->channel, 
	'', 
	$data, 
	{ exchange => 'kanku_to_all_workers' }
  );

  sleep($self->wait_for_workers);

  # Getting response from workers
  while ( my $msg = $self->job_queue->mq->recv(100) ) {
	if ($msg ) {
		my $data;
		$self->logger->debug("Incomming task confirmation\n". Dumper($msg));
		my $body = $msg->{body};
		try { 
		  $data = decode_json($body);
		  $all_workers->{task_confirmation}->{$data->{answer_queue}} = $data;
		} catch {
		  $self->logger->debug("Error in JSON:\n$_\n$body\n");
		};
	}
  }

  # Wait for task results from workers
  my $timeout = 60*60*2; # wait maximum 2 hours
  my $seconds_running=0;
  while ( keys(%{$all_workers->{task_confirmation}}) < keys(%{$all_workers->{task_result}})  ) {
    my $msg = $self->job_queue->mq->recv(1000);
    if ($msg) {
        my $data;
        $logger->debug("Incomming task_result");
        $logger->trace(Dumper($msg));
        my $body = $msg->{body};
        try { 
          $data = decode_json($body);
          $all_workers->{task_result}->{$data->{answer_queue}} = $data;
        } catch {
          $logger->debug("Error in JSON:\n$_\n$body\n");
        };
    }
    if( $seconds_running > $timeout) {
      $logger->warn("Reached timeout of $timeout seconds waiting for all workers to finish");
    }
    $seconds_running++;
  }
  
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
