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
package Kanku::Roles::SSH;

use Moose::Role;

use Data::Dumper;
use Net::SSH2;
use namespace::autoclean;
use Kanku::Config;

with 'Kanku::Roles::Logger';

has 'passphrase' => (
  is	  => 'rw',
  isa	  => 'Str',
  default => ''
);

has 'privatekey_path' => (
  is	  => 'rw',
  isa	  => 'Str',
  lazy	  => 1,
  default => sub { 
    return $_[0]->job->context->{privatekey_path}
    || Kanku::Config->instance()->config()->{'Kanku::Roles::SSH'}->{privatekey_path}
    || '';
  }
);

has 'publickey_path' => (
  is	  => 'rw',
  isa	  => 'Str',
  lazy	  => 1,
  default => sub {
    return $_[0]->job->context->{publickey_path}
    || Kanku::Config->instance()->config()->{'Kanku::Roles::SSH'}->{publickey_path}
    || '';
  }
);

has 'ipaddress' => (
  is	  => 'rw',
  isa	  => 'Str',
  lazy    => 1,
  default => sub { $_[0]->job->context->{ipaddress} || '' }
);

has 'username' => (
  is	  => 'rw',
  isa	  => 'Str',
  lazy    => 1,
  default => 'root'
);

has 'connect_timeout' => (
  is	  => 'rw',
  isa	  => 'Int',
  default => 300
);

has [ qw/job ssh2/ ] => (
  is => 'rw',
  isa => 'Object'
);

has auth_type => (
  is=>'rw',
  isa=>'Str',
  lazy => 1,
  default=>
  sub {
    my $cfg = Kanku::Config->instance->config();
    my $pkg = __PACKAGE__;

    # agent has to stay default for cli tool
    return $cfg->{$pkg}->{auth_type} || 'agent';
  }
);

has ENV => (
  is=>'rw',
  isa=>'HashRef',
  lazy => 1,
  default=> sub {{}}
);

sub get_defaults {
  my $self = shift;
  my $logger  = $self->logger;

  if (! $self->privatekey_path ) {
    if ( $::ENV{HOME} ) {
      my $key_path = "$::ENV{HOME}/.ssh/id_rsa";
      $self->privatekey_path($key_path) if ( -f $key_path);
    }
  }

  $logger->debug(' - get_defaults: privatekey_path - '.$self->privatekey_path);

  if (! $self->publickey_path && $self->privatekey_path) {
    my $key_path = $self->privatekey_path.".pub";
    $self->publickey_path($key_path) if ( -f $key_path);
  }

  $logger->debug(' - get_defaults: publickey_path - '.$self->publickey_path);

  return 1;
}

sub connect {
  my $self    = shift;
  my $logger  = $self->logger;
  my $ssh2    = Net::SSH2->new(
    strict_host_key_checking=>'no',
    timeout => 1000 * 60 * 60 * 4 # default timeout 4 hours in milliseconds
  );
  $self->ssh2($ssh2);

  my $results = [];
  my $ip      = $self->ipaddress;

  $logger->debug("Connecting to $ip");

  my $connect_count=0;

  while (! $ssh2->connect($ip)) {
    die "Could not connect to $ip: $!" if ($connect_count > $self->connect_timeout);
    $connect_count++;
    $logger->trace("Trying to reconnect: connect_count: ".$connect_count." timeout: ".$self->connect_timeout);
    sleep 1;
  }

  $logger->debug("Connected successfully to $ip after $connect_count retries.");

  if ( $self->auth_type eq 'publickey' ) {
    $logger->debug(' - ssh2: using auth_publickey SSH_AUT_SOCK: '.($::ENV{SSH_AUTH_SOCK} || q{}));
    $ssh2->auth_publickey(
      $self->username,
      $self->publickey_path,
      $self->privatekey_path,
      $self->passphrase
    );
  } elsif ( $self->auth_type eq 'agent' ) {
    $logger->debug(' - ssh2: using auth_agent');
    $ssh2->auth_agent($self->username);
  } else {
    die "ssh auth_type not known!\n"
  }

  if ( ! $ssh2->auth_ok()  ) {

    $logger->info(
      "Using the following login data:\n" .
          "username   : " . ( $self->username || '' )         . "\n".
          "pubkey     : " . ( $self->publickey_path || '' )   . "\n".
          "privkey    : " . ( $self->privatekey_path || '' )  . "\n".
          "passphrase : " . ( $self->passphrase || '' )       . "\n"
    );
    my @err = $ssh2->error;
    die "Could not authenticate! $err[2]\n";
  }

  return $ssh2
}

sub exec_command {
  my $self = shift;
  my $cmd  = shift;
  my $ssh2 = $self->ssh2;

  my $chan = $ssh2->channel();
  $chan->ext_data('merge');
  for my $key (keys(%{$self->ENV})) {
    my $val = $self->ENV->{$key};
    $cmd = "export $key='$val'; $cmd";
  }

  $self->logger->info("Executing command: $cmd");
  $chan->exec($cmd);

  my $out = undef;
  my $buf = undef;
  while ($chan->read($buf,1024)) {
    $out .= $buf;
  }

  die "Command '$cmd' failed:\n\n$out\n" if $chan->exit_status;

  return $out;
}

1;

__END__

=head1 NAME

Kanku::Roles::SSH - A generic role for handling ssh connections using Net::SSH2

=head1 SYNOPSIS

  package Kanku::Handler::MySSHHandler;
  use Moose;
  with 'Kanku::Roles::SSH';

  sub execute {
    my ($self) = @_;

    ...

    $self->get_defaults();

    $self->connect();

    $self->exec_command("/bin/true");
  }

=head1 DESCRIPTION

This module contains a generic role for handling ssh connections in kanku using Net::SSH2

=head1 METHODS


=head2 get_defaults



=head2 connect



=head2 exec_command



=head1 ATTRIBUTES

  ipaddress         : IP address of host to connect to

  publickey_path    : path to public key file (optional)

  privatekey_path   : path to private key file

  passphrase        : password to use for private key

  username          : username used to login via ssh

  connect_timeout   : time to wait for successful connection to host

  job               : a Kanku::Job object (required for context)

  ssh2              : a Net::SSH2 object (usually created by role itself)

  auth_type	    : SEE Net::SSH2 for further information

=head1 CONTEXT

=head2 getters

  ipaddress

  publickey_path

  privatekey_path

=head2 setters

  NONE


=head1 DEFAULTS

  privatekey_path       : $HOME/.ssh/id_rsa

  publickey_path        : $HOME/.ssh/id_rsa.pub

  username              : root

  connect_timeout	: 300 (sec)

  auth_type		: agent

=cut
