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

has 'max_processes' => (is=>'rw',isa=>'Int',default=>5);

sub run {
  my $self = shift;
    my $jobcount = 0;

    my @child_pids = ();


    while (1) {

      debug("Please Type Your message and hit ENTER:\n");

      $jobcount++;
      my $msg = <>;
      chomp $msg;

      last if ( $msg eq "quit");

      my $pid = fork();
      $SIG{CHLD} = 'IGNORE';

      if ( $pid ) {
        push (@child_pids,$pid);
      } else {


        my $queue = "scheduler-task-$jobcount";
        my $kmq = Kanku::MQ->new(
          scheduler => 1,
          queue_name => $queue
        );

        my $applications = advertise_task( 
          $kmq,
          {
              answer_queue	  => $queue,
              message		  => $msg, 
              id			  => $jobcount , 
              pid			  => $pid
          }
        );
        debug("### ALL APPLICATIONS:\n". Dumper($applications));

        my ($prefered_application,$declined_applications) = score_applications($applications);

        decline_applications($kmq,$declined_applications);

        my $result = offer_task($kmq,$prefered_application);

        debug("### RESULT:\n".Dumper($result));

        debug("Child exiting\n");

        $kmq->mq->disconnect;

        exit 0;

      }

      while ( @child_pids > $self->max_processes ) {
        @child_pids = grep { $_ == waitpid($_,WNOHANG) } @child_pids;
        sleep(1);
        debug("ChildPids: @child_pids\n");
      }

    }
}

sub decline_applications {
  my ($kmq,$declined_applications) = @_;

  foreach my $queue( keys(%$declined_applications) ) {
	$kmq->mq->publish($kmq->channel,$queue,encode_json({action => 'decline_application'}),{});
  }

}


sub offer_task {

  my ($kmq,$prefered_application)=@_;

  $kmq->mq->publish(
	$kmq->channel,
	$prefered_application->{answer_queue},
	encode_json(
		{
		  action			=> 'offer_task',
		  answer_queue		=> $kmq->queue_name
		}
	)
  );

  my $timeout_in_min = 120;

  # recv timeout is calculated in milliseconds
  my $msg = $kmq->mq->recv($timeout_in_min * 60 * 1000);
  if ($msg ) {
	my $data;
	debug("### INCOMMING RESULT:\n". Dumper($msg));
	my $body = $msg->{body};
	try { 
	  return decode_json($body);
	} catch {
		debug("Error in JSON:\n$_\n$body\n");
	};
  } else {
	return { error => "timeout" }
  }
}

sub score_applications {
  my ($applications) = @_;

  my $pref;

  my @keys = keys(%$applications);

  my $key = shift(@keys);
  
  my $ret = $applications->{$key};
  delete $applications->{$key};

  return ($ret,$applications);

};


sub advertise_task {
  my ($kmq,$opts)=@_;
  my $all_applications = {};
  my $wait_for_applications = 1;

  my $data = encode_json({action => 'advertise_task', %$opts});

  $kmq->mq->publish(
	$kmq->channel, 
	$kmq->routing_key, 
	$data, 
	{ exchange => $kmq->exchange_name }
  );

  sleep($wait_for_applications);

  while ( my $msg = $kmq->mq->recv(100) ) {
	if ($msg ) {
		my $data;
		debug("### INCOMMING APPLICATION:\n". Dumper($msg));
		my $body = $msg->{body};
		try { 
		  $data = decode_json($body);
		  $all_applications->{$data->{answer_queue}} = $data;
		} catch {
			debug("Error in JSON:\n$_\n$body\n");
		};
	}
  }

  return $all_applications;
}

sub debug {
  print "[$$] - @_\n";
}

1;
