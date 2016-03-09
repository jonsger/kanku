#!/usr/bin/env perl


use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Data::Dumper;
use Kanku::Job;
use Kanku::Util::VM;
use Kanku::Handler::PrepareSSH;
use Kanku::Handler::ExecuteCommandViaSSH;
use Log::Log4perl;

Log::Log4perl->init("$FindBin::Bin/../etc/console-log.conf");

my $job = Kanku::Job->new();

my $vm = Kanku::Util::VM->new(
  domain_name=>'obs-server',
  config => {
    login_user => 'root',
    login_pass => 'opensuse'
  }
);

my $ip = $vm->get_ipaddress("eth0");

$vm->console->logout();

print "ADDRESS: $ip\n";
$job->context()->{ipaddress} = $ip;
my $tasks = [
Kanku::Handler::ExecuteCommandViaSSH->new( 
    ipaddress => $ip,
    commands => [ "git clone https://github.com/M0ses/nm-plugin-splitdns.git /tmp/nm-plugin-sad","ls -la /tmp"],
    job => $job,
    logger => Log::Log4perl->get_logger
),
];

foreach my $task (@$tasks) {
    print Dumper(
      $task->prepare(),
      $task->execute(),
      $task->finalize()
    );

}

exit 0;

