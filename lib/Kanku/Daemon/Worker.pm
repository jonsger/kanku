package Kanku::Daemon::Worker;

use Moose;

our $VERSION = "0.0.1";

use FindBin;
use lib "$FindBin::Bin/lib";
use Data::Dumper;
use POSIX;
use JSON::XS;
use Try::Tiny;
use Kanku::MQ;
use Kanku::RabbitMQ;
use Kanku::Config;
use Kanku::Task::Local;
use Kanku::Job;
use Sys::CPU;
use Sys::LoadAvg qw( loadavg );
use Sys::MemInfo qw(totalmem freemem);
use Carp;
use Net::Domain qw/hostfqdn/;
use UUID qw/uuid/;
use MIME::Base64;

with 'Kanku::Roles::Logger';
with 'Kanku::Roles::ModLoader';
with 'Kanku::Roles::DB';
with 'Kanku::Roles::Daemon';

has child_pids => (is=>'rw',isa=>'ArrayRef',default => sub {[]});
has kmq => (is=>'rw',isa=>'Object');
has job_queue_name => (is=>'rw',isa=>'Str');
has remote_job_queue_name => (is=>'rw',isa=>'Str');
has local_job_queue_name => (is=>'rw',isa=>'Str');
has worker_id => (is=>'rw',isa=>'Str',default => sub {uuid()});

sub run {
  my $self   = shift;

  my $config = Kanku::Config->instance->config->{ref($self)};
  my $logger = $self->logger();

  my @childs=();

  my $pid;

  # for host queue
  $pid = fork();

  if (! $pid ) {
    while(1) {
      try {
        my $kmq = Kanku::RabbitMQ->new(%{ $config->{rabbitmq} || {}});
        $kmq->shutdown_file($self->shutdown_file);
        $kmq->connect() or die "Could not connect to rabbitmq\n";
        $kmq->setup_worker();
        $self->local_job_queue_name(hostfqdn());
        $kmq->create_queue(
	  queue_name=>$self->local_job_queue_name,
	  exchange_name=>'kanku.to_all_hosts'
        );
	my $msg = $kmq->recv(1000);
	if ($msg) {
	  my $data;
	  my $body = $msg->{body};
          # Extra try/catch to get better debugging output
          # like adding body to log message
	  try {
	    $data = decode_json($body);
	  } catch {
	    die("Error in JSON:\n$_\n$body\n");
	  };

	  if ( $data->{action} eq 'send_task_to_all_workers' ) {
	    my $answer = {
	      action => 'task_confirmation',
	      task_id => $data->{task_id},
	      # answer_queue is needed on dispatcher side
	      # to distinguish the results per worker host
	      answer_queue => $self->local_job_queue_name
	    };
	    $self->remote_job_queue_name($data->{answer_queue});
	    $kmq->publish(
	      $self->remote_job_queue_name,
	      encode_json($answer),
	      { exchange => 'kanku.to_dispatcher'}
	    );

	    $self->handle_task($data,$kmq);
	  } else {
	    $logger->warn("Unknown action: ". $data->{action});
	  }
	}
      } catch {
	$logger->error($_);
      };
      $self->remote_job_queue_name('');
      $self->local_job_queue_name('');
      if ($self->detect_shutdown) {
	$logger->info("AllWorker process detected shutdown - exiting");
	exit 0;
      }
    }
  } else {
    push(@childs,$pid);
  }

  # wait for advertisements

  $pid = fork();

  if (! $pid ) {
    while (1) {
      try {
        my $kmq = Kanku::RabbitMQ->new(%{ $config->{rabbitmq} || {}});
        $kmq->shutdown_file($self->shutdown_file);
        $kmq->connect() or die "Could not connect to rabbitmq\n";
	$kmq->setup_worker();
	$kmq->create_queue(
	  queue_name    => $self->worker_id,
	  exchange_name =>'kanku.to_all_workers'
	);
	$self->logger->debug("Waiting for message (1000) ms");
	my $msg  = $kmq->recv(1000);
	if ( $msg ) {
	  my $body = $msg->{body};
	  my $data;

	  try {
	    $data = decode_json($body);
	  } catch {
	    die("Error in JSON:\n$_\n$body\n");
	  };

	  if ( $data->{action} eq 'advertise_job' ) {
	    $self->handle_advertisement($data, $kmq);
	  }

	  $kmq->queue->disconnect();
	}
      } catch {
        $logger->error($_);
      };
      if ($self->detect_shutdown) {
        $logger->info("Worker process '$$' detected shutdown - exiting");
        exit 0;
      }
    }
  } else {
    push(@childs,$pid);
  }

  while (@childs) {
    @childs = grep { waitpid($_,WNOHANG) == 0 } @childs;
    $logger->trace("Active Childs: (@childs)");
    sleep(1);
  }

  $logger->info("No more childs running, returning from Daemon->run()!");
  return;
}

sub handle_advertisement {
  my ($self, $data, $kmq) = @_;
  my $logger = $self->logger();

  $logger->debug("Starting to handle advertisement");
  $logger->trace(Dumper($data));

  if ( $data->{answer_queue} ) {
      $self->remote_job_queue_name($data->{answer_queue});
      my $job_id = $data->{job_id};
      $self->local_job_queue_name("job-$job_id-".$self->worker_id);
      my $answer = "Process '$$' is applying for job '$job_id'";

      my $job_kmq = Kanku::RabbitMQ->new(%{$kmq->connect_info},queue_name =>$self->local_job_queue_name);
      $job_kmq->connect();
      $job_kmq->create_queue();

      my $application = {
        job_id		  => $job_id,
        message		  => $answer ,
        worker_fqhn   => hostfqdn(),
        worker_pid	  => $$,
        answer_queue  => $self->local_job_queue_name,
        resources	  => collect_resources(),
      };
      $logger->debug("Sending apllication for job_id $job_id on queue ".$self->remote_job_queue_name);
      $logger->trace(Dumper($application));

      my $json    = encode_json($application);


      $kmq->publish(
        $self->remote_job_queue_name,
        $json,
        { exchange => 'kanku.to_dispatcher', mandatory => 1 }
      );

      # TODO: Need timeout
      my $msg = $job_kmq->recv();
      my $body = decode_json($msg->{body});
      if ( $body->{action} eq 'offer_job' ) {
        $logger->info("Starting with job ");
        $logger->trace(Dumper($msg,$body));

        $self->handle_job($job_id,$job_kmq);
        return;
      } elsif ( $body->{action} eq 'decline_application' ) {
        $logger->debug("Nothing to do - application declined");
        $self->remote_job_queue_name('');
        $self->local_job_queue_name('');
        return;
      } else {
        $logger->error("Answer on application for job $job_id unknown");
        $logger->trace(Dumper($msg,$body));
      }

  } else {
    $logger->error("No answer queue found. Ignoring advertisement");
  }

  return;
}

sub handle_job {
  my ($self,$job_id,$job_kmq) = @_;
  my $logger = $self->logger;

  $SIG{TERM} = sub {
    my $answer = {
	action        => 'aborted_job',
	error_message => "Aborted job because of TERM signal",
    };

    $self->logger->trace("Sending answer to '".$self->remote_job_queue_name."':\n".Dumper($answer));

    $job_kmq->publish(
      $self->remote_job_queue_name,
      encode_json($answer),
      { exchange => 'kanku.to_dispatcher'}
    );

    exit 0;
  };

  try  {
    while (1){
      my $task_msg = $job_kmq->recv(10000);
      if ( $task_msg ) {
        my $task_body = decode_json($task_msg->{body});
        $logger->debug("Got new message while waiting for tasks");
        $logger->trace(Dumper($task_body));
        if (
           $task_body->{action} eq 'task' and $task_body->{job_id} == $job_id
        ){
          $logger->info("Starting with task");
          $logger->trace(Dumper($task_msg,$task_body));

          $self->handle_task($task_body,$job_kmq,$job_id);
        }
        if ( $task_body->{action} eq 'finished_job' and $task_body->{job_id} == $job_id) {
          $logger->debug("Got finished_job for job_id: $job_id");
          last;
        }
        $logger->debug("Waiting for next task");
      } else {

        if ( $self->detect_shutdown ) {
          my $answer = {
              action        => 'aborted_job',
              error_message => "Aborted job because of daemon shutdown",
          };

          $self->logger->trace("Sending answer to '".$self->remote_job_queue_name."':\n".Dumper($answer));

          $job_kmq->publish(
            $self->remote_job_queue_name,
            encode_json($answer),
            { exchange => 'kanku.to_dispatcher'}
          );

          exit 0;
        }
      }
    }
  } catch {
    my $e = $_;
    $logger->error($e);

    $job_kmq->publish(
      $self->remote_job_queue_name,
      encode_json({
        action        => 'finished_task',
        error_message => $e
      }),
      { exchange => 'kanku.to_dispatcher' }
    );
    my $task_msg = $job_kmq->recv(10000);
    my $task_body = decode_json($task_msg->{body});
    if ( $task_body->{action} eq 'finished_job' and $task_body->{job_id} == $job_id) {
      $logger->debug("Got finished_job for job_id: $job_id");
      return;
    } else {
      $logger->debug("Unknown answer when waitingin for finish_job:");
      $logger->trace(Dumper($task_body));
    }
  };

  return;
}

sub handle_task {
  my ($self, $data, $job_kmq, $job_id) = @_;

  confess "Got no task_args" if (! $data->{task_args});

  $self->logger->trace("task_args:\n".Dumper($data->{task_args}));

  # create object from serialized data
  my $job = Kanku::Job->new($data->{task_args}->{job});
  $data->{task_args}->{job}=$job;

  my $task   = Kanku::Task::Local->new(%{$data->{task_args}},schema => $self->schema);

  my $result = $task->run();
  $result->{result} = encode_base64($result->{result}) if ($result->{result});
  my $answer = {
      action        => 'finished_task',
      result        => $result,
      answer_queue  => $self->local_job_queue_name,,
      job           => $job->to_json
  };

  $self->logger->trace("Sending answer to '".$self->remote_job_queue_name."':\n".Dumper($answer));

  $job_kmq->publish(
    $self->remote_job_queue_name,
	encode_json($answer),
    { exchange => 'kanku.to_dispatcher'}
  );
}

sub collect_resources {

  return {
	total_cpus	  => Sys::CPU::cpu_count(),
	free_cpus	  => Sys::CPU::cpu_count() - 1, # TODO - calculate how much CPU's used by running VM's
	total_ram	  => totalmem(),
	free_ram	  => freemem,
	load_avg	  => [ loadavg() ]
  }

}

__PACKAGE__->meta->make_immutable();
1;
