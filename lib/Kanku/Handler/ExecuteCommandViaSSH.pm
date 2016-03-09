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
package Kanku::Handler::ExecuteCommandViaSSH;

use Moose;

use Data::Dumper;

use namespace::autoclean;

with 'Kanku::Roles::Handler';
with 'Kanku::Roles::Logger';
with 'Kanku::Roles::SSH';

has [qw/ipaddress publickey_path privatekey_path passphrase username/] => (is=>'rw',isa=>'Str');
has commands => (is=>'rw',isa=>'ArrayRef',default=>sub { [] });

sub prepare {
  my $self = shift;

  $self->get_defaults();

  return {
    code => 0,
    message => "Preparation successful"
  };
}

sub execute {
  my $self    = shift;
  my $results = [];
  my $ssh2    = $self->connect();
  my $ip      = $self->ipaddress;

  foreach my $cmd ( @{$self->commands} ) {
    
      my $out = $self->exec_command($cmd);

      push @$results, {
        command     => $cmd,
        exit_status => 0,
        message     => $out
      };

  }

  return {
    code        => 0,
    message     => "All commands on $ip executed successfully",
    subresults  => $results
  };
}

sub finalize {
  return {
    code    => 0,
    message => "Nothing to do!"
  }
}

__PACKAGE__->meta->make_immutable;

1;
