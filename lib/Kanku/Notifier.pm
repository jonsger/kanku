# Copyright (c) 2019 SUSE LLC
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
package Kanku::Notifier;

1;

__END__

=head1 NAME

Kanku::Notifier::*

=head1 SYNOPSIS

Here is an example how to configure the module in your kanku-config.yml:

  Kanku::Notifier:
    kanku_url: https://hostname/path

=head1 DESCRIPTION

The variables configured in the section Kanku::Notifier are globally used
to define settings used for all notifiers.

=head1 OPTIONS

kanku_url: this option defines the base url of the kanku web ui.

=head1 DEFAULTS

kanku_url: If not given, it will use http://localhost/kanku

=cut

