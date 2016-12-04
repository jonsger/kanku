package Kanku::Test::MockConsole;

use strict;
use warnings;

sub new   { return bless({_debug=>[]},$_[0]); }

sub cmd    { shift;push(@Kanku::Test::MockConsole::CmdBuffer,@_); }

sub login  { return }

sub logout { return }

1;
