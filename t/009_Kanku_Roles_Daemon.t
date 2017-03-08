use strict;
use warnings;

use Test::More tests => 3;
use Test::Exception;
require_ok('Kanku::MyDaemon');

{
  local @ARGV=("--non-existant-option");
  my $out;
  local *STDERR;
  open STDERR, '>', \$out or die "Can't open STDOUT: $!";

  throws_ok(
    sub  { Kanku::MyDaemon->new()->daemon_options() },
    qr/Usage:/,
    'Checking die if option unknown'
  );
}

for my $opt (qw/stop/){
  local @ARGV=("--$opt");
  is_deeply(
    Kanku::MyDaemon->new()->daemon_options(),
    {stop => 1},
    "Checking '--$opt' option"
  );
}

exit 0;

