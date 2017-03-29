#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use Log::Log4perl;
use lib "$FindBin::Bin/../lib";
use Kanku::Setup::LibVirt::Network;
Log::Log4perl->init("$FindBin::Bin/../etc/kanku-network-setup-logging.conf");

my $logger = Log::Log4perl->get_logger();

my $current_network_name = $ARGV[0];
my $action               = $ARGV[1];
my $setup		 = Kanku::Setup::LibVirt::Network->new();
my $net_name             = $setup->cfg->{'Kanku::LibVirt::Network::OpenVSwitch'}->{name};

$logger->debug("ARGS: @ARGV\n");


if ( $current_network_name ne $net_name ) {
	$logger->info("Current network name ($current_network_name) did not match our network name ($net_name)");
	exit 0;
}

if ( $action eq "start" ) {
	$setup->prepare_ovs();
}

if ( $action eq "started" ) {
	$setup->prepare_dns();
	$setup->start_dhcp();
	$setup->configure_iptables();
}

if ( $action eq "stopped" ) {
	$setup->kill_dhcp();
	$setup->cleanup_iptables;
	$setup->bridge_down;
	# ...
}


exit 0;
