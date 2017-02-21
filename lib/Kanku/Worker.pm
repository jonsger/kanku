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
use Kanku::Config::Worker;
use Sys::CPU;
use Sys::LoadAvg qw( loadavg );
use Sys::MemInfo qw(totalmem freemem);

with 'Kanku::Roles::Logger';


sub run {
  my $self   = shift;

  my $cfg    = Kanku::Config::Worker->new();
  my $config = $cfg->load_config();

  my $logger = $self->logger();

  $logger->debug("kanku worker config:\n".Dumper($config));

  my $kmq    = Kanku::MQ->new(%{ $config->{rabbitmq} || {}});
  my $mq     = $kmq->mq;

  $logger->info("Started consumer '".$kmq->consumer_id."' with PID $$\n");

  while (1) {

    my $msg = $mq->recv();
    
    my $data;
    my $body = $msg->{body};
    try {
	  $data = decode_json($body);
    } catch {
	  print "Error in JSON:\n$_\n$body\n";
    };

    if ( $data->{action} eq 'advertise_task' ) {
	    print "### INCOMMING ADVERTISEMENT:\n".Dumper($data);

	    if ( $data->{answer_queue} ) {

		    my $task_id = $data->{id};

		    my $answer = "Process '$$' is applying for task '$task_id'";

		    my $application = {
			  task_id		  => $task_id, 
			  message		  => $answer , 
			  worker_pid	  => $$,
			  answer_queue  => $kmq->queue_name,
			  resources	  => collect_resources()
		    };

		    print "### OUTGOING APPLICATION:\n".Dumper($application);

		    my $json;
		    $json = encode_json($application);

		    $mq->publish(1, $data->{answer_queue}, $json);

		    # TODO: Need timeout
		    my $msg = $mq->recv();
		    my $body = decode_json($msg->{body});
		    if ( $body->{action} eq 'offer_task' ) {
			  print "#### STARTING with TASK\n".Dumper($body);
			  print "Doing task\n";
			  print "task finished\n";
			  print "  Sending back result\n";
			  
			  $kmq->mq->publish(
			    $kmq->channel,
			    $body->{answer_queue},
			    encode_json({
				  action => 'finished_task',
				  state  => 'succeed'
			    })
			  );
		    } elsif ( $body->{action} eq 'decline_application' ) {
			  print "Nothing to do - application declined\n";
		    } else {
			  print "ERROR: Answer unknown\n";
		    }

	    } else {
		  print STDERR "No answer queue found. Ignoring advertisement\n";
	    }
    }

  }

  $mq->disconnect();

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
