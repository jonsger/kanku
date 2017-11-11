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
package Kanku::Cmd::Command::login;

use Moose;
use Data::Dumper;
use Term::ReadKey;
use YAML qw/LoadFile DumpFile/;

extends qw(MooseX::App::Cmd::Command);

with 'Kanku::Cmd::Roles::Remote';

sub abstract { "login to your remote kanku instance" }

sub description { "login to your remote kanku instance" }


sub execute {
  my $self  = shift;
  my $logger  = Log::Log4perl->get_logger;

  # Please note the priority of options
  # * command line options
  # * rc_file options
  # * manual input
  
  if ( -f $self->rc_file ) {

    $self->settings(LoadFile($self->rc_file));
   
    if ( ! $self->apiurl ) { 
      $self->apiurl( $self->settings->{apiurl} || '');
    }
    if ( ! $self->user ) {
      $self->user( $self->settings->{$self->apiurl}->{user} || '');
    }
    if ( ! $self->password ) {
      $self->password( $self->settings->{$self->apiurl}->{password} || '');
    }
  }

  while ( ! $self->apiurl ) {
    print "Please enter your apiurl: ";
    my $url = <STDIN>;
    chomp($url);
    $self->apiurl($url) if ($url);
  }

  $logger->debug("apiurl: " .  $self->apiurl);

  $self->connect_restapi();

  if ( $self->session_valid ) {

    $self->save_settings();

    $logger->info("Already logged in.");
    $logger->info(" Please use logut if you want to change user");
  
 
    return { success => 1 } 
  }

  while ( ! $self->user ) {
    print "Please enter your user: ";
    my $user = <STDIN>;
    chomp($user);
    $self->user($user) if ($user);
  }

  while ( ! $self->password ) {
    
     print "Please enter your password for the remote server:\n";
     ReadMode('noecho');
     my $read = <STDIN>;
     chomp($read);
    
     ReadMode(0); 
     print "Please repeat your password\n";
     ReadMode('noecho');
     my $read2 = <STDIN>;
     chomp($read2);
     ReadMode(0); 
    
     $self->password($read || '') if ( $read eq $read2 );
    
  } 

  $self->user($self->user);
  $self->password($self->password);

  if ( $self->login() ) {
    # Store new default settings
    $self->save_settings(); 
    $logger->info("Login succeed!");
  } else {
    $logger->error("Login failed!");
  }

}

sub save_settings {
  my $self    = shift;

  $self->settings->{apiurl}                    = $self->apiurl;
  $self->settings->{$self->apiurl}->{user}     = $self->user;
  $self->settings->{$self->apiurl}->{password} = $self->password;

  DumpFile($self->rc_file,$self->settings);

  return 0;
}

__PACKAGE__->meta->make_immutable;

1;
