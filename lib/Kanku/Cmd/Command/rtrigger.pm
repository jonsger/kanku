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
package Kanku::Cmd::Command::rtrigger;

use Moose;
use Data::Dumper;
use Term::ReadKey;
use YAML qw/LoadFile DumpFile Dump/;
use POSIX;
use Try::Tiny;
use JSON::XS;


extends qw(MooseX::App::Cmd::Command);

with 'Kanku::Cmd::Roles::Remote';
with 'Kanku::Cmd::Roles::RemoteCommand';
with 'Kanku::Cmd::Roles::View';

has job => (
  traits        => [qw(Getopt)],
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases	=> 'j',
  documentation => '(*) Remote job name - mandatory',
);

has config => (
  traits        => [qw(Getopt)],
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases	=> 'c',
  documentation => '(*) use given config for remote job. example: -c "[]"',
);

sub abstract { "trigger a remote job given by name" }

sub description {
  "trigger a specified job on your remote instance

" . $_[0]->description_footer;
}

sub execute {
  my $self  = shift;
  Kanku::Config->initialize();
  my $logger  = Log::Log4perl->get_logger;

  if ( $self->job ) {
    my $kr;
    try {
      $kr = $self->connect_restapi();
    } catch {
      exit 1;
    };

    my $data = $kr->post_json(
      # path is only subpath, rest is added by post_json
      path => "job/trigger/".$self->job,
      data => $self->config || '[]'
    );

    $self->view('rtrigger.tt', $data); 
  } else {
	$logger->error("You must at least specify a job name to trigger");
  }
}

__PACKAGE__->meta->make_immutable;

1;
