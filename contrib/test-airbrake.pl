#!/usr/bin/env perl
use strict;
use warnings;
use Kanku::Config;
use Log::Log4perl;
use FindBin;
use Data::Dumper;
use Kanku::Airbrake;

BEGIN {
  Log::Log4perl->init("$FindBin::Bin/../etc/console-log.conf");
  unshift @::INC, "$FindBin::Bin/../lib";
  Kanku::Config->initialize();
  Kanku::Airbrake->initialize();
};

my $ab = Kanku::Airbrake->instance();

print Dumper($ab);

$ab->notify("Hello world!");

exit 0;
