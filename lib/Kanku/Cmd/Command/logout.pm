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
package Kanku::Cmd::Command::logout;

use Moose;
use Data::Dumper;
use Term::ReadKey;
use Kanku::YAML;

extends qw(MooseX::App::Cmd::Command);

with 'Kanku::Cmd::Roles::Remote';

sub abstract { "logout from your remote kanku instance" }

sub description {
  "This command will proceeced a logout from your remote kanku instance, ",
  "delete the local session cookie ".
  "and remove the apiurl incl. settings from your rcfile"
}

sub execute {
  my $self  = shift;
  my $logger  = Log::Log4perl->get_logger;

  my $kr =  $self->connect_restapi();

  if ( $kr->logout() ) {
    delete $self->settings->{$self->apiurl};
    delete $self->settings->{apiurl};
    $self->save_settings();
    $logger->info("Logout succeed");
  }
}

sub save_settings {
  my $self    = shift;

  Kanku::YAML::DumpFile($self->rc_file, $self->settings);

  return 0;
};

__PACKAGE__->meta->make_immutable;

1;
