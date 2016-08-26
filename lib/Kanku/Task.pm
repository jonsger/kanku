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
package Kanku::Task;

use Moose;
with 'Kanku::Roles::Logger';

use Kanku::Config;
use Kanku::Job;
use JSON::XS;
use Data::Dumper;
use Try::Tiny;

has 'schema'     => (is=>'rw',isa=>'Object');
has 'job'        => (is=>'rw',isa=>'Object');
has 'scheduler'  => (is=>'rw',isa=>'Object');
has 'module'     => (is=>'rw',isa=>'Str');
has 'options'    => (is=>'rw',isa=>'HashRef',default=>sub {{}});
has 'args'       => (is=>'rw',isa=>'HashRef');

sub run {
  my ($self)  = @_;
  my $logger                        = $self->logger;
  my $schema                        = $self->schema();
  my $job                           = $self->job;
  my $handler                       = $self->module;
  my $scheduler                     = $self->scheduler;
  my $args                          = $self->args;

  $logger->debug("Starting task with handler: $handler");

  my %out = ();
  my $last_result = $scheduler->get_last_run_result(
                      $job->name,
                      $handler
                    );

  my $task = $schema->resultset('JobHistorySub')->create({
    job_id  => $job->id,
    name    => $handler,
    state   => 'running'
  });

  # execute subtask
  my $state = undef;
  my $result = undef;
  try {

    my $mod = $handler;
    die "Now use_module definition in config (job: $job)" if ( ! $mod );
    my $mod_args = $args || {};

    die "args for $mod not a HashRef" if ( ref($mod_args) ne 'HASH' );

    my $mod2require = $mod;
    $mod2require =~ s|::|/|g;
    $mod2require = $mod2require . ".pm";
    require "$mod2require";

    my %final_args = (%{$self->{options}},%{$mod_args});

    $logger->trace("final args for $mod:\n".Dumper(\%final_args));

    my $obj = $mod->new(%final_args,job=>$job,schema=>$schema);

    if ( $last_result && $last_result->result() ) {
      my $str = $last_result->result();
      $obj->last_run_result(decode_json($str));
    }

    $obj->logger($logger);

    $out{prepare} = $obj->prepare();

    $out{execute} = $obj->execute();

    $out{finalize} = $obj->finalize();

    $result = encode_json(\%out);
    $state  = 'succeed';
    foreach my  $step ( "prepare","execute","finalize") {

      if (ref($out{$step}) eq "HASH" && $out{$step}->{message} ) {

        $self->logger->debug("-- ".$self->{module}."\->$step: $out{$step}->{message}");

      }

    }

  }
  catch {
    my $e = $_;

    $logger->error($e);
    $result = encode_json({error_message=>$e});
    $state  = 'failed';
    $job->state($state);
  };

  $task->update({
    state => $state,
    result => $result
  });

  $job->update_db();

  return $state;

}

__PACKAGE__->meta->make_immutable();

1;

