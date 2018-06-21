#!/usr/bin/env perl

use strict;
use warnings;
use Log::Log4perl;

BEGIN {
  unshift @::INC, ($ENV{KANKU_LIB_DIR} || '/usr/lib/kanku/lib');
}

use Kanku::Setup::LibVirt::Network;

my $conf_dir = $::ENV{KANKU_ETC_DIR} || '/etc/kanku';

Log::Log4perl->init("$conf_dir/logging/network-setup.conf");

my $logger = Log::Log4perl->get_logger();

my $current_network_name = $ARGV[0];
my $action               = $ARGV[1];
my $setup                = Kanku::Setup::LibVirt::Network->new();
my $net_name             = $setup->cfg->{'Kanku::LibVirt::Network::OpenVSwitch'}->{name};

$logger->debug("ARGS: @ARGV\n");


if ( $current_network_name ne $net_name ) {
  $logger->info("Current network name ($current_network_name) did not match our network name ($net_name)");
  exit 0;
}

if ( $action eq 'start' ) {
  $setup->prepare_ovs();
}

if ( $action eq 'started' ) {
  $setup->prepare_dns();
  $setup->start_dhcp();
  $setup->configure_iptables();
}

if ( $action eq 'stopped' ) {
  $setup->kill_dhcp();
  $setup->cleanup_iptables;
  $setup->bridge_down;
}


exit 0;
