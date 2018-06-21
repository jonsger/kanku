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
package Kanku::Cmd::Command::console;

use Moose;
use Kanku::Config;

extends qw(MooseX::App::Cmd::Command);

has domain_name => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'd',
    documentation => 'name of domain to open console',
    lazy		  => 1,
    default		  => sub {
      return Kanku::Config->instance()->config()->{domain_name};
    },
);

sub abstract { return 'Open a serial console to vm'; }

sub description { return 'Open a serial console to vm' }

sub execute {
  my $self    = shift;
  Kanku::Config->initialize(class => 'KankuFile');
  my $logger  = Log::Log4perl->get_logger;
  my $cfg     = Kanku::Config->instance();


  my $cmd = 'virsh -c qemu:///system console '.$self->domain_name;

  exec($cmd);
}

__PACKAGE__->meta->make_immutable;
1;
