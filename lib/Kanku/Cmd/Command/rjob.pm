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
package Kanku::Cmd::Command::rjob;

use Moose;
use Data::Dumper;
use Term::ReadKey;
use YAML qw/LoadFile DumpFile Dump/;
use POSIX;
use Try::Tiny;


extends qw(MooseX::App::Cmd::Command);

with 'Kanku::Cmd::Roles::Remote';
with 'Kanku::Cmd::Roles::RemoteCommand';
with 'Kanku::Cmd::Roles::View';

has config => (
  traits        => [qw(Getopt)],
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases	=> 'c',
  documentation => '(*) show config of remote job. Remote job name mandatory',
);

sub abstract { "show result of tasks from a specified remote job" }

sub description {
  "show result of tasks from a specified job on your remote instance

" . $_[0]->description_footer;
}

sub execute {
  my $self  = shift;
  Kanku::Config->initialize;
  my $logger  = Log::Log4perl->get_logger;

  if ( $self->config ) {
    my $kr;
    try {
      $kr = $self->connect_restapi();
    } catch {
      exit 1;
    };

    my $data = $kr->get_json( path => "job/config/".$self->config);

    print $data->{config} if $data;

  } elsif ($self->list) {

    my $kr;
    try {
      $kr = $self->connect_restapi();
    } catch {
      exit 1;
    };

    my $tmp_data = $kr->get_json( path => "gui_config/job");

    my @job_names = sort ( map { $_->{job_name} } @{$tmp_data->{config}} );
    my $data = { job_names => \@job_names };

    $self->view('rjob/list.tt', $data);

  } elsif ($self->details) {

    my $kr;
    try {
      $kr = $self->connect_restapi();
    } catch {
      exit 1;
    };

    my $data = $kr->get_json( path => "gui_config/job");
	my $job_config;
	while ( my $j = shift( @{$data->{config}} )) {
		if ( $j->{job_name} eq $self->details ) {
			$job_config = $j;
			last;
		}
	}
	print Dumper($job_config);
  } else {
	$logger->warn("Please specify a command. Run 'kanku help rjob' for further information.");
  }
}

__PACKAGE__->meta->make_immutable;

1;
