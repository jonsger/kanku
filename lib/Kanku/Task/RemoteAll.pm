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
package Kanku::Task::RemoteAll;

=head1 NAME

Kanku::Dispatch::RabbitMQ - TODO: comment

=head1 SYNOPSIS

|scheduler.pl <required-options> [optional options]

=head1 DESCRIPTION

FIXME: add a useful description

=head1 AUTHORS

Frank Schreiner, <fschreiner@suse.de>

=cut

use Moose;

our $VERSION = "0.0.1";

with 'Kanku::Roles::Logger';

use Data::Dumper;
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

  $logger->debug("Starting new remote-all task");

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
		$logger->debug("Incomming task confirmation");
        $logger->trace(Dumper($msg));

		my $body = $msg->{body};
		try {
		  $data = decode_json($body);
		  $all_workers->{task_confirmation}->{$data->{answer_queue}} = $data;
		} catch {
		  $logger->debug("Error in JSON:\n$_\n$body\n");
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

__PACKAGE__->meta->make_immutable;
1;
