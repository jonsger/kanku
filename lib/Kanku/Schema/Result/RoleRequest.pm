use utf8;
package Kanku::Schema::Result::RoleRequest;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table("role_request");

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_nullable => 0 },
  "creation_time",
  { data_type => "integer", is_nullable => 0 },
  "roles",
  { data_type => "text" },
  "comment",
  { data_type => "text" },
  "decision",
  # 0 - undecided, 1 - accepted, 2 - declined
  { data_type => "integer", is_nullable => 0, default_value => 0},
  "decision_comment",
  { data_type => "text" },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(
  "user",
  "Kanku::Schema::Result::User",
  { "foreign.id" => "self.user_id" },
);
#__PACKAGE__->has_many(
#  "user_roles",
#  "Kanku::Schema::Result::UserRole",
#  { "foreign.role_id" => "self.id" },
#  { cascade_copy => 0, cascade_delete => 0 },
#);
#__PACKAGE__->many_to_many("users", "user_roles", "user");

1;
