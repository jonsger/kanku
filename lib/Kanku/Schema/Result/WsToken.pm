package Kanku::Schema::Result::WsToken;
use base qw/DBIx::Class::Core/;
__PACKAGE__->table('wstoken');
__PACKAGE__->add_columns(
    user_id        => { data_type => 'integer' },
    auth_token     => { data_type => 'varchar', size => 32 },
);
__PACKAGE__->set_primary_key('auth_token');
__PACKAGE__->belongs_to(
    user => "Kanku::Schema::Result::User",
    "user_id"
);

1;
