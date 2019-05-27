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
package Kanku::Cmd::Command::stopvm;     ## no critic (NamingConventions::Capitalization)

use Moose;
use Kanku::Config;
use Try::Tiny;
use Log::Log4perl;
use XML::XPath;

extends qw(MooseX::App::Cmd::Command);

has domain_name => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'd',
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

has force => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    cmd_aliases   => 'f',
    documentation => 'destroy domain instead of shutdown',
);

sub abstract { return 'Stop kanku VM'; }    ## no critic (NamingConventions::ProhibitAmbiguousNames)

sub description { return 'This command can be used to stop/shutdown a running VM'; }

sub execute {
  my $self    = shift;
  Kanku::Config->initialize(class => 'KankuFile');
  my $logger  = Log::Log4perl->get_logger;
  my $dn      = $self->domain_name;

  my $vm = Kanku::Util::VM->new(domain_name => $dn);
  $logger->debug("Searching for domain: $dn");
  if ($vm->dom) {
    $logger->info("Stopping domain: $dn");
    if ($self->force) {
      $vm->dom->destroy();
    } else {
      $vm->dom->shutdown();
    }
    while ($vm->state eq 'on') {
      sleep 1;
    }
    $logger->info("Stopped domain: $dn successfully");
  } else {
    $logger->fatal("Domain $dn doesn't exists");
    exit 1;
  }
  return;
}

__PACKAGE__->meta->make_immutable;

1;
