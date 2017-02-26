package Kanku::Worker;

use Moose;

our $VERSION = "0.0.1";

use FindBin;
use lib "$FindBin::Bin/lib";
use Data::Dumper;
use POSIX;
use JSON::XS;
use Try::Tiny;
use Kanku::MQ;
use Kanku::Config;
use Kanku::Config::Worker;
use Kanku::Task::Local;
use Kanku::Job;
use Sys::CPU;
use Sys::LoadAvg qw( loadavg );
use Sys::MemInfo qw(totalmem freemem);
use Carp;
use Net::Domain qw/hostfqdn/;

with 'Kanku::Roles::Logger';
with 'Kanku::Roles::ModLoader';

has child_pids => (is=>'rw',isa=>'ArrayRef',default => sub {[]});
has kmq => (is=>'rw',isa=>'Object');
has schema => (is=>'rw',isa=>'Object');
has job_queue_name => (is=>'rw',isa=>'Str');

sub run {
  my $self   = shift;

  Kanku::Config->initialize();

  my $cfg    = Kanku::Config::Worker->new();
  my $config = $cfg->load_config();

  my $logger = $self->logger();

  $logger->debug("kanku worker config:\n".Dumper($config));

  $self->kmq(Kanku::MQ->new(%{ $config->{rabbitmq} || {}}));

  my $mq     = $self->kmq->mq;

  $logger->info("Started consumer '".$self->kmq->consumer_id."' with PID $$\n");

  while (1) {

    my $msg = $mq->recv();
    
    my $data;
    my $body = $msg->{body};
    try {
	  $data = decode_json($body);
    } catch {
	  $logger->error("Error in JSON:\n$_\n$body\n");
    };

    if ( $data->{action} eq 'advertise_job' ) {
      $self->handle_advertisement($data);
    } elsif ( $data->{action} eq 'send_task_to_all_workers' ) {
      $self->handle_task($data);
    }
  }

  $mq->disconnect();
}

sub handle_advertisement {
  my ($self, $data) = @_;
  my $kmq    = $self->kmq;
  my $mq     = $kmq->mq;
  my $logger = $self->logger();

  $logger->debug("Starting to handle advertisement");
  $logger->trace(Dumper($data));

  if ( $data->{answer_queue} ) {

      my $job_id = $data->{job_id};

      my $answer = "Process '$$' is applying for job '$job_id'";

      my $application = {
        job_id		  => $job_id, 
        message		  => $answer ,
        worker_fqhn   => hostfqdn(),
        worker_pid	  => $$,
        answer_queue  => $kmq->queue_name,
        resources	  => collect_resources(),
      };
      $logger->debug("Sending apllication for job_id $job_id on queue ".$data->{answer_queue});
      $logger->trace(Dumper($application));

      my $json = encode_json($application);

      $mq->publish(
        1, 
        $data->{answer_queue}, 
        $json,
        { exchange => 'kanku_to_dispatcher' }
      );

      # TODO: Need timeout
      my $msg = $mq->recv();
      my $body = decode_json($msg->{body});
      if ( $body->{action} eq 'offer_job' ) {
        $logger->info("Starting with job ");
        $logger->trace(Dumper($msg,$body));
        $self->job_queue_name($body->{answer_queue});
        $self->handle_job($job_id);

      } elsif ( $body->{action} eq 'decline_application' ) {
        $logger->debug("Nothing to do - application declined");
      } else {
        $logger->error("Answer on application for job $job_id unknown");
        $logger->trace(Dumper($msg,$body));
      }

  } else {
    $logger->error("No answer queue found. Ignoring advertisement");
  }
}

sub handle_job {
  my ($self,$job_id) = @_;
  my $kmq    = $self->kmq;
  my $mq     = $kmq->mq;
  my $logger = $self->logger;


  try  {
    $logger->debug("Waiting for messages on ".$kmq->channel." / ".$kmq->routing_key." / ".$kmq->queue_name);

    while ( my $task_msg = $mq->recv() ) {
      my $task_body = decode_json($task_msg->{body});
      $logger->debug("Got new message while waiting for tasks");
      $logger->trace(Dumper($task_body));
      if ( 
        ( $task_body->{action} eq 'task' and $task_body->{job_id} == $job_id )
        or $task_body->{action} eq 'send_task_to_all_workers'
      ){
        $logger->info("Starting with task");
        $logger->trace(Dumper($task_msg,$task_body));
        $self->handle_task($task_body,$mq);
      }
      last if ( $task_body->{action} eq 'finished_job' and $task_body->{job_id} == $job_id);
      $logger->debug("Waiting for next task");
    }
  } catch {
    my $e = $_;
    $logger->error($e);

    $mq->publish(
      $kmq->channel,
      $self->job_queue_name,
      encode_json({
        action => 'finished_task',
        error_message =>$e
      })
    );
  };

  $logger->info("Finished job $job_id");
}

sub handle_task {
  my ($self, $data) = @_;

  confess "Got no task_args" if (! $data->{task_args});

  $self->logger->trace("task_args:\n".Dumper($data->{task_args}));

  # create object from serialized data 
  my $job = Kanku::Job->new($data->{task_args}->{job});
  $data->{task_args}->{job}=$job;

  my $task   = Kanku::Task::Local->new(%{$data->{task_args}},schema => $self->schema);

  my $result = $task->execute_all();

  $self->kmq->mq->publish(
    $self->kmq->channel,
    $self->job_queue_name,
	encode_json({
	  action        => 'finished_task',
      result        => $result,
      answer_queue  => $self->kmq->queue_name,
      job           => $job->to_json
	}),
    { exchange => 'kanku_to_dispatcher'}
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

1;
