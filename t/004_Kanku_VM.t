use strict;
use warnings;

use Test::More tests => 2;
use FindBin;
use Path::Class qw/dir/;
use Data::Dumper;

require_ok('Kanku::Util::VM');

my $vm = Kanku::Util::VM->new(app_base_path=>dir("$FindBin::Bin/data/004"));

my ($got,$expected);

$expected = {
  'test' => [
    'foo',
    'bar'
  ],
  'domain' => {
    'vcpu' => '2',
    'name' => 'obs-appliance',
    'memory' => '2097152'
  }
};

is_deeply(
  $vm->config(),
  $expected
);

my $nvm = Kanku::Util::VM->new();
$nvm->image_file('obs-server.x86_64-2.6.51-Build15.4.qcow2');
$nvm->create_domain();

exit 0;

