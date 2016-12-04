#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
use Kanku::Test::MockConsole;
use Kanku::Test::MockLogger;
use Data::Dumper;
use_ok("Kanku::Handler::SetupNetwork");

my $logger = Kanku::Test::MockLogger->new();
my $h = Kanku::Handler::SetupNetwork->new(
  interfaces =>{},
  logger => $logger
);

ok(! (defined($h->_configure_resolver)),"Checking return if resolv not defined");

$h->resolv({});
my $con = Kanku::Test::MockConsole->new();
is($h->_configure_resolver($con),1,"Checking return if resolv is defined but empty");
is($Kanku::Test::MockConsole::CmdBuffer[0],'echo -en "" > /etc/resolv.conf',"Checking command if resolv is defined but empty");
