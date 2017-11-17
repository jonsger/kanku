#!/usr/bin/env perl

use strict;
use Test::More tests => 7;
use FindBin;
use DBIx::Class::Migration;
use Kanku::Schema;
use Data::Dumper;

my $db = "$FindBin::Bin/tmp.db";
my $dsn = "dbi:SQLite:$db";
unlink $db;
my $schema = Kanku::Schema->connect($dsn);
my $migration = DBIx::Class::Migration->new(
  schema => $schema);

$migration->install;
$migration->populate('install');

use_ok('Kanku::WebSocket::Session');

my $ws_session = Kanku::WebSocket::Session->new(
  schema  => $schema,
  user_id => '1'
);

my $session_token = $ws_session->session_token;
print "$session_token\n";

my $auth_token = $ws_session->auth_token;

my $user_table = $schema->resultset('User')->count();

ok($user_table == 1, "Checking user table");

my $st = $schema->resultset('WsSession')->find({session_token=>$session_token});
my $at = $schema->resultset('WsToken')->find({auth_token=>$auth_token});
ok(!$st,"Checking session_token in database");
ok($at,"Checking auth_token in database");

$ws_session->authenticate;


$st = $schema->resultset('WsSession')->find({session_token=>$session_token});
$at = $schema->resultset('WsToken')->find({auth_token=>$auth_token});
ok($st,"Checking session_token in database");
ok(!$at,"Checking auth_token in database");
ok($st->permissions > 0, "Checking permissions");

exit 0;
