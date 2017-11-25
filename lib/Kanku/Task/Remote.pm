# Copyright (c) 2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
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

with 'Kanku::Roles::Logger';

use Data::Dumper;
use JSON::XS;
use Try::Tiny;
use MIME::Base64;

has job => (is=>'rw',isa=>'Object');

has module => (is=>'rw',isa=>'Str');

has [qw/job_queue daemon/]=> (is=>'rw',isa=>'Object');

has wait_for_workers => (is=>'ro',isa=>'Int',default=>1);

has final_args => (is=>'rw',isa=>'HashRef');

has queue => (is=>'rw',isa=>'Str');

has rabbit_config => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  default => sub { Kanku::Config->instance->config->{"Kanku::RabbitMQ"} || {}; }
);


sub run {
  my ($self)      = @_;
  my $kmq         = $self->job_queue;
  my $all_workers = {};
  my $logger      = $self->logger;

  $self->logger->debug("Starting new remote task");

  my $job = $self->job;

  my $data = encode_json(
    {
      action => 'task',
      answer_queue => $self->job_queue->queue_name,
      job_id => $job->id,
      task_args => {
        job       => {
          context     => $job->context,
          name        => $job->name,
          id          => $job->id,
        },
        module      => $self->module,
        final_args  => $self->final_args,
      }
    }
  );

  $logger->debug("Sending remote job: ".$self->module);
  $logger->debug(" - channel: ".$kmq->channel);
  $logger->debug(" - routing_key ".$kmq->routing_key);
  $logger->debug(" - queue_name ".$self->queue);
  $logger->trace(Dumper($data));

  $kmq->queue->publish(
	$kmq->channel,
	$self->queue,
	$data,
  );

  $self->logger->debug("Waiting for result on queue: ".$self->job_queue->queue_name());
  # Wait for task results from worker
  my $result;
  my $state;
  while (1){
    my $msg = $self->job_queue->recv(10000);
    if ( $msg ) {
      my $data;
      $self->logger->debug("Incomming task result");
      $self->logger->trace(Dumper($msg));
      my $body = $msg->{body};

      try {
	$data = decode_json($body);
      } catch {
	$self->logger->debug("Error in JSON:\n$_\n$body\n");
      };

      if (
	$data->{action} eq 'finished_task' or
	$data->{action} eq 'aborted_job'
      ) {
	$logger->trace("Content of \$data:\n".Dumper($data));
	if ( $data->{error_message} ) {
	  die $data->{error_message};
	} else {
	  my $job = decode_json($data->{job});
          $logger->debug("Content of \$data->result: ".Dumper($data->{result}));

          try {
            $data->{result}->{result} = decode_base64($data->{result}->{result}) if ($data->{result}->{result});
            $result = $data->{result};
             $logger->debug("Content of \$data->result->{result}: $data->{result}->{result}");
          } catch {
            $logger->fatal("Error while decoding base64: $_");
            $logger->debug(Dumper($data));
            $data->{result} = "Error while decoding base64: $_";
          };

	  $self->job->context(${job}->{context});
	  last;
	}
      } elsif ($data->{action} eq 'apply_for_job') {
        $logger->warn("Got application from $data->{worker_fqhn} for already running job($data->{job_id}). Declining!");
        my $rmq = Kanku::RabbitMQ->new(%{$self->rabbit_config});
        $rmq->connect(no_retry=>1) ||
            $logger->error("Could not connect to rabbitmq");
        my $queue = $data->{answer_queue};
        $rmq->queue_name($queue);
        $rmq->publish(
          $queue,
          encode_json({action => 'decline_application'}),
        );
      }
    } else {
      if ($self->daemon->detect_shutdown) {
	die "Job ".$job->id." aborted by dispatcher daemon shutdown\n";
      }
    }
  }
  return $result
}

__PACKAGE__->meta->make_immutable();

1;
