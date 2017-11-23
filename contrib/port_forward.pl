#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Log::Log4perl;

use Kanku::Job;
use Kanku::Util::IPTables;
use Kanku::Util::VM;
use YAML::XS qw/LoadFile/;

Log::Log4perl->init("$FindBin::Bin/../etc/console-log.conf");

our $VERSION = "0.0.1";

if ( @ARGV < 3 ) {
  my @file = split(/\//,$0);
  my $basename = pop(@file);
  print "Usage: $basename <domain_name> <host_interface> <rule_1> [rule_n]
Example: 

# $basename obs-server eth0 tcp:443 tcp:22

";
  exit 0;
}

my $cfg = LoadFile("$FindBin::Bin/../etc/config.yml");
my $domain_name     = shift(@ARGV);
my $host_interface  = shift(@ARGV);

my $vm = Kanku::Util::VM->new(domain_name => $domain_name);

my $ip = $vm->get_ipaddress;

my $ipt = Kanku::Util::IPTables->new(
    domain_name     => $domain_name,
    host_interface  => $host_interface,
    guest_ipaddress => $ip
);

$ipt->add_forward_rules_for_domain(
    start_port => $cfg->{'Kanku::Util::IPTables'}->{start_port},
    forward_rules => \@ARGV
);

exit 0;
