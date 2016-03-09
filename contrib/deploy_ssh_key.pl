#!/usr/bin/env perl


use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Path::Class qw/dir/;
use Data::Dumper;


use Kanku::Handler::DeployPubKey;
use Kanku::Config;

my $cfg = Kanku::Config->new()->config;
my $opts = $cfg->{Jobs}->{'obs-server'}->{work}->[3]->{options};

my $obj = Kanku::Handler::DeployPubKey->new(%{$opts});

$obj->prepare();

$obj->execute();

$obj->finalize();

exit 0;

