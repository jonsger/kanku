#!/usr/bin/env perl

=head1 NAME 

port_forward.pl - FIXME: comment your tool

=head1 SYNOPSIS

|port_forward.pl <required-options> [optional options]

=head1 DESCRIPTION

FIXME: add a useful description

=head1 AUTHORS

Frank Schreiner (M0ses), m0ses@samaxi.de

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Log::Log4perl;

use Kanku::Job;
use Kanku::Handler::PortForward;

Log::Log4perl->init("$FindBin::Bin/../etc/console-log.conf");

our $VERSION = "0.0.1";

if ( @ARGV < 3 ) {
  my @file = split(/\//,$0);
  my $basename = pop(@file);
  print "Usage: $basename <GUEST_IP> <domain_name> <rule_1> [rule_n]
Example: 

# $basename 192.168.100.208 obs-server-26 tcp:5444:443 tcp:5023:22

";

  exit 0;
}

my $job = Kanku::Job->new();

$job->context->{ipaddress} = shift(@ARGV);
$job->context->{domain_name} = shift(@ARGV);

my $handler = Kanku::Handler::PortForward->new(
  job => $job,
  logger => Log::Log4perl->get_logger(),
  host_interface => 'eth0',
  forward_ports => \@ARGV
);

$handler->prepare();
$handler->execute();

exit 0;


