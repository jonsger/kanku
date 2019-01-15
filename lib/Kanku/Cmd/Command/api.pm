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
package Kanku::Cmd::Command::api;

use Moose;
use Data::Dumper;
use Term::ReadKey;
use Try::Tiny;

extends qw(MooseX::App::Cmd::Command);

with 'Kanku::Cmd::Roles::Remote';
with 'Kanku::Cmd::Roles::RemoteCommand';

sub abstract { "make (GET) requests to api with arbitrary (sub) uri" }

sub description {
  "list guests on your remote kanku instance

" . $_[0]->description_footer;
}

has uri => (
  traits        => [qw(Getopt)],
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'u',
  documentation => 'uri to send request to',
);

has param => (
  traits        => [qw(Getopt)],
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'p',
  documentation => 'parameters to send',
);

sub execute {
  my $self  = shift;
  my $logger  = Log::Log4perl->get_logger;

  # $logger->warn("Please specify a command. Run 'kanku help rguest' for further information.");
  my $kr;
  try {
	$kr = $self->connect_restapi();
  } catch {
	exit 1;
  };

  my $data = $kr->get_json( path => $self->uri );
  print Dumper($data);
}

__PACKAGE__->meta->make_immutable;

1;
