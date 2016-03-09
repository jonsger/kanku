package Kanku::Schema::Result::UserRoles;
use base qw/DBIx::Class::Core/;
__PACKAGE__->table('user_roles');
__PACKAGE__->add_columns(
    user_id  => { data_type => 'integer' },
    role_id  => { data_type => 'integer' },
);
__PACKAGE__->set_primary_key('user_id', 'role_id');
__PACKAGE__->belongs_to(user => "Kanku::Schema::Result::User", "user_id");
__PACKAGE__->belongs_to(role => "Kanku::Schema::Result::Role", "role_id");
1;

