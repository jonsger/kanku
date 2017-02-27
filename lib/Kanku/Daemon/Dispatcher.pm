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
package Kanku::Daemon::Dispatcher;

use Moose;
use Data::Dumper;

with 'Kanku::Roles::ModLoader';
with 'Kanku::Roles::DB';

sub run {
  my ($self) = @_;
  my $cfg = Kanku::Config->instance();

  my $mod = $cfg->config->{dispatcher} || "Kanku::Dispatch::Local";
  $self->load_module($mod);

  $mod->new(schema=>$self->schema)->run();
}

__PACKAGE__->meta->make_immutable;

1;
