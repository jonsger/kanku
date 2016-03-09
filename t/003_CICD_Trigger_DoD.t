use strict;
use warnings;

use Test::More tests => 1;                      # last test to print

require_ok('Kanku::Trigger::DoD');

my $dod = Kanku::Trigger::DoD->new();

$dod->get_image_file_from_url();

my $file = $dod->download() . "\n";

exit 0;
