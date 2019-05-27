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
package Kanku::Handler::FileMove;

use Moose;
use Path::Class qw/file/;

with 'Kanku::Roles::Handler';
with 'Kanku::Roles::Logger';

sub execute {
  my $self  = shift;
  my $pkg   = __PACKAGE__;
  my $files_to_move = $self->job->context->{$pkg}->{files_to_move};

  while ( my $i = shift @$files_to_move ) {
    my $src = file($i->[0]);
    my $dst = file($i->[1]);

    $self->logger->info("Moving ". $src->stringify);
    $self->logger->info("  to ". $dst->stringify);

    ( -d $dst->parent ) || $dst->parent->mkpath;

    $src->move_to($dst) || die "Could not move ". $src ." to ".$dst."\n";

  }

  return {
    code    => 0,
    message => "Successfully moved all files in files_to_move stack"
  }

}

1;

__END__

=head1 NAME

Kanku::Handler::FileMove

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::FileMove

=head1 DESCRIPTION

This handler moves a file in the filesystem.

=head1 OPTIONS

NONE

=head1 CONTEXT

=head2 getters

 files_to_move      : array of move jobs. 1st element is src, 2nd is dst

=head2 setters

NONE

=head1 DEFAULTS

NONE


=cut

