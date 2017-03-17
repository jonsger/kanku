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
package Kanku::RabbitMQ;

use Moose;

use Net::AMQP::RabbitMQ;
use JSON::XS;
use Data::Dumper;
use UUID ':all';

with 'Kanku::Roles::Logger';

has 'channel' => (is=>'rw',isa=>'Int',default => 1);
has 'port'	  => (is=>'rw',isa=>'Int',default => 5671);

has [qw/ssl ssl_verify_host ssl_init/]	=> (is=>'rw',isa=>'Bool',default => 1);

has [qw/
  host vhost user password
  queue_name
  exchange_name
  routing_key
  consumer_id
  ssl_cacert
/] => (is=>'rw',isa=>'Str');

has '+host'	          => ( default => 'localhost');
has '+vhost'	      => ( default => '/kanku');
has '+user'	          => ( default => 'kanku');
has '+password'	      => ( default => 'guest');
has '+exchange_name'  => ( default => 'amq.direct');
has '+routing_key'    => ( default => '');

has queue => (
	  is	  => 'rw', 
	  isa	  => 'Object',
);

sub connect {
  my ($self) = @_;

  $self->queue(Net::AMQP::RabbitMQ->new());

  my @opts = (
    $self->host,
    { 
      vhost           => $self->vhost,
      user            => $self->user,
      password	      => $self->password,
      port            => $self->port,
      ssl             => $self->ssl,
      ssl_cacert      => $self->ssl_cacert || '',
      ssl_verify_host => $self->ssl_verify_host,
      ssl_init        => $self->ssl_init,
    }
  );

  $self->logger->trace("Trying to connect to rabbitmq with the folloing options:\n".Dumper(\@opts));

  $self->queue->connect(@opts);

  $self->queue->channel_open($self->channel);
}

sub connect_info {
  my ($self) = @_;
  return  {
    host            => $self->host,
    vhost           => $self->vhost, 
    user            => $self->user,
    password        => $self->password,
    port	        => $self->port,
    ssl             => $self->ssl,
    ssl_cacert      => $self->ssl_cacert,
    ssl_verify_host => $self->ssl_verify_host,
    ssl_init        => $self->ssl_init,
  };
}
#
sub setup_worker {
  my ($self,$mq)=@_;
  
  $self->queue->exchange_declare(
    $self->channel,
    'kanku.to_all_workers',
    { exchange_type => 'fanout' }
  );

  $self->queue->exchange_declare(
    $self->channel,
    'kanku.to_all_hosts',
    { exchange_type => 'fanout' }
  );
}

sub recv {
  my $self = shift;

  my $logger = $self->logger;

  $logger->trace("Waiting for message on channel:     '".$self->channel."'");
  $logger->trace("                       queue:       '".$self->queue_name."'");
  $logger->trace("                       routing_key: '".$self->routing_key."'");

  return $self->queue->recv(@_);
}

sub publish {
  my ($self, $rk, $data, $opts) = @_;

  my $logger = $self->logger;

  $logger->trace("Publishing for message:");
  $logger->trace("  channel    : '".$self->channel."'");
  $logger->trace("  routing_key: '$rk'");
  $logger->trace("  data       :\n",Dumper($data));
  $logger->trace("  opts       :\n",Dumper($opts));

  return $self->queue->publish($self->channel, $rk, $data, $opts);
}

sub create_queue {
  my $self = shift;
  my %opts = @_;

  for my $key (keys(%opts)) { $self->$key($opts{$key}) }

  $self->logger->debug(
    "Creating new queue ('".
    join("','",$self->channel,$self->queue_name,$self->exchange_name,$self->queue_name).
    "')"
  );

  my $mq = $self->queue;

  $mq->queue_declare(
    $self->channel,
    $self->queue_name
  );
  $mq->queue_bind(
    $self->channel,
    $self->queue_name,
    $self->exchange_name,
    $self->queue_name,
    {}
  );
  $self->consumer_id(
      $mq->consume(
        $self->channel,
        $self->queue_name
      )
  );

  $self->logger->debug("Started consuming ".$self->queue_name."' as consumer_id ".$self->consumer_id);

  return $mq;
}

1; 

