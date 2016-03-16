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
package Kanku::Cmd::Command::ssh;

use Moose;
use Kanku::Config;
use Kanku::Util::VM;
use Sys::Virt;
use Data::Dumper;
use Net::IP;
extends qw(MooseX::App::Cmd::Command);

has user => (
  traits        => [qw(Getopt)],
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'u',
  documentation => 'Login user to use for ssh (default: kanku)',
  default => 'kanku'
);

sub abstract { "open ssh connection to vm" }

sub description { "open ssh connection to vm" }


sub execute {
  my $self  = shift;
  my $cfg   = Kanku::Config->instance();
  my $vm    = Kanku::Util::VM->new(
                domain_name         => $cfg->config->{domain_name},
                management_network  => $cfg->config->{management_network} || ''
              );
  my $ip    = $vm->get_ipaddress;
  my $user  = $self->user;

  system("ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l $user $ip");

}

__PACKAGE__->meta->make_immutable;

1;
