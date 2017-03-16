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
package Kanku::Handler::Reboot;

use Moose;
use Kanku::Config;
use Kanku::Util::VM;

use Path::Class::File;
use Data::Dumper;
with 'Kanku::Roles::Handler';

has [qw/
      domain_name
      login_user
      login_pass
/] => (is => 'rw',isa=>'Str');
has [qw/wait_for_network wait_for_console/] => (is => 'rw',isa=>'Bool',lazy=>1,default=>1);
has [qw/timeout/] => (is => 'rw',isa=>'Int',lazy=>1,default=>600);

has gui_config => (
  is => 'ro',
  isa => 'ArrayRef',
  lazy => 1,
  default => sub {
      [
        {
          param => 'forward_port_list',
          type  => 'text',
          label => 'List of Forwarded Ports'
        },
      ];
  }
);
sub distributable { 1 };

sub prepare {
  my $self = shift;
  my $ctx  = $self->job()->context();

  $self->domain_name($ctx->{domain_name}) if ( ! $self->domain_name && $ctx->{domain_name});
  $self->login_user($ctx->{login_user})   if ( ! $self->login_user  && $ctx->{login_user});
  $self->login_pass($ctx->{login_pass})   if ( ! $self->login_pass  && $ctx->{login_pass});

  return {
    code    => 0,
    message => "Nothing todo"
  };
}

sub execute {
  my $self = shift;
  my $ctx  = $self->job()->context();

  my $cfg  = Kanku::Config->instance()->config();

  my $vm = Kanku::Util::VM->new(
      domain_name => $self->domain_name,
      login_user  => $self->login_user,
      login_pass  => $self->login_pass,
      job_id      => $self->job->id,
  );

  my $con = $vm->console();

  $con->login();

  $con->cmd(
      "reboot",
  );

  $con->logout();

  return {
    code    => 0,
    message => "Rebooted domain " . $self->domain_name ." successfully"
  };
}

1;

__END__

=head1 NAME

Kanku::Handler::Reboot

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::Reboot
    options:
      wait_for_console: 1
      wait_for_network: 1
      timeout:          600 
      ....

=head1 DESCRIPTION

This handler reboots the VM and optional waits for network and console.

=head1 OPTIONS


    wait_for_console : wait for console login
 
    wait_for_network : wait until network is up again

    timeout :          wait only <seconds>

=head1 CONTEXT

=head2 getters

 domain_name

=head2 setters

=head1 DEFAULTS

    wait_for_console : 1 (true)
 
    wait_for_network : 1 (true)

    timeout : 600 seconds

=cut

