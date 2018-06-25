# Copyright (c) 2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
package Kanku::Cmd::Command::startvm;    ## no critic (NamingConventions::Capitalization)

use Moose;
use Kanku::Config;
use Try::Tiny;
use Log::Log4perl;
use XML::XPath;
use Data::Dumper;

extends qw(MooseX::App::Cmd::Command);

has domain_name => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'X',
    documentation => 'name of domain to create',
    lazy          => 1,
    default       => sub { $_[0]->cfg->config->{domain_name} },
);

has cfg => (
    isa           => 'Object',
    is            => 'rw',
    lazy          => 1,
    default       => sub { Kanku::Config->instance(); },
);

sub abstract { return 'Start kanku VM'; }    ## no critic (NamingConventions::ProhibitAmbiguousNames)

sub description { return 'This command can be used to start an already existing VM'; }

sub execute {
  my $self    = shift;
  Kanku::Config->initialize(class => 'KankuFile');
  my $logger  = Log::Log4perl->get_logger;
  my $dn      = $self->domain_name;
  my $vm      = Kanku::Util::VM->new(domain_name => $dn);

  $logger->debug("Searching for domain: $dn");

  if ($vm->dom) {
    $logger->info("Starting domain: $dn");
    $vm->dom->create();
  } else {
    $logger->fatal("Domain $dn already exists");
    exit 1;
  }

  return;
}

__PACKAGE__->meta->make_immutable;

1;
