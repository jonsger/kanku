# Copyright (c) 2015 SUSE LLC
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
package Kanku::Roles::Daemon;

use Moose::Role;
use Getopt::Long;
use Path::Class::File;
use Path::Class::Dir;
use Data::Dumper;
use YAML;
use Try::Tiny;
use FindBin;

requires 'run';

has daemon_options => (
  is      => 'rw',
  isa     => 'HashRef',
  default => sub {
    my ($self) = @_;
    my $opts = {};
    GetOptions(
      $opts,
      'stop',
      'foreground|f'
    ) || die $self->print_usage();
    return $opts;
  }
);

has daemon_basename => (
  is => 'rw',
  isa => 'Str',
  default => sub { Path::Class::File->new($0)->basename }
);

sub print_usage {
  my ($self) = @_;
  my $basename = $self->daemon_basename;

  return "\nUsage: $basename [--stop]\n";
}

sub prepare {
  my ($self) = @_;

  if ( $self->daemon_options()->{stop}) {
  };

}

sub initialize_shutdown {
  my ($self) = @_;

  my $run_dir       = "$FindBin::Bin/../var/run";

  if ( ! -d $run_dir ) {
    Path::Class::Dir->new($run_dir)->mkpath();
  }

  Path::Class::File->new($run_dir,$self->daemon_basename.".shutdown")->touch();

}

1;
