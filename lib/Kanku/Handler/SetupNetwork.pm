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
package Kanku::Handler::SetupNetwork;

use Moose;
#use Data::Dumper;
use Kanku::Util::VM::Console;
use Kanku::Config;
#use Path::Class qw/file/;
use XML::XPath;
use Try::Tiny;
with 'Kanku::Roles::Handler';


has [qw/domain_name login_user login_pass/] => (is=>'rw',isa=>'Str',lazy=>1,default=>'');
has 'interfaces' => (is=>'rw',isa=>'HashRef');
has 'resolv' => (is=>'rw',isa=>'HashRef|Undef');
has '_mac_table' => (is=>'rw',isa=>'HashRef',lazy=>1,default=>sub {{}});

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
  my $self   = shift;
  my $cfg    = Kanku::Config->instance()->config();
  my $ctx    = $self->job()->context();
  my $logger = $self->logger;

  my $con = Kanku::Util::VM::Console->new(
        domain_name => $ctx->{domain_name},
        login_user => $self->login_user(),
        login_pass => $self->login_pass(),
        debug => $cfg->{'Kanku::Util::VM::Console'}->{debug} || 0
  );

  $con->init();
  $con->login();

  $self->_configure_interfaces($con);

  $self->_configure_resolver($con);

  $con->logout();

  return {
    code    => 0,
    message => "Successfully prepared " . $self->domain_name . " for ssh connections\n"
  }
}

sub _configure_resolver {
  my ($self,$con) = @_;

  return undef if (ref($self->resolv) ne 'HASH');

  my $config_str  = "";
  my $config_file = "/etc/resolv.conf";

  for my $key ( keys(%{$self->resolv}) ) {
    if ($key eq 'nameserver') {
      for my $dns ( @{$self->resolv()->{$key}} ) {
        $config_str .= "nameserver $dns\\n";
      }
    } else {
        $config_str .= "$key ".$self->resolv()->{$key}."\\n";
    }
  }

  my $resolv_conf = 'echo -en "'.$config_str. "\" > $config_file";

  $con->cmd($resolv_conf);

  return 1;

}

sub _configure_interfaces {
  my ($self,$con) = @_;
  $con->cmd("systemctl start wickedd");
  $con->cmd("systemctl enable wickedd");

  for my $interface ( keys(%{$self->interfaces}) ) {
    my $cfg         = $self->interfaces()->{$interface};
    my $config_str  = "";
    my $config_file = "/etc/sysconfig/network/ifcfg-$interface";
    for my $key (keys(%{$cfg})) {
      my $val = $cfg->{$key};
      $config_str .= "$key=\"$val\"\\n";
    }
    my $create_config     = 'echo -en "'.$config_str. "\" > $config_file";
    $self->logger->debug("Create config command:\n$create_config");
    $con->cmd($create_config);

    my $if_command        = "ifup $interface";   
    $self->logger->debug("ifup command:\n$if_command");
    $con->cmd($if_command);

    my $if_desc = $con->cmd("LANG=C ip link show $interface|grep 'link/ether'");
    my @out = split(/\n/,$if_desc->[0]);
    my $ether = $out[1];
    $ether =~ s/^\s*link\/ether ([\w:]+) brd ff:ff:ff:ff:ff:ff$/$1/;
    $self->_mac_table->{$ether} = $interface;
  }
}
1;

__END__

=head1 NAME

Kanku::Handler::SetupNetwork

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::SetupNetwork
    options:
      interfaces:
        eth0:
          BOOTPROTO: dhcp
        eth1:
          BOOTPROTO: static
          IPADDR: 192.168.122.22/24
      resolv:
        nameserver:
          - 192.168.122.1
        search: opensuse.org local.site
        domain: local.site
          

=head1 DESCRIPTION

This handler set`s up your Network configuration

=head1 OPTIONS

  interfaces - An array of strings which include your public ssh key

=head1 CONTEXT

=head1 DEFAULTS

=cut
