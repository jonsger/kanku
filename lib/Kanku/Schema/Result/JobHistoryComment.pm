use utf8;
package Kanku::Schema::Result::JobHistoryComment;

use JSON::XS;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table("job_history_comment");


__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "job_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "comment",
  { data_type => "text", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(
  "job",
  "Kanku::Schema::Result::JobHistory",
  { id => "job_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);

__PACKAGE__->belongs_to(
  "user",
  "Kanku::Schema::Result::User",
  { id => "user_id" },
#  {
#    is_deferrable => 0,
#    join_type     => "LEFT",
#    on_delete     => "CASCADE",
#    on_update     => "NO ACTION",
#  },
);

sub TO_JSON {
  my $self = shift;
  my $rv = {};
  for my $col (qw/id job_id user_id comment/) {
    $rv->{$col} = $self->$col();
  }

  $rv->{user} = $self->user->TO_JSON;
  return $rv
}


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
