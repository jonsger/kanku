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
package Kanku::Handler::CleanupIPTables;

use Moose;
use Kanku::Util::VM;
use Kanku::Util::IPTables;
use Try::Tiny;
use Carp;
with 'Kanku::Roles::Handler';

has domain_name => (
  is   => 'rw',
  isa  => 'Str',
  lazy => 1,
  default => sub { $_[0]->job()->context()->{domain_name} || '' }
);

has disabled => (is => 'rw',isa=>'Bool');

has gui_config => (
  is => 'ro',
  isa => 'ArrayRef',
  lazy => 1,
  default => sub {
      [
        {
          param => 'domain_name',
          type  => 'text',
          label => 'Domain Name:'
        },
        {
          param => 'disabled',
          type  => 'checkbox',
          label => 'Disabled'
        },
      ];
  }
);

sub execute {

  my $self = shift;

  confess "No domain_name given!\n" if (! $self->domain_name );

  if ( $self->disabled ) {
      return {
        code    => 0,
        message => "Skipped cleanup of iptables rules for domain " . $self->domain_name ." because of disabled job"
      }
  }

  my $ipt = Kanku::Util::IPTables->new(domain_name=>$self->domain_name);

  $ipt->cleanup_rules_for_domain();

  return {
    code    => 0,
    message => "Successfully cleaned up iptables rules for domain " . $self->domain_name
  }

}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Kanku::Handler::CleanupIPTables

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::CleanupIPTables
    options:
      domain_name: domain-to-cleanup

=head1 DESCRIPTION

This handler removes configured port forwarding rules.

=head1 OPTIONS

    domain_name           : name of domain to remove

=head1 CONTEXT

=head2 getters

 domain_name

=head2 setters

NONE

=head1 DEFAULTS

NONE

=cut
