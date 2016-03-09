use utf8;
package Kanku::Schema::Result::JobHistory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanku::Schema::Result::JobHistory

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<job_history>

=cut

__PACKAGE__->table("job_history");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 1

=head2 state

  data_type: 'text'
  is_nullable: 1

=head2 args

  data_type: 'text'
  is_nullable: 1

=head2 result

  data_type: 'text'
  is_nullable: 1

=head2 creation_time

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 start_time

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 end_time

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 last_modified

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "state",
  { data_type => "text", is_nullable => 1 },
  "args",
  { data_type => "text", is_nullable => 1 },
  "result",
  { data_type => "text", is_nullable => 1 },
  "creation_time",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "start_time",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "end_time",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "last_modified",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 job_history_subs

Type: has_many

Related object: L<Kanku::Schema::Result::JobHistorySub>

=cut

__PACKAGE__->has_many(
  "job_history_subs",
  "Kanku::Schema::Result::JobHistorySub",
  { "foreign.job_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2016-01-14 15:14:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:F8SGqcNymWr6zqRwI1aXIg

sub TO_JSON {
  my $self = shift;
  my $rv = {};
  for my $col (qw/id name state args result creation_time start_time end_time last_modified/) {
    $rv->{$col} = $self->$col();
  }
  
  return $rv
}
# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
