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
package Kanku::MQ;

use Moose;

use Net::AMQP::RabbitMQ;
use JSON::XS;
use Data::Dumper;
use UUID ':all';

with 'Kanku::Roles::Logger';

has 'channel'	=> (is=>'rw',isa=>'Int',default => 1);
has 'dispatcher' => (is=>'rw',isa=>'Int',default => 0);

has [qw/
  host vhost user password
  queue_name
  exchange_name
  routing_key
  consumer_id
/] => (is=>'rw',isa=>'Str');

has '+host'	      => ( default => 'localhost');
has '+vhost'	      => ( default => '/kanku');
has '+user'	      => ( default => 'kanku');
has '+password'	      => ( default => 'guest');
has '+queue_name'     => ( default => 'dispatcher');
has '+exchange_name'  => ( default => 'task_adv_exchange');
has '+routing_key'    => ( default => '');

has mq => (
	  is	  => 'rw', 
	  isa	  => 'Object',
	  lazy	  => 1,
	  default => 
sub {

  my $self = shift;

  my $mq = $self->connect();

  $self->setup($mq);

  # don`t create worker queue for scheduler
  if ($self->dispatcher) {
    my $queue = $mq->queue_declare(
      $self->channel,
      'applications'
    );
    $mq->queue_bind(
      $self->channel,
      'applications',
      'kanku_to_dispatcher',
      '',
      {}
    );
  } else {

    $self->queue_name(uuid());
    $self->routing_key($self->queue_name());
    my $queue = $mq->queue_declare($self->channel,$self->queue_name);

    $mq->queue_bind(
      $self->channel,
      $self->queue_name,
      'kanku_to_all_workers',
      '',
      {}
    );

    $self->consumer_id( $mq->consume(1, $self->queue_name) );
  }
 
  return $mq;
}
);

sub connect {
  my ($self) = @_;

  my $mq = Net::AMQP::RabbitMQ->new();

  my @opts = (
    $self->host,
    { 
      vhost		=> $self->vhost, 
      user		=> $self->user,
      password	=> $self->password
    }
  );

  $self->logger->debug("Trying to connect to rabbitmq with the folloing options:\n".Dumper(\@opts));

  $mq->connect(@opts);

  $mq->channel_open($self->channel);

  return $mq;
}

sub connect_info {
  my ($self) = @_;
  return  {
    host      => $self->host,
    vhost     => $self->vhost, 
    user      => $self->user,
    password  => $self->password
  };

}

sub setup {
  my ($self,$mq)=@_;
  
  $mq->exchange_declare(
    $self->channel,
    'kanku_to_all_workers',
    { exchange_type => 'fanout' }
  );

  $mq->exchange_declare(
    $self->channel,
    'kanku_to_dispatcher',
    { exchange_type => 'direct' }
  );

}

sub shutdown {
  my $self = shift;
}

sub recv {
  my $self = shift;

  my $logger = $self->logger;

  $logger->debug("Waiting for message on channel: '".$self->channel."' queue: '".$self->queue_name."' routing_key: '".$self->routing_key."'");

  return $self->mq->recv(@_);
}

sub publish {
  my $self = shift;

  my $logger = $self->logger;

  $logger->debug("Publishing message on channel: '".$self->channel."' queue: '".$self->queue_name."' routing_key: '".$self->routing_key."'");

  return $self->mq->publish($self->channel,$self->routing_key,@_);
}

sub create_queue {
  my $self = shift;
  my %opts = @_;

  die "No exchange name given in options" if (! $opts{exchange_name});

  $self->logger->debug("Creating new queue ('".join("','",$self->channel,$self->queue_name,$opts{exchange_name},$self->queue_name)."')");

  # FIXME: Dirty hack for now - needs refactoring urgently

  my $mq = $self->mq($self->connect()); 

  $mq->queue_declare($self->channel,$self->queue_name);
  $mq->queue_bind($self->channel,$self->queue_name,$opts{exchange_name},$self->queue_name,{});
  $mq->consume($self->channel,$self->queue_name);

  return $mq;
}
  #
1; 

