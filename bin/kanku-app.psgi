#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use Plack::Builder;
use lib "$FindBin::Bin/../lib";

use Kanku;

builder {
  mount(Kanku->websocket_mount);
  mount '/kanku' => Kanku->to_app;
};
