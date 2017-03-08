use strict;
use warnings;

use Test::More tests => 6;
use Test::Exception;

# avoid 'only used once'
my $xy = $FindBin::Bin;
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

for my $opt (qw/stop foreground/){
  local @ARGV=("--$opt");
  is_deeply(
    Kanku::MyDaemon->new()->daemon_options(),
    {$opt => 1},
    "Checking '--$opt' option"
  );
}

my $aliases =  {
  '-f' => 'foreground'
};

for my $alias (keys(%{$aliases})) {
  local @ARGV=($alias);
  my $opt = $aliases->{$alias};
  is_deeply(
    Kanku::MyDaemon->new()->daemon_options(),
    {$opt => 1},
    "Checking alias '$alias' for option '--$opt'"
  );
}

{
  Kanku::MyDaemon->new()->initialize_shutdown();
  my $shf = "$FindBin::Bin/../var/run/009_Kanku_Roles_Daemon.t.shutdown";
  ok(
    ( -f $shf ),
    "Checking shutdown file"
  );
  unlink $shf;
}
exit 0;

