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
=head1 NAME

Kanku::RabbitMQ - A helper class for Net::AMQP::RabbitMQ

=head1 SYNOPSIS

    my $kmq = Kanku::RabbitMQ->new(%{ $config || {}});
    $kmq->shutdown_file($self->shutdown_file);
    $kmq->connect() or die "Could not connect to rabbitmq\n";
    $kmq->setup_worker();
    $kmq->create_queue(
      queue_name    => $self->worker_id,
      exchange_name =>'kanku.to_all_workers'
    );

=cut

use Moose;

use Net::AMQP::RabbitMQ;
use JSON::XS;
use UUID ':all';
use Try::Tiny;

with 'Kanku::Roles::Logger';
with 'Kanku::Roles::Helpers';

=head1 ATTRIBUTES

=over

=item channel

=item port

=item ssl

=back

=cut

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
has '+ssl_cacert'    => ( default => '');

has queue => (
	  is	  => 'rw',
	  isa	  => 'Object',
);

has shutdown_file => (
	  is	  => 'rw',
	  isa	  => 'Object',
);

=head1 METHODS

=head2 connect - connect to a rabbitmq server

 $kmq->connect(no_retry=>1);

=cut

sub connect {
  my ($self, %opts) = @_;
  my $logger = $self->logger;

  $logger->debug(__PACKAGE__."->connect to opts:".$self->dump_it(\%opts));
  $self->queue(Net::AMQP::RabbitMQ->new());

  my @connect_opts = (
    $self->host,
    {
      vhost           => $self->vhost,
      user            => $self->user,
      password	      => $self->password,
      port            => $self->port,
      ssl             => $self->ssl,
      ssl_cacert      => $self->ssl_cacert || '/etc/ssl/ca-bundle.pem',
      ssl_verify_host => $self->ssl_verify_host,
      ssl_init        => $self->ssl_init,
    }
  );

  $logger->debug("Trying to connect to rabbitmq with the folloing options: ".$self->dump_it(\@connect_opts));

  my $connect_success = 0;
  while (! $connect_success ) {
    try {
      $self->queue->connect(@connect_opts);
      $connect_success = 1;
    } catch {
      if ( $self->shutdown_file ) {
        my $msg = "Found shutdown file '"
          . $self->shutdown_file
          . "' while trying to connect to rabbitmq\n";
        die $msg if ( -f $self->shutdown_file);
      }
      $logger->trace("Error while connecting to RabbitMQ: '$_'");
      die "Could not connect to RabbitMQ: $_" if $opts{no_retry};
      sleep 1;
    };

  }

  $logger->info("Connection rabbitmq on ".$self->host." established successfully");

  $self->queue->channel_open($self->channel);

  return 1;
}

=head2 connect_info - return a hash ref containing config for connect

=cut

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
=head2 setup_worker -

=cut

sub setup_worker {
  my ($self, $mq) = @_;

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
=head2 recv - wait and read new incomming messages

=cut

sub recv {
  my ($self, @opts) = shift;
  my $logger = $self->logger;

  $logger->trace("Waiting for message on channel:     '".$self->channel."'");
  $logger->trace("                       queue:       '".$self->queue_name."'");
  $logger->trace("                       routing_key: '".$self->routing_key."'");

  my $msg = $self->queue->recv(@opts);
  if ($msg) {
    $logger->trace("Recieved data:".$self->dump_it($msg));
  }
  return $msg;
}

=head2 publish - send a message

   $kmq->publish($routing_key, $data, $opts);

=cut

sub publish {
  my ($self, $rk, $data, $opts) = @_;

  my $logger = $self->logger;

  $logger->trace("Publishing for message:");
  $logger->trace("  channel    : '".$self->channel."'");
  $logger->trace("  routing_key: '$rk'");
  $logger->trace("  data       : ".$self->dump_it($data));
  $logger->trace("  opts       : ".$self->dump_it($opts));

  return $self->queue->publish($self->channel, $rk, $data, $opts);
}

=head2 create_queue -

=cut
sub create_queue {
  my ($self, %opts) = @_;

  while ( my ($key, $value) = each(%opts)) { $self->$key($opts{$key}) if defined($value) }

  $self->logger->debug(
    "Creating new queue ('".
    join("','",$self->channel,($self->queue_name ||''),$self->exchange_name,($self->queue_name||'')).
    "')"
  );

  my $mq = $self->queue;

  my $qn = $mq->queue_declare(
    $self->channel,
    ($self->queue_name || '')
  );

  $self->queue_name($qn);

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

  return $qn;
}

=head2 destroy_queue - unbind and delete queue (if_unused=>0,if_empty=>0)

   $kmq->destroy_queue;

=cut

sub destroy_queue {
  my ($self) = @_;
  my $mq = $self->queue;
  my %opts = @_;

  while ( my ($key, $value) = each(%opts)) { $self->$key($opts{$key}) if defined($value) }

  $self->logger->debug(
    "Destroying queue ('".
    join("','",$self->channel,($self->queue_name ||''),$self->exchange_name,($self->queue_name||'')).
    "')"
  );

  $mq->queue_unbind(
    $self->channel,
    $self->queue_name,
    $self->exchange_name,
    $self->queue_name,
    {}
  );

  $mq->queue_delete(
    $self->channel,
    $self->queue_name,
    {if_empty => 0, if_unused => 0}
  );
}

=head2 destroy_queue - unbind and delete queue (if_unused=>0,if_empty=>0)

   $kmq->destroy_queue;

=cut

sub reconnect {
  my ($self) = @_;
  my $mq = $self->queue;

  try {
    $mq->disconnect;
  };

  $self->connect;

  try {
    $self->create_queue;
  } catch {
    $self->logger->warn($_);
    if($_ =~ / NOT_FOUND - no exchange /) {
      $self->logger->debug("Trying to setup worker after reconnect");
      # the connection gets automatically disconnect if exchange does not
      # exists, thats why we force connect here
      $self->connect;
      $self->setup_worker;
      $self->create_queue;
    } else {
      die $_;
    }
  };
}
1;
