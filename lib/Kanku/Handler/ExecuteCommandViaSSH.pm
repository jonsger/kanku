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
use namespace::autoclean;

with 'Kanku::Roles::Handler';
with 'Kanku::Roles::SSH';

has commands => (is=>'rw', isa=>'ArrayRef', default => sub {[]});
has timeout => (is=>'rw',isa=>'Int',lazy=>1,default=>60*60*4);

has environment => (is=>'rw', isa=>'HashRef', default => sub {{}});
has context2env => (is=>'rw', isa=>'HashRef', default => sub {{}});

sub distributable { 1 }

sub execute {
  my $self    = shift;
  my $results = [];
  my $ssh2    = $self->connect();
  my $ip      = $self->ipaddress;
  my $ctx     = $self->job->context;

  $ssh2->timeout(1000*$self->timeout) if ($self->timeout);

  for my $env_var (keys(%{$self->context2env})) {
    # upper case environment variables are more shell
    # style
    my $n_env_var = uc($env_var);
    $self->ENV->{$n_env_var} = $ctx->{$env_var};
  }

  for my $env_var (keys(%{$self->environment})) {
    # upper case environment variables are more shell
    # style
    my $n_env_var = uc($env_var);
    $self->ENV->{$n_env_var} = $ctx->{$env_var};
  }

  foreach my $cmd ( @{$self->commands} ) {

      my $out = $self->exec_command($cmd);

      my @err = $ssh2->error();
      if ($err[0]) {
        $ssh2->disconnect();
        die "Error while executing command via ssh '$cmd': $err[2]";
      }

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

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Kanku::Handler::ExecuteCommandViaSSH

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::ExecuteCommandViaSSH
    options:
      context2env:
        ipaddress:
      environment:
        test: value
      publickey_path: /home/m0ses/.ssh/id_rsa.pub
      privatekey_path: /home/m0ses/.ssh/id_rsa
      passphrase: MySecret1234
      username: kanku
      commands:
        - rm /etc/shadow

=head1 DESCRIPTION

This handler will connect to the ipaddress stored in job context and excute the configured commands


=head1 OPTIONS

      commands          : array of commands to execute


SEE ALSO Kanku::Roles::SSH


=head1 CONTEXT

=head2 getters

SEE Kanku::Roles::SSH

=head2 setters

NONE

=head1 DEFAULTS

SEE Kanku::Roles::SSH

=cut
