use utf8;
package Kanku::Schema::Result::ImageDownloadHistory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanku::Schema::Result::ImageDownloadHistory

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<image_download_history>

=cut

__PACKAGE__->table("image_download_history");

=head1 ACCESSORS

=head2 vm_image_url

  data_type: 'text'
  is_nullable: 0

=head2 vm_image_file

  data_type: 'text'
  is_nullable: 1

=head2 download_time

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "vm_image_url",
  { data_type => "text", is_nullable => 0 },
  "vm_image_file",
  { data_type => "text", is_nullable => 1 },
  "download_time",
  { data_type => "integer", is_nullable => 1 },
  "etag",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</vm_image_url>

=back

=cut

__PACKAGE__->set_primary_key("vm_image_url");


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-11-16 13:40:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:fgDMJNvwgjKd0t6rRX0jPw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
