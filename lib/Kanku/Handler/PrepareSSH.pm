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
package Kanku::Handler::PrepareSSH;

use Moose;
use Data::Dumper;
use Kanku::Util::VM::Console;
use Kanku::Config;
use Path::Class qw/file/;

with 'Kanku::Roles::Handler';

has ['public_keys', 'public_key_files' ] => (is=>'rw',isa=>'ArrayRef',lazy=>1,default=>sub { [] });
has [qw/domain_name login_user login_pass/] => (is=>'rw',isa=>'Str');

sub prepare {
  my $self = shift;

  my $ctx  = $self->job()->context();

  $self->domain_name($ctx->{domain_name}) if ( ! $self->domain_name && $ctx->{domain_name});
  $self->login_user($ctx->{login_user})   if ( ! $self->login_user  && $ctx->{login_user});
  $self->login_pass($ctx->{login_pass})   if ( ! $self->login_pass  && $ctx->{login_pass});

  my $file_counter = 0;

  if ( ! @{$self->public_keys} and ! @{$self->public_key_files} ) {
    my $key_file = "$ENV{HOME}/.ssh/id_rsa.pub";
    ( -f $key_file ) && push @{$self->public_key_files}, $key_file;

    $key_file = "$ENV{HOME}/.ssh/id_dsa.pub";
    ( -f $key_file ) && push @{$self->public_key_files}, $key_file;

  }

  if ( $self->public_key_files ) {
    foreach my $file ( @{ $self->public_key_files } ) {
      $file_counter++;
      my $fh = file($file);

      my $key = $fh->slurp();
      push(@{ $self->public_keys },$key);

    }
  }

  return {
    code    => 0,
    message => "Successfully finished prepare and loaded keys from $file_counter files"
  };
}

sub execute {
  my $self = shift;
  my $cfg   = Kanku::Config->instance()->config();
  my $con = Kanku::Util::VM::Console->new(
        domain_name => $self->domain_name,
        login_user => $self->login_user(),
        login_pass => $self->login_pass(),
        debug => $cfg->{'Kanku::Util::VM::Console'}->{debug} || 0
  );

  $con->init();
  $con->login();

  my $str="";
  map { $str .= "$_\n" } @{$self->public_keys()};

  $con->cmd('[ -d $HOME/.ssh ] || mkdir $HOME/.ssh');


  $con->cmd(
    "cat <<EOF >> \$HOME/.ssh/authorized_keys\n" .
    "$str\n" .
    "EOF\n"
  );

  $con->cmd('useradd -m kanku');
  $con->cmd('mkdir /home/kanku/.ssh');
  $con->cmd(
    "cat <<EOF >> /home/kanku/.ssh/authorized_keys\n" .
    "$str\n" .
    "EOF\n"
  );

  # TODO: make dynamically switchable between systemV and systemd
  $con->cmd("service sshd status || service sshd start");

  $con->cmd("chkconfig sshd on");


  $con->logout();

  return {
    code    => 0,
    message => "Successfully prepared " . $self->domain_name . " for ssh connections\n"
  }
}

1;
