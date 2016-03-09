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
package Kanku::Handler::RemoveDomain;

use Moose;
use Kanku::Util::VM;
use Kanku::Util::IPTables;
use Sys::Virt;
with 'Kanku::Roles::Handler';

has [qw/uri domain_name/] => (is => 'rw',isa=>'Str');

sub execute {

  my $self = shift;

  if ( $self->job()->context()->{domain_name} ) {
    $self->domain_name($self->job()->context()->{domain_name});
  }

  my $vm    = Kanku::Util::VM->new( domain_name => $self->domain_name );

  eval {
    $vm->remove_domain();
  };

  $self->logger->warn("Error while removing domain: ".$self->domain_name) if $@;

  my $ipt = Kanku::Util::IPTables->new(domain_name=>$self->domain_name);

  $ipt->cleanup_rules_for_domain();

  return {
    code    => 0,
    message => "Successfully removed domain " . $self->domain_name
  }

}

1;

