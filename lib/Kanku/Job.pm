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
use JSON::XS;
with 'Kanku::Roles::Serialize';
with 'Kanku::Roles::Logger';

has "context" => (
    is  => 'rw',
    isa => 'HashRef',
    default => sub { {} }
);

has id => ( is  => 'rw', isa => 'Int' );
has [qw/name state result workerinfo masterinfo trigger_user/] => ( is => 'rw', isa => 'Str' );
has [qw/skipped scheduled triggered/] => ( is => 'rw', isa => 'Bool' );
has [qw/creation_time start_time end_time last_modified/] => ( is  => 'rw', isa => 'Int' );
has db_object => ( is => 'rw', isa => 'Object' );
has '+workerinfo' => (default =>"localhost");

sub json_keys; # prototype to not break the requires in Kanku::Roles::Serialize
has 'json_keys' => (
  is      => 'rw',
  isa     => 'ArrayRef',
  default => sub {[qw/
    name state result workerinfo skipped scheduled triggered creation_time
    start_time end_time last_modified id context masterinfo trigger_user
  /
  ]});

sub update_db {
  my $self = shift;
  my $ds = { last_modified => time() };

  foreach my $key ( qw/id name state start_time end_time result workerinfo masterinfo trigger_user/ ) {
    my $value = $self->$key();
    $ds->{$key} = $value if ( $value );
  }

  return $self->db_object->update($ds);

}

sub exit_with_error {
  my ($self,$error) = @_;
  $self->logger->error($error);
  $self->result(encode_json({error_message=>$error}));
  $self->state('failed');
  $self->end_time(time());
  $self->update_db();
  die $error;
}

__PACKAGE__->meta->make_immutable;

1;
