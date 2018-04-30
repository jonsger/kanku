#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use Plack::Builder;
use lib "$FindBin::Bin/../lib";
use Log::Log4perl;

use Kanku;
use Kanku::REST;

Log::Log4perl->init("$FindBin::Bin/../etc/log4perl.conf");

builder {
  mount '/kanku/rest' => Kanku::REST->to_app;
  mount(Kanku->websocket_mount);
  mount '/kanku' => Kanku->to_app;
};
