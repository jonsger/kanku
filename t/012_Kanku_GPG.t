#!/usr/bin/perl

use Test::More tests => 1;

use_ok('Kanku::GPG');

my $gpg = Kanku::GPG->new(
  message    => "Hallo Frank",
  recipients => ['frank@samaxi.de', 'mls@suse.de'],
);

print $gpg->encrypt;

exit 0;
