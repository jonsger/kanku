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
package Kanku::Scheduler;

use Moose;
with 'Kanku::Roles::Logger';

use Kanku::Config;
use Kanku::Job;
use Kanku::Dispatch::Local;
use Kanku::Task;
use JSON::XS;
use Data::Dumper;
use Try::Tiny;
has 'schema' => (is=>'rw',isa=>'Object');

sub run {
  my $self    = shift;
  my $logger  = $self->logger();
  my $schema  = $self->schema();

  $logger->warn("Running Kanku::Scheduler");

  # Set all running jobs to failed on startup
  # TODO: In a more distributed setup we need some
  # other mechanism here
  #
  my @running_jobs = $schema->resultset('JobHistory')->search({ state => 'running' });

  foreach my $job (@running_jobs) {
    $job->update({ state=>'failed', end_time => time() });
  }

  my @no_end_time_jobs = $schema->resultset('JobHistory')->search({ end_time => 0 });

  foreach my $job (@no_end_time_jobs) {
    $job->update({ state=>'failed', end_time => time() });
  }

  my $dispatcher = Kanku::Dispatch::Local->new(schema => $schema);
  while (1) {
    $self->create_scheduled_jobs();

    # TODO: we need a better delay algorithm here
    sleep 1;
  }
}

sub create_scheduled_jobs {
  my $self    = shift;
  my $logger  = $self->logger();
  my $cfg     = Kanku::Config->instance();
  my $schema  = $self->schema();
  my $counter = 0;
  # Create scheduler entries
  #
  #$logger->debug("Starting rescheduling\n");

  foreach my $job (@{$cfg->config->{'Kanku::Scheduler'}}){
    $counter++;

    my $job_name = $job->{job_name};
    if (! $job_name ) {
      die "Missing job_name Kanku::Scheduler configuration (section $counter)\n".
            "Please fix your configuration!\n";
    }

    my $reschedule = 1;
    my $rs = $schema->resultset('JobHistory')->search({name=>$job_name});


    # check last run
    # if was less than delay ago suspend rescheduling
    my $jl = Kanku::JobList->new(schema=>$schema);
    my $lr = $jl->get_last_job($job_name);

    if ($lr) {
        my $next_run = $lr->last_modified + $job->{delay};
        my $now = time();

#        $logger->debug("  - Checking if next_run($next_run) greater than now($now)");

        if ($next_run > time() ) {
            $reschedule = 0;
        }
    } else {
      $logger->trace("  - No last run result found!");
    }

    if ($jl->get_scheduled_or_triggered_job($job_name) ) {
      $reschedule = 0;
    }

    if ( $reschedule ) {
        $logger->debug(" - Rescheduling job '".$job_name."'");
        $schema->resultset('JobHistory')->create({
              name => $job_name,
              creation_time => time(),
              last_modified => time(),
              state => 'scheduled'
          }
        );
    }
  }

};

__PACKAGE__->meta->make_immutable();

1;

