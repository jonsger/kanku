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

has 'schema' => (is=>'rw',isa=>'Object');


sub run {
  my $self    = shift;
  while (1) {
    my $job_list = $self->get_todo_list();

    foreach my $job (@$job_list) {
      $self->run_job($job);
    }

    sleep 1;
  }
}

sub run_job {
  my $self    = shift;
  my $job     = shift;
  my $logger  = $self->logger();
  my $schema  = $self->schema();

  my $job_definition = Kanku::Config->instance()->job_config($job->name());
  my $notifiers = Kanku::Config->instance()->notifiers_config($job->name());

  if (! $job_definition ) {
    # log error
    $logger->error($@);

    # update database fields
    $job->result(encode_json({error_message=>"job with this name not configured in config.yml"}));
    $job->state('failed');
    $job->start_time(time());
    $job->end_time(time());

    # write to database
    $job->update_db();

    return 1

  }

  $logger->debug("Starting job: ".$job->name);

  $job->start_time(time());
  $job->state("running");
  $job->update_db();

  my $state             = undef;
  my $args              = [];
  my $parse_args_failed = 0;

  try {
      my $args_string = $job->db_object->args();

      if ($args_string) {
        $args = decode_json($args_string);
      }

      die "args not containting a ArrayRef" if (ref($args) ne "ARRAY" );

  }
  catch {
    my $e = $_;

    $logger->error($e);
    $job->result(encode_json({error_message=>$e}));
    $job->state('failed');
    $job->end_time(time());
    $job->update_db();
    $parse_args_failed=1;
  };

  return 1 if $parse_args_failed;

  $logger->trace("  -- args:".Dumper($args));

  my $task_counter = 0;

  my $last_task;

  foreach my $sub_task (@{$job_definition}) {

    my $task = Kanku::Task->new(
      job       => $job,
      options   => $sub_task->{options} || {},
      module    => $sub_task->{use_module},
      schema    => $schema,
      scheduler => $self,
      args      => $args->[$task_counter] || {},
    );
    $last_task = $task;
    $state = $task->run();

    last if ($state eq 'failed');

    $task_counter++;

    last if ($job->skipped);

  }

  $job->state(($job->skipped) ? 'skipped' : $state);
  $job->end_time(time());
  $job->update_db();

  foreach my $notifier (@{$notifiers}) {
    try {
	$self->execute_notifier($notifier,$job,$last_task);
    }
    catch {
      my $e = $_;
      $logger->error("Error while sending notification");
      $logger->error($e);
    };
  }


  return $job->state;
}

__PACKAGE__->meta->make_immutable();

1;

