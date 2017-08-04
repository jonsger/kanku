#!/usr/bin/env perl

use strict;
use warnings;
use Kanku::Config;
use Log::Log4perl;
use FindBin;
use Data::Dumper;

BEGIN {
  Log::Log4perl->init("$FindBin::Bin/../etc/console-log.conf");
  unshift @::INC, "$FindBin::Bin/../lib";
  Kanku::Config->initialize();
};

use Kanku::Airbrake;

my $ab = Kanku::Airbrake->new();

print Dumper($ab);

$ab->notify("Hello world!");

exit 0;
