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
package Kanku::Daemon::Scheduler;

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

sub run {
  my $self    = shift;
  my $logger  = $self->logger();

  $logger->info("Running Kanku::Daemon::Scheduler");

  while (1) {
    $self->create_scheduled_jobs();

    last if $self->detect_shutdown();

    # TODO: we need a better delay algorithm here
    sleep 1;
  }

  return;
}

sub create_scheduled_jobs {
  my $self    = shift;
  my $logger  = $self->logger();
  my $cfg     = Kanku::Config->instance();
  my $schema  = $self->schema();
  my $counter = 0;

  # Create scheduler entries
  #
  #
  if ( $cfg->config->{'Kanku::Scheduler'}) {
    $logger->warn("Kanku::Scheduler in config file is deprecated. Please change to Kanku::Daemon::Scheduler")
  }
  # Kanku::Scheduler is in there because of backwards compability
  foreach my $job (@{$cfg->config->{'Kanku::Scheduler'} || $cfg->config->{'Kanku::Daemon::Scheduler'}}){
    $counter++;

    my $job_name = $job->{job_name};
    if (! $job_name ) {
      die "Missing job_name Kanku::Daemon::Scheduler configuration (section $counter)\n".
            "Please fix your configuration!\n";
    }

    my $reschedule = 1;

    my $jl = Kanku::JobList->new(schema=>$schema);

    if ($jl->get_job_active($job_name) ) {
      $reschedule = 0;
    } else {
      # check last run
      # if was less than delay ago suspend rescheduling
      my $lr = $jl->get_last_job($job_name);

      if ($lr) {
	  my $next_run = $lr->last_modified + $job->{delay};
	  my $now = time();

	  #$logger->debug("  - Checking if next_run($next_run) > now($now)");

	  if ($next_run > $now ) {
	      $reschedule = 0;
	  }
      }
    }

    if ( $reschedule ) {
      $logger->debug(" - Rescheduling job '".$job_name."'");
      $schema->resultset('JobHistory')->create(
        {
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
