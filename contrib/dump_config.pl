#!/usr/bin/env perl


use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Data::Dumper;

use Log::Log4perl;
use Kanku::Config;

Log::Log4perl->init("$FindBin::Bin/../etc/console-log.conf");

Kanku::Config->initialize();

my $cfg       = Kanku::Config->instance;

my @jl = $cfg->job_list;

foreach my $j (@jl) {
  print Dumper($cfg->job_config($j));
}

exit 0;

