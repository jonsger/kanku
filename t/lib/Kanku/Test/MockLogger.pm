package Kanku::Test::MockLogger;

use strict;
use warnings;

sub new   { return bless({_debug=>[]},$_[0]); }
sub debug { push(@{$_[0]->{_debug}},@_); }

1;
