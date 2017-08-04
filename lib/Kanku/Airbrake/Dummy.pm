package Kanku::Airbrake::Dummy;

use Moose;
use Data::Dumper;
sub add_error { return; }
sub has_error { return; }
sub send      { return; }
sub notify    { print Dumper(@_);return; }

1;
