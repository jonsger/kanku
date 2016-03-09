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
use Data::Dumper;
use lib "$FindBin::Bin/../lib";
use Log::Log4perl;

use Kanku::Util::IPTables;

Log::Log4perl->init("$FindBin::Bin/../etc/console-log.conf");

our $VERSION = "0.0.1";

if ( @ARGV != 1 ) {
  my @file = split(/\//,$0);
  my $basename = pop(@file);
  print "Usage: $basename <domain_name>\n";

  exit 0;
}


my $ipt = Kanku::Util::IPTables->new(
    domain_name     => $ARGV[0],
);

print Dumper($ipt->get_forwarded_ports_for_domain());

exit 0;


