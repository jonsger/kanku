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
use Kanku::Remote;
use YAML qw/LoadFile DumpFile/;

extends qw(MooseX::App::Cmd::Command);

has apiurl => (
  traits        => [qw(Getopt)],
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'a',
  documentation => 'Url to your kanku remote instance',
);

has rc_file => (
  traits        => [qw(Getopt)],
  isa           => 'Str',
  is            => 'rw',
  documentation => 'Config file to load and store settings',
  default       => "$ENV{HOME}/.kankurc"
);

has settings => (
  isa           => 'HashRef',
  is            => 'rw',
  default       => sub {{}}
);

sub abstract { "logout from your remote kanku instance" }

sub description { 
  "This command will proceeced a logout from your remote kanku instance, ",
  "delete the local session cookie ".
  "and remove the apiurl incl. settings from your rcfile" 
}

sub execute {
  my $self  = shift;
  my $logger  = Log::Log4perl->get_logger;

  # Please not the priority of options
  # * command line options
  # * rc_file options
  # * manual input
  
  if ( -f $self->rc_file ) {

    $self->settings(LoadFile($self->rc_file));
   
    if ( ! $self->apiurl ) { 
      $self->apiurl( $self->settings->{apiurl} || '');
    }
  }

  while ( ! $self->apiurl ) {
    print "Please enter your apiurl: ";
    my $url = <STDIN>;
    chomp($url);
    $self->apiurl($url) if ($url);
  }

  my $kr =  Kanku::Remote->new(
    apiurl   => $self->apiurl,
  );

  if ( $kr->logout() ) {
    delete $self->settings->{$self->apiurl};
    delete $self->settings->{apiurl};
    $self->save_settings();
    $logger->info("Logout succeed");
  }
}

sub save_settings {
  my $self    = shift;

  DumpFile($self->rc_file,$self->settings);

  return 0;
};

__PACKAGE__->meta->make_immutable;

1;
