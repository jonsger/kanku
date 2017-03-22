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
package Kanku::Roles::Dispatcher;

use Moose::Role;
use POSIX;
use JSON::XS;
use Data::Dumper;
use Try::Tiny;

use Kanku::Config;
use Kanku::Job;
use Kanku::Task;

with 'Kanku::Roles::ModLoader';
with 'Kanku::Roles::DB';

has '_shutdown_detected' => (is=>'rw',isa=>'Bool',default=>0);

=head1 NAME

Kanku::Roles::Dispatcher - A role for dispatch modules

=head1 REQUIRED METHODS

=head2 run_job - Run a job

=cut

requires "run_job";

=head1 METHODS

=head2 execute_notifier - run a configured notification module

=cut

sub run {
  my ($self) = @_;
  my $logger = $self->logger;
  my @child_pids;
  my $shutdown = 0;

  $self->initialize();

  $self->cleanup_dead_jobs();

  $SIG{'INT'} = sub {
    open(F,'>',"$FindBin::Bin/../var/run/kanku-dispatcher.shutdown");
    close F;
  };

  try {
    $self->cleanup_on_startup();
  } catch {
    $logger->warn($_);
  };

  while (1) {
    my $job_list = $self->get_todo_list();

    while (my $job = shift(@$job_list)) {
      my $pid = fork();

      if (! $pid ) {
        $logger->debug("Child starting with pid $$ -- $self");
        try {
          my $res = $self->run_job($job);
          $logger->debug("Got result from run_job");
          $logger->trace(Dumper($res));
        }
        catch {
          $logger->error("raised exception");
          my $e = shift;
          $logger->error($e);
        };
        $logger->debug("Before exit: $$");
        exit 0;
      } else {
        push (@child_pids,$pid);
       
      
        # wait for childs to exit
        while ( @child_pids >= $self->max_processes ) {
          @child_pids = grep { waitpid($_,WNOHANG) == 0 } @child_pids;
          last if ( $self->_detect_shutdown );
          sleep(1);
          #$self->logger->debug("ChildPids: (@child_pids) ".$self->max_processes."\n");
        }
      }
      last if ( $self->_detect_shutdown );
    }
    last if ( $self->_detect_shutdown );
    sleep 1;
  }

  kill('TERM',@child_pids);
 
  my $wcnt = 0; 

  while ( @child_pids ) {
    # log only every minute
    $self->logger->debug("Waiting for childs to exit: (@child_pids)") if (! $wcnt % 60);
    $wcnt++; 
    @child_pids = grep { waitpid($_,WNOHANG) == 0 } @child_pids;
    sleep(1);
  }

  $self->cleanup_on_exit();

  $self->cleanup_dead_jobs();

  unlink("$FindBin::Bin/../var/run/kanku-dispatcher.shutdown");

  exit 0;
}


sub cleanup_dead_jobs {
  my ($self) = @_;
  my $logger = $self->logger;

  my $dead_jobs = $self->schema->resultset('JobHistory')->search(
    { state => ['running','dispatching'] }
  );
  $dead_jobs->update({ state => 'failed', end_time => time()});

  my $dead_tasks = $self->schema->resultset('JobHistorySub')->search(
    { state => ['running'] }
  );

  $dead_tasks->update({ state => 'failed'});
}

sub run_notifiers {
  my ($self, $job, $last_task) = @_;
  my $logger    = $self->logger();
  my $notifiers = Kanku::Config->instance()->notifiers_config($job->name());
  
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
}

sub execute_notifier {
  my ($self, $options, $job, $task) = @_;

  my $state     = $job->state;

  $self->logger->debug("Job state: $state // $options->{states}");

  my @in        = grep { $state eq $_ } (split(/\s*,\s*/,$options->{states}));

  $self->logger->trace("\@in: '@in'");

  return if (! @in);

  my $mod = $options->{use_module};
  die "No use_module definition in config (job: $job)" if ( ! $mod );

  my $args = $options->{options} || {};
  die "args for $mod not a HashRef" if ( ref($args) ne 'HASH' );

  $self->load_module($mod);

  my $notifier = $mod->new( options=> $args );

  $notifier->short_message("Job ".$job->name." has exited with state '$state'");
  $notifier->full_message($task->result);

  $notifier->notify();

}

sub load_job_definition {
  my ($self, $job)   = @_;
  my $job_definition = undef;

  $self->logger->debug("Loading definition for job: ".$job->name);

  try {
    $job_definition = Kanku::Config->instance()->job_config($job->name);
  }
  catch {
    $job->exit_with_error($_);
  };
  return $job_definition;
} 

sub prepare_job_args  {
  my ($self, $job)      = @_;
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
    $job->exit_with_error($_);
  };

  $self->logger->trace("  -- args:".Dumper($args));

  return $args;
}

sub get_todo_list {
  my $self    = shift;
  my $schema  = $self->schema;
  my $todo = [];
  my $rs = $schema->resultset('JobHistory')->search({state=>['scheduled','triggered']},{ order_by => { -asc => 'creation_time' }} );

  while ( my $ds = $rs->next )   {
    push (
      @$todo,
      Kanku::Job->new(
        db_object => $ds,
        id        => $ds->id,
        state     => $ds->state,
        name      => $ds->name,
        skipped   => 0,
        scheduled => ( $ds->state eq 'scheduled' ) ? 1 : 0,
        triggered => ( $ds->state eq 'triggered' ) ? 1 : 0,
      )
    );
  }

  return $todo;
}

sub start_job {
  my ($self,$job) = @_;

  $self->logger->debug("Starting job: ".$job->name." (".$job->id.")");
  
  $job->start_time(time());
  $job->state("running");
  $job->update_db();
}

sub end_job {
  my ($self,$job,$task) = @_;

  $job->state(($job->skipped) ? 'skipped' : $task->state);
  $job->end_time(time());
  $job->update_db();

  $self->logger->debug("Finished job: ".$job->name." (".$job->id.") with state '".$job->state."'");
}

1;
