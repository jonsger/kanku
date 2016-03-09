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
package Kanku::Handler::GIT;

use Moose;

use Data::Dumper;

use namespace::autoclean;


with 'Kanku::Roles::Handler';
with 'Kanku::Roles::Logger';
with 'Kanku::Roles::SSH';

has [qw/  ipaddress
          publickey_path
          privatekey_path passphrase  username
          giturl          revision    destination
    /] => (is=>'rw',isa=>'Str');

has 'submodules' => (is=>'rw',isa=>'Bool');

has gui_config => (
  is => 'ro',
  isa => 'ArrayRef',
  lazy => 1,
  default => sub {
      [
        {
          param => 'giturl',
          type  => 'text',
          label => 'Git URL'
        },
        {
          param => 'destination',
          type  => 'text',
          label => 'Destination'
        },
        {
          param => 'revision',
          type  => 'text',
          label => 'Revision'
        },
      ];
  }
);


sub prepare {
  my $self = shift;

  die "No giturl given"  if (! $self->giturl );

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

  # clone git repository
  my $cmd_clone     = "git clone " .  $self->giturl . ( ( $self->destination ) ? " " . $self->destination : '');

  $self->exec_command($cmd_clone);

  my $git_dest      = ( $self->destination ) ? " -C " . $self->destination : '';

  # checkout specific revision if revision given
  if ( $self->revision ) {
      my $cmd_checkout  = "git".$git_dest." checkout " .  $self->revision;

      $self->exec_command($cmd_checkout);
  }

  if ( $self->submodules ) {
      my $cmd_submodule_init = "git".$git_dest." submodule init";
      $self->exec_command($cmd_submodule_init);

      my $cmd_submodule_update = "git".$git_dest." submodule update";
      $self->exec_command($cmd_submodule_update);
  }

  return {
    code        => 0,
    message     => "git clone from url ".$self->giturl." and checkout of revision ".$self->revision." was successful",
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
