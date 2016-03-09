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
package Kanku::Job;

use Moose;
use Data::Dumper;


has "context" => (
    is  => 'rw',
    isa => 'HashRef',
    default => sub { {} }
);

has id => ( is  => 'rw', isa => 'Int' );
has [qw/name state result/] => ( is => 'rw', isa => 'Str' );
has [qw/skipped scheduled triggered/] => ( is => 'rw', isa => 'Bool' );
has [qw/creation_time start_time end_time last_modified/] => ( is  => 'rw', isa => 'Int' );
has db_object => ( is => 'rw', isa => 'Object' );

sub update_db {
  my $self = shift;
  my $ds = { last_modified => time() };

  foreach my $key ( qw/id name state start_time end_time result/ ) {
    my $value = $self->$key();
    $ds->{$key} = $value if ( $value );
  }

  return $self->db_object->update($ds);

}

1;

