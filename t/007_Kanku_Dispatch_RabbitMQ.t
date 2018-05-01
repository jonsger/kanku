use strict;
use warnings;

use Test::More tests => 4;                      # last test to print
use Log::Log4perl;
use FindBin;
Log::Log4perl->init("$FindBin::Bin/etc/log_to_dev_null.conf");

require_ok('Kanku::Dispatch::RabbitMQ');

my $mq    = Kanku::Dispatch::RabbitMQ->new();

my $tc = {
  'Kanku::Handler::SetJobContext' => 0,
  'Kanku::Handler::CreateDomain'  => 1,
  'Kanku::Handler::RemoveDomain'  => 2,
};

for my $mod (keys(%$tc)) {
  is(
    $mq->check_task($mod),
    $tc->{$mod},
    "Checking distributable attribute of $mod"
  );
}

exit 0;
