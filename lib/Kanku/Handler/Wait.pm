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
package Kanku::Handler::Wait;

use Moose;
with 'Kanku::Roles::Handler';

has [qw/delay reason/] => (is=>'rw',isa=>'Str');

sub prepare {
  return {
    code    => 0,
    message => "Nothing to do"
  };
}

sub execute {
  my $self = shift;

  sleep $self->delay;

  my $reason = $self->reason || "Not configured";

  return {
    code => 0,
    message => "Slept for " . $self->delay . ". Reason: $reason"
  };
}

sub finalize {
  return {
    code    => 0,
    message => "Nothing to do"
  };
}

1;