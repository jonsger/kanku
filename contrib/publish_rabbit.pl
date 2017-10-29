#!/usr/bin/env perl

use strict;
use warnings;

use Net::AMQP::RabbitMQ;
use JSON::XS;
use Data::Dumper;

my $host = $ARGV[0];
my $user = $ARGV[1];
my $password = $ARGV[2];

my $channel = 1;
my $exchange = "pubsub";  # This exchange must exist already
my $routing_key = "opensuse.obs.package.build_success";

my $messages= { 
  1 => {
    rkey => 'opensuse.obs.package.build_success',
    msg  =>  encode_json(
	{
	  project    => 'OBS:Server:Unstable',
	  package    => 'obs-server',
	  repository => 'SLE_12_SP3',
	  arch       => 'x86_64'
	}
    ),
  },
  2 => {
    rkey => 'opensuse.obs.repo.published',
    msg  =>  encode_json(
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
    print "Publishing message($data->{rkey}): $data->{msg}\n";
    $mq->publish($channel, $data->{rkey}, $data->{msg}, { exchange => $exchange });
  }
}
$mq->disconnect();
