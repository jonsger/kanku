#!/usr/bin/env perl


use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Path::Class qw/dir/;
use Data::Dumper;


use Kanku::Trigger::DoD;
use Kanku::Util::VM;

my $dod = Kanku::Trigger::DoD->new(project=>'home:M0ses:branches:OBS:Server:Unstable');

$dod->get_image_file_from_url();

my $file = $dod->download();

my $vm = Kanku::Util::VM->new();
$vm->image_file($file);
$vm->create_domain();

$vm->connect_expect();

exit 0;

