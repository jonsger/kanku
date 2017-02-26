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
package Kanku::Dispatch::Local;

use Moose;

with 'Kanku::Roles::Logger';
with 'Kanku::Roles::Dispatcher';

use Kanku::Config;
use Kanku::Job;
use Kanku::Task;
use JSON::XS;
use Data::Dumper;
use Try::Tiny;

has 'max_processes' => (is=>'rw',isa=>'Int',default=>1);


sub run_job {
  my $self    = shift;
  my $job     = shift;
  my $logger  = $self->logger();
  my $schema  = $self->schema();

  my $job_definition = $self->load_job_definition($job);
  if ( ! $job_definition) {
    $logger->error("No job definition found!");
    return "failed";
  }

  $self->start_job($job);

  my $state             = undef;
  my $args              = $self->prepare_job_args($job);

  return 1 if (! $args);

  $logger->trace("  -- args:".Dumper($args));

  my $last_task;

  foreach my $sub_task (@{$job_definition}) {
    my $task_args = shift(@$args) || {};
    my $task = Kanku::Task->new(
      job       => $job,
      options   => $sub_task->{options} || {},
      module    => $sub_task->{use_module},
      schema    => $schema,
      scheduler => $self,
      args      => $task_args
    );
    $last_task = $task;
    $state = $task->run();

    last if ( $state eq 'failed' or $job->skipped);
  }

  $job->state($state);

  $self->end_job($job,$state);

  $self->run_notifiers($job,$last_task);

  return $job->state;
}

__PACKAGE__->meta->make_immutable();

1;

