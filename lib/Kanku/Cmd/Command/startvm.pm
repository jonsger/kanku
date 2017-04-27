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
package Kanku::Cmd::Command::startvm;

use Moose;
use Kanku::Config;
use Try::Tiny;
use Log::Log4perl;
use XML::XPath;
use Data::Dumper;

#use Kanku::Util::VM;
#use Kanku::Util::IPTables;

extends qw(MooseX::App::Cmd::Command);

has domain_name => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'X',
    documentation => 'name of domain to create',
    lazy          => 1,
    default       => sub { $_[0]->cfg->config->{domain_name} }
);

has cfg => (
    isa           => 'Object',
    is            => 'rw',
    lazy          => 1,
    default       => sub { Kanku::Config->instance(); }
);

sub abstract { "Start kanku VM" }

sub description { "This command can be used to start an already existing VM" }

sub execute {
  my $self    = shift;
  my $logger  = Log::Log4perl->get_logger;

  my $vm = Kanku::Util::VM->new(domain_name=>$self->domain_name);
  $logger->debug("Searching for domain: ".$self->domain_name);
  if ($vm->dom) {
    $logger->info("Starting domain: ".$self->domain_name);
    $vm->dom->create();
  } else {
    $logger->fatal("Domain ".$self->domain_name." already exists");
    exit 1;
  }

}

__PACKAGE__->meta->make_immutable;

1;
