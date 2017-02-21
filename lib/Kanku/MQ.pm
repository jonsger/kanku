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

has 'channel'	=> (is=>'rw',isa=>'Int',default => 1);
has 'scheduler' => (is=>'rw',isa=>'Int',default => 0);

has [qw/
  host vhost user password
  queue_name
  exchange_name
  routing_key
  consumer_id
/] => (is=>'rw',isa=>'Str');

has '+host'			  => ( default => 'localhost');
has '+vhost'		  => ( default => '/');
has '+user'			  => ( default => 'guest');
has '+password'		  => ( default => 'guest');
has '+queue_name'	  => ( default => 'scheduler');
has '+exchange_name'  => ( default => 'task_adv_exchange');
has '+routing_key'	  => ( default => 'task_adv');

has mq => (
	  is	  => 'rw', 
	  isa	  => 'Object',
	  lazy	  => 1,
	  default => 
sub {

  my $self = shift;

  my $mq = Net::AMQP::RabbitMQ->new();

  $mq->connect( $self->host,
				{ 
				  vhost		=> $self->vhost, 
				  user		=> $self->user,
				  password	=> $self->password
				}
  );

  $mq->channel_open($self->channel);

  $mq->exchange_declare($self->channel,$self->exchange_name,{exchange_type => 'fanout' });

  # don`t create worker queue for scheduler
  if ( $self->scheduler ) {
	my $queue = $mq->queue_declare($self->channel,$self->queue_name);
  } else {

	$self->queue_name(uuid());
	my $queue = $mq->queue_declare($self->channel,$self->queue_name);

	$mq->queue_bind(
	  $self->channel,
	  $self->queue_name,
	  $self->exchange_name,
	  $self->routing_key,
	  {}
	);
  }

  $self->consumer_id( $mq->consume(1, $self->queue_name) );
 
  return $mq

}
);

1; 

