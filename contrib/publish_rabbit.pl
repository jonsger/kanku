#!/usr/bin/env perl

use strict;
use warnings;

use Net::AMQP::RabbitMQ;
use JSON::XS;
use Data::Dumper;
use FindBin;
use YAML;

my $host = $ARGV[0];
my $user = $ARGV[1];
my $password = $ARGV[2];

my $channel = 1;

my $messages= { 
  1 => {
    exchange       => "pubsub", # This exchange must exist already
    routing_prefix => "opensuse",
    routing_key    => 'obs.package.build_success',
    msg            =>  encode_json(
      {
        project    => 'OBS:Server:Unstable',
        package    => 'obs-server',
        repository => 'SLE_12_SP3',
        arch       => 'x86_64'
      }
    ),
  },
  2 => {
    exchange       => "pubsub", # This exchange must exist already
    routing_prefix => "suse",
    routing_key    => 'obs.repo.published',
    msg            =>  encode_json(
      {
        project    => 'OBS:Server:Unstable',
        repo => 'SLE_12_SP3',
      }
    ),
  }
};

my $mq = Net::AMQP::RabbitMQ->new();
print "Connecting to host $host with username $user and password $password\n";
$mq->connect($host, { user => $user, password => $password });
$mq->channel_open($channel);

print "Please enter a number to send an event:\n";
print Dumper($messages);

while (1) {
  my $in = <STDIN>;
  chomp($in);
  if ( $messages->{$in} ) {
    my $data = $messages->{$in};
    my $rkey = $data->{routing_prefix}.'.'.$data->{routing_key};
    print "Publishing message($rkey): $data->{msg}\n";
    $mq->publish($channel, $rkey, $data->{msg}, { exchange => $data->{exchange} });
  }
}
$mq->disconnect();
exit 0;
