package Kanku::Task::Remote;


=head1 NAME

Kanku::Task::Remote - Run task on specific worker

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

TODO - add a useful description

=head1 AUTHORS

Frank Schreiner, <fschreiner@suse.de>

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

has kmq => (is=>'rw',isa=>'Object');

has job => (is=>'rw',isa=>'Object');

has job_queue => (is=>'rw',isa=>'Object');

has wait_for_workers => (is=>'ro',isa=>'Int',default=>1);

sub run {
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
          context     => $opts->{job}->context,
          name        => $opts->{job}->name,
          id          => $opts->{job}->id,
        },
        module      => $opts->{module},
        final_args  => {%{$opts->{options}},%{$opts->{args}}}
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

__PACKAGE__->meta->make_immutable();

1;
