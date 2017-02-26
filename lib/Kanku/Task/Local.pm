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
package Kanku::Task::Local;

=head1 NAME

Kanku::Task - single task which executes a Handler

=cut

use Moose;
with 'Kanku::Roles::Logger';
with 'Kanku::Roles::ModLoader';

use JSON::XS;
use Data::Dumper;

=head1 ATTRIBUTES

=cut

=head2 job       - a Kanku::Job object of parent job

=cut

has 'job'             => (is=>'rw',isa=>'Object');

=head2 module    - name of the Kanku::Handler::* module to be executed

=cut

has 'module'          => (is=>'rw',isa=>'Str');

=head2 args      - arguments for the Handler from e.g. webfrontend

optional arguments which could be used to overwrite options from the config file

=cut

has 'final_args'      => (is=>'rw',isa=>'HashRef',default=>sub {{}} );

has 'last_run_result' => (is=>'rw',isa=>'HashRef',default=>sub {{}} );

has 'schema'             => (is=>'rw',isa=>'Object');

=head1 METHODS

=head2 run - execute prepare/execute/finalize

=cut

sub run {
  my ($self) = @_;
  my $state  = undef;
  my $result = undef;
  my $job    = $self->job;
  my $mod    = $self->module;
  my %out;
  $self->load_module($mod);
  $self->logger->trace("final_args:\n" . Dumper($self->final_args));
  my $obj = $mod->new(
    %{$self->final_args},
    job             => $job,
    logger          => $self->logger,
    schema          => $self->schema,
    last_run_result => $self->last_run_result,
  );

  $out{prepare}  = $obj->prepare();

  $out{execute}  = $obj->execute();

  $out{finalize} = $obj->finalize();

  $result = encode_json(\%out);
  $state  = 'succeed';

  foreach my  $step ( "prepare","execute","finalize") {
    if (ref($out{$step}) eq "HASH" && $out{$step}->{message} ) {
      $self->logger->debug("-- ".$self->{module}."\->$step: $out{$step}->{message}");
    }
  }

  return {
    result => $result,
    state  => $state
  }
}

__PACKAGE__->meta->make_immutable();

1;

