use utf8;
package Kanku::Schema::Result::ObsCheckHistory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanku::Schema::Result::ObsCheckHistory

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<obs_check_history>

=cut

__PACKAGE__->table("obs_check_history");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 api_url

  data_type: 'text'
  is_nullable: 1

=head2 project

  data_type: 'text'
  is_nullable: 1

=head2 package

  data_type: 'text'
  is_nullable: 1

=head2 vm_image_url

  data_type: 'text'
  is_nullable: 1

=head2 check_time

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "api_url",
  { data_type => "text", is_nullable => 1 },
  "project",
  { data_type => "text", is_nullable => 1 },
  "package",
  { data_type => "text", is_nullable => 1 },
  "vm_image_url",
  { data_type => "text", is_nullable => 1 },
  "check_time",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-04-24 00:28:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:nuC6cRD2M1Qy4Bd2OUXeWQ
# These lines were loaded from 'lib/Kanku/Schema/Result/ObsCheckHistory.pm' found in @INC.
# They are now part of the custom portion of this file
# for you to hand-edit.  If you do not either delete
# this section or remove that file from @INC, this section
# will be repeated redundantly when you re-create this
# file again via Loader!  See skip_load_external to disable
# this feature.

__PACKAGE__->might_have(
  image => 'Kanku::Schema::Result::ImageDownloadHistory',
  'vm_image_url'
);
  # For UNIQUE (column1, column2)
__PACKAGE__->add_unique_constraint(
  unique_obscheck => [ qw/api_url project package/ ],
);
# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
