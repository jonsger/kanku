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
use Data::Dumper;
use Net::IP;

with 'Kanku::Roles::SSH';

extends qw(MooseX::App::Cmd::Command);

has user => (
  traits        => [qw(Getopt)],
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'u',
  documentation => 'Login user to use for ssh (default: kanku)',
  default => 'kanku'
);

has login_user => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'l',
    documentation => 'user to login',
        lazy              => 1,
        default           => sub {
          return Kanku::Config->instance()->config()->{login_user} || '';
        }
);

has login_pass => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'p',
    documentation => 'password to login',
        lazy              => 1,
        default           => sub {
          return Kanku::Config->instance()->config()->{login_pass} || '';
        }
);

sub abstract { "open ssh connection to vm" }

sub description { "open ssh connection to vm" }


sub execute {
  my $self  = shift;
  my $cfg   = Kanku::Config->instance();
  my $vm    = Kanku::Util::VM->new(
                domain_name         => $cfg->config->{domain_name},
		login_user  => $self->login_user,
                login_pass  => $self->login_pass,
                management_network  => $cfg->config->{management_network} || ''
              );
  my $state = $vm->state;

  if ( $state eq 'on' ) {
    my $ip    = $vm->get_ipaddress;
    my $user  = $self->user;

    $self->ipaddress($ip);
    $self->username($user);
    $self->job(Kanku::Job->new());
    $self->connect();

    system("ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l $user $ip");
    exit 0;
  } elsif ($state eq 'off') {
    $self->logger->warn("VM is off - use 'kanku startvm' to start VM and try again");
    exit 1;
  } else {
    $self->logger->fatal("No VM found or VM in state 'unknown'");
    exit 2;
  }

}

__PACKAGE__->meta->make_immutable;

1;
