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
package Kanku::Cmd::Command::list;

use Moose;
#use Kanku::Config;
#use Kanku::Scheduler;
#use Kanku::Job;
#use Kanku::Util::VM;
use Log::Log4perl;
extends qw(MooseX::App::Cmd::Command);
with "Kanku::Cmd::Roles::Schema";

has global => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    cmd_aliases   => 'g',
    documentation => 'global vm list',
);

sub abstract { "Not implemented yet" }

sub execute {
  my $self    = shift;
  my $logger  = Log::Log4perl->get_logger;
  #my $cfg     = Kanku::Config->instance();

  #my $schema  = $self->schema;


}

__PACKAGE__->meta->make_immutable;

1;
