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
package Kanku::Cmd::Roles::Remote;

use Moose::Role;
use  Log::Log4perl;
use YAML qw/LoadFile/;
use Kanku::Remote;

has apiurl => (
  traits        => [qw(Getopt)],
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'a',
  documentation => 'Url to your kanku remote instance',
);

has user => (
  traits        => [qw(Getopt)],
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'u',
  documentation => 'Login user to to connect to your kanku remote instance',
);

has password => (
  traits        => [qw(Getopt)],
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'p',
  documentation => 'Login password to connect to your kanku remote instance',
);

has rc_file => (
  traits        => [qw(Getopt)],
  isa           => 'Str',
  is            => 'rw',
  documentation => 'Config file to load and store settings',
  default       => "$ENV{HOME}/.kankurc"
);

has settings => (
  isa           => 'HashRef',
  is            => 'rw',
  default       => sub {{}}
);

sub _connect_restapi {
  my $self = shift;
  my $logger  = Log::Log4perl->get_logger;

  if ( ! $self->apiurl ) { 
    if ( -f $self->rc_file ) {
      $self->settings(LoadFile($self->rc_file));
      $self->apiurl( $self->settings->{apiurl} || '');
    }
  }

  if ( ! $self->apiurl ) {
    $logger->error("No apiurl found - Please login");
	die "No apiurl found!";
  }

  my $kr =  Kanku::Remote->new(
    apiurl   => $self->apiurl,
  );

  return $kr;
}

1;
