# Copyright (c) 2017 SUSE LLC
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
package Kanku::Roles::ModLoader;

use Moose::Role;
use Carp;
with 'Kanku::Roles::Logger';

sub load_module {
  my ($self,$mod) = @_;  

  confess "No mod given!" if (! $mod);

  $self->logger->debug("Trying to load module $mod");

  my $mod2require = $mod;
  $mod2require =~ s|::|/|g;
  $mod2require = $mod2require . ".pm";
  require "$mod2require";
}

1; 
