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
package Kanku::Cmd::Command::destroy;

use Moose;
use Kanku::Config;
use Kanku::Util::VM;
use Kanku::Util::IPTables;
use Log::Log4perl;

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

sub abstract { "Remove domain completely" }

sub description { "meaningfull description" }



sub execute {
  my $self    = shift;
  my $vm      = Kanku::Util::VM->new(domain_name => $self->domain_name);
  my $logger  = Log::Log4perl->get_logger;
  my $dom;

  eval {
    $dom = $vm->dom;
  };

  if ( $@ or ! $dom ) {
    $logger->fatal("Error: ".$self->domain_name." not found\n");
    exit 1;
  }

  eval {
    $vm->remove_domain();
  };

  if ( $@ ) {
    $logger->fatal("Error while removing domain: ".$self->domain_name.":\n");
    $logger->fatal($@);
    exit 1;
  }

  my $ipt = Kanku::Util::IPTables->new(domain_name=>$self->domain_name);
  $ipt->cleanup_rules_for_domain();

  $logger->info("Removed domain ".$self->domain_name." successfully");
}

__PACKAGE__->meta->make_immutable;

1;
