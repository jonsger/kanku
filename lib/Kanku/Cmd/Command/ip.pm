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
package Kanku::Cmd::Command::ip;

use Moose;
use Kanku::Config;
use Kanku::Job;
use Kanku::Util::VM;

extends qw(MooseX::App::Cmd::Command);

has domain_name => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'd',
    documentation => 'name of domain',
    lazy		  => 1,
    default		  => sub {
      return Kanku::Config->instance()->config()->{domain_name} || q{};
    },
);

has login_user => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'u',
    documentation => 'user to login',
    lazy		  => 1,
    default		  => sub {
          return Kanku::Config->instance()->config()->{login_user} || q{};
    },
);

has login_pass => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'p',
    documentation => 'password to login',
    lazy		  => 1,
    default		  => sub {
      return Kanku::Config->instance()->config()->{login_pass} || q{};
    },
);


sub abstract { 'Show ip address of kanku vm' }

sub description { 'Show ip address of kanku vm' }

sub execute {
  my $self    = shift;
  my $logger  = Log::Log4perl->get_logger;
  Kanku::Config->initialize(class => 'KankuFile');
  my $cfg     = Kanku::Config->instance();


  my $vm = Kanku::Util::VM->new(
    domain_name =>$self->domain_name,
    login_user  => $self->login_user,
    login_pass  => $self->login_pass,
  );

  my $ip = $vm->get_ipaddress();

  if ( $ip ) {

    $logger->info("IP Address: $ip");

  } else {
    $logger->error('Could not find IP Address');
  }

  return;
}

__PACKAGE__->meta->make_immutable;

1;
