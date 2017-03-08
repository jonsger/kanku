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
package Kanku::JobList;

use Moose;
use Data::Dumper;

with 'Kanku::Roles::DB';

has "context" => (
    is  => 'rw',
    isa => 'HashRef',
    default => sub { {} }
);

has [qw/db_object/ ] => ( is => 'rw', isa => 'Object' );

=head2 get_last_run_result - Get result from the latest previous run

=cut

sub get_last_run_result {
  my $self     = shift;
  my $sub_task = shift;
  my $job_name = shift;
  my $schema   = $self->schema();
  my $lr       = undef;

  my $job = $self->get_last_job($job_name);

  die "sub_task name must be given as second argument" unless $sub_task;

  if ( $job ) {
        my $subs = $job->job_history_subs();
        return $subs->search({name => $sub_task},{order_by => { '-desc' =>'id'},limit=>1})->first();
  }

  return undef
}

=head2 get_last_job - Get database entry for the latest previous run

=cut

sub get_last_job {
  my $self     = shift;
  my $job_name = shift;
  my $schema   = $self->schema();

  die "job_name must be given" unless $job_name;

  my $jobs_list = $schema->resultset('JobHistory')
                    ->search(
                      {
                        name=>$job_name,
                        end_time=>{ '>'=>0},
                      },{
                        order_by=>{
                          '-desc'=>'last_modified'
                        },
                        limit=>1
                      }
                    );

  return $jobs_list->next();
}

sub get_job_activ {
  my $self     = shift;
  my $job_name = shift;
  my $schema   = $self->schema();

  die "job_name must be given" unless $job_name;

  my $jobs_list = $schema->resultset('JobHistory')
                    ->search(
                      {
                        name=>$job_name,
			state => ["scheduled","triggered","running","dispatching"]
                      },{
                        order_by=>{
                          '-desc'=>'creation_time'
                        },
                        limit=>1
                      }
                    );

  return $jobs_list->next();
}



__PACKAGE__->meta->make_immutable;

1;
