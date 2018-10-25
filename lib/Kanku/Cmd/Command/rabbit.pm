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
package Kanku::Cmd::Command::rabbit;

use Moose;
use Kanku::Config;
use Data::Dumper;
use YAML qw/LoadFile/;
use FindBin;
use Log::Log4perl;

extends qw(MooseX::App::Cmd::Command);

use Kanku::Test::RabbitMQ;

has listen => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'l',
    documentation => 'execute listener test',
);

has send => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 's',
    documentation => 'send message to server',
);

has props => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'p',
    documentation => 'get properties from server',
);

has config => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'c',
    documentation => 'configuration file',
);

has notification => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'n',
    documentation => 'notification id',
    default       => '',
);

has output_plugin => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'o',
    documentation => 'notification id',
    default       => 'plain',
);

has cfg => (
    isa           => 'HashRef',
    is            => 'rw',
    lazy		  => 1,
    default		  => sub {
      my ($self) = @_;
      my $cf = $self->config;
      $cf = "$FindBin::Bin/../etc/rabbit.yml" if (! $cf && -f "$FindBin::Bin/../etc/rabbit.yml");
      $cf = "/etc/kanku/rabbit.yml" if (! $cf && -f "/etc/kanku/rabbit.yml");
      die "Could not find any config file!\n" unless $cf;
      return LoadFile($cf);
    },
);

sub abstract { return 'test rabbitmq'; }

sub description { return 'This command is for testing rabbitmq connctions'; }

sub execute {
  my ($self)  = (@_);
  my $srv     = $self->send || $self->listen || $self->props || '';
  die "No config found for $srv! Use one of <".join('|', keys %{$self->cfg->{servers}}).">.\n" unless $srv;

  my $mq = Kanku::Test::RabbitMQ->new(
    config        => $self->cfg->{servers}->{$srv},
    logger        => Log::Log4perl->get_logger,
    notifications => $self->cfg->{notifications},
    notification  => $self->notification,
    output_plugin => $self->output_plugin,
  );

  $mq->connect;
  my $rc;
  if ($self->listen) {
    $rc = $mq->listen;
  } elsif ($self->send) {
    $rc = $mq->send;
  } elsif ($self->props) {
    $rc = $mq->props;
  }

  $mq->disconnect;
  exit $rc;
}

__PACKAGE__->meta->make_immutable;

1;
