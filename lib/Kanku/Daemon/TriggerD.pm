# Copyright (c) 2017 SUSE LLC
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
package Kanku::Daemon::TriggerD;

use Moose;
with 'Kanku::Roles::Logger';
with 'Kanku::Roles::DB';
with 'Kanku::Roles::Daemon';

#use Kanku::Config;
use Kanku::Job;
use Kanku::Dispatch::Local;
use Kanku::Task;
use JSON::XS;
use Data::Dumper;
use Try::Tiny;
use POSIX;

use Kanku::Listener::RabbitMQ;

sub run {
  my $self    = shift;
  my $logger  = $self->logger();

  $logger->info("Running Kanku::Daemon::TriggerD");

  my $config = Kanku::Config->instance()->config();
  my @childs;

  for my $listener_config (@{$config->{'Kanku::Daemon::TriggerD'}->{listener}}) {

    my $pid = fork();

    die "Could not fork: $!" unless(defined($pid));

    if ($pid) {
      push(@childs, $pid);
    } else {

      my $class = $listener_config->{class};
      my $listener_object = $class->new(config => $listener_config, daemon => $self );

      my ($mq, $qname) = $listener_object->connect_listener($listener_config);

      $listener_object->wait_for_events($mq, $qname);

      exit 0;
    }
  }

  while (@childs) {
    if ($self->detect_shutdown) {
      $logger->trace("Sending shutdown to childs (@childs)");
      kill('INT',@childs);
    }
    @childs = grep { waitpid($_,WNOHANG) == 0 } @childs;
    $logger->trace("Active Childs: (@childs)");
    sleep(1);
  }

  return;
}

__PACKAGE__->meta->make_immutable();

1;
