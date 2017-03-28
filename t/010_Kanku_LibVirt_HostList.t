#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use Data::Dumper;
use Test::More tests => 3;

use_ok('Kanku::LibVirt::HostList');

my $hl = Kanku::LibVirt::HostList->new(
           cfg_file => "$FindBin::Bin/fixtures/libvirt/etc/01-config.yml"
         );
my ($got,$expected);

$expected = ['10.0.0.1'];
$got      = $hl->get_remote_ips;
is_deeply($got,$expected,"Checking get_remote_ips with simple hostlist");

$expected = [
  'qemu:///system',
  'qemu+ssh://root@10.0.0.1/system?keyfile=%2Fopt%2Fkanku%2Fetc%2Fssh%2Fid_dsa&known_hosts=%2Fopt%2Fkanku%2Fetc%2Fssh%2Fknown_hosts&no_tty=1&no_verify=1&sshauth=privkey'
];

$got      = $hl->get_remote_urls;

is_deeply($got,$expected,"Checking get_remote_urls with simple hostlist");
exit 0;
