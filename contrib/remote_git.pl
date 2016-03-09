#!/usr/bin/env perl


use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Path::Class qw/dir/;
use Data::Dumper;


use Kanku::Handler::GIT;
use Kanku::Config;
use Kanku::Job;

Log::Log4perl->init("$FindBin::Bin/../etc/console-log.conf");


my $cfg       = Kanku::Config->new()->config;
my $opts      = $cfg->{Jobs}->{'obs-server'}->{work}->[5]->{options};
$opts->{job}  = Kanku::Job->new();
$opts->{job}->context->{ipaddress} = $ARGV[0];
$opts->{logger} = Log::Log4perl->get_logger;
my $obj       = Kanku::Handler::GIT->new(%{$opts});

$obj->prepare();

$obj->execute();

$obj->finalize();

exit 0;

