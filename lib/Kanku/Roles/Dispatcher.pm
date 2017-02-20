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
with 'Kanku::Roles::Logger';

use Kanku::Config;
use Kanku::Job;
use Kanku::Task;
use JSON::XS;
use Data::Dumper;
use Try::Tiny;

has 'schema' => (is=>'rw',isa=>'Object');

=head1 NAME

Kanku::Roles::Dispatcher - A role for dispatch modules

=head1 REQUIRED METHODS

=head2 run - Run a job

=cut

requires "run_job";


=head1 METHODS

=head2 execute_notifier - run a configured notification module

=cut

sub execute_notifier {
  my $self    = shift;
  my $options = shift;
  my $job     = shift;
  my $task    = shift;
  my $state   = $job->state;
  my $in_states = 0;

  foreach my $st (split(/\s*,\s*/,$options->{states})) {
    $in_states = 1 if ($state eq $st);
  }

  return if (! $in_states);

  my $mod = $options->{use_module};
  die "Now use_module definition in config (job: $job)" if ( ! $mod );

  my $args = $options->{options} || {};
  die "args for $mod not a HashRef" if ( ref($args) ne 'HASH' );

  my $mod2require = $mod;
  $mod2require =~ s|::|/|g;
  $mod2require = $mod2require . ".pm";
  $self->logger->debug("Trying to load $mod2require");
  require "$mod2require";

  my $notifier = $mod->new( options=> $args );

  $notifier->short_message("Job ".$job->name." has exited with state '$state'");
  $notifier->full_message($task->result);

  $notifier->notify();

}


#__PACKAGE__->meta->make_immutable();

1;

