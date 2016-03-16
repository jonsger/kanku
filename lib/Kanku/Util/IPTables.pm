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
package Kanku::Util::IPTables;

use Moose;
use Data::Dumper;

with 'Kanku::Roles::Logger';

# For future use: we could also get the ip from the serial login
# but therefore we need the domain_name
has [qw/domain_name/] => (is=>'rw',isa=>'Str');
has [qw/guest_ipaddress host_ipaddress host_interface forward_port_list/] => (is=>'rw',isa=>'Str');
has forward_ports => (is=>'rw',isa=>'ArrayRef',default=>sub { [] });

has host_ipaddress => (
  is      =>'rw',
  isa     =>'Str',
  lazy    => 1,
  default =>sub {
    my $host_interface = $_[0]->host_interface;

    die "No host_interface given. Can not determine host_ipaddress" if (! $host_interface );

    my $cmd = "ip addr show " . $_[0]->host_interface;
    my @out = `$cmd`;

    for my $line (@out) {
      if ( $line =~ /^\s*inet\s+([0-9\.]*)(\/\d+)?\s.*/ ) {
        return $1
      }
    }
    return '';
  }
);

sub get_forwarded_ports_for_domain {
  my $self        = shift;
  my $domain_name = shift || $self->domain_name;
  my $result      = { };
  my $sudo        = $self->sudo();
  my $cmd         = "";

  die "No domain_name given. Cannot procceed\n" if (! $domain_name);

  my $re = '^DNAT.*\/\*\s*Kanku:host:'.$self->domain_name.'\s*\*\/';

  # prepare command to read PREROUTING chain
  $cmd = $sudo . "LANG=C iptables -t nat -L PREROUTING -n";

  # read PREROUTING rules
  my @prerouting_rules = `$cmd`;

  # check each PREROUTING rule if comment matches "/* Kanku:host:<domain_name> */"
  # and push line number to rules ARRAY
  for my $line (@prerouting_rules) {
      if ( $line =~ $re ) {
        chomp $line;
        # DNAT       tcp  --  0.0.0.0/0            10.160.67.4          tcp dpt:49002 /* Kanku:host:obs-server */ to:192.168.100.148:443
        my($target,$prot,$opt,$source,$destination,@opts) = split(/\s+/,$line);
        my ($host_port,$guest_port);
        for my $f (@opts) {
          if ($f =~ /^dpt:(\d+)$/ ) { $host_port = $1 }
          if ($f =~ /^to:[\d\.]+:(\d+)$/ ) { $guest_port = $1 }
        }
        $result->{$destination}->{$host_port} = $guest_port; 
      }
  }

  return $result;
}

sub get_active_rules_for_domain {
  my $self        = shift;
  my $domain_name = shift || $self->domain_name;
  my $result      = { filter => { FORWARD => [] }, nat => { PREROUTING => [] }  };
  my $sudo        = $self->sudo();
  my $cmd         = "";

  die "No domain_name given. Cannot procceed\n" if (! $domain_name);

  my $re = '^(\d+).*\/\*\s*Kanku:host:'.$self->domain_name.'\s*\*\/';

  # prepare command to read PREROUTING chain
  $cmd = $sudo . "LANG=C iptables -t nat -v -L PREROUTING -n --line-numbers";

  # read PREROUTING rules
  my @prerouting_rules = `$cmd`;

  # check each PREROUTING rule if comment matches "/* Kanku:host:<domain_name> */"
  # and push line number to rules ARRAY
  for my $line (@prerouting_rules) {
      push(@{$result->{nat}->{PREROUTING}},$1) if ( $line =~ $re );
  }

  # prepare command to read FORWARD chain
  $cmd = $sudo . "LANG=C iptables -v -L FORWARD -n --line-numbers";

  # read FORWARD rules
  my @forward_rules = `$cmd`;

  # check each FORWARD rule if comment matches "/* Kanku:host:<domain_name> */"
  # and push line number to rules ARRAY
  for my $line (@forward_rules) {
    push (@{$result->{filter}->{FORWARD}},$1) if ( $line =~ $re);
  }

  return $result;
}

sub cleanup_rules_for_domain {
  my $self        = shift;
  my $domain_name = shift || $self->domain_name;
  my $rules       = $self->get_active_rules_for_domain($domain_name);
  my $sudo        = $self->sudo();

  foreach my $table (keys(%{$rules})) {
    foreach my $chain (keys(%{$rules->{$table}})) {
      foreach my $line_number (reverse(@{$rules->{$table}->{$chain}})) {
        my $cmd = $sudo."iptables -t $table -D $chain $line_number";
        my @out = `$cmd 2>&1`;
        if ($?) {
          die "Error while deleting rules by executing command:\n\t$cmd\n\n@out"
        }
      }
    }
  }


};

sub add_forward_rules_for_domain {
  my $self          = shift;
  my %opts          = @_;
  my $start_port    = $opts{start_port};
  my $forward_rules = $opts{forward_rules};
  my $sudo          = $self->sudo();
  
  my $portlist      = { tcp =>[],udp=>[] };
  my $host_ip       = $self->host_ipaddress;
  my $guest_ip      = $self->guest_ipaddress;

  foreach my $rule (@$forward_rules) {
    if ($rule =~ /^(tcp|udp):(\d+)$/i ) {
      # ignore case for protocol TCP = tcp
      my $p = lc($1);
      push(@{$portlist->{$p}},$2);
    } else {
      die "Malicious rule detected '$rule'\n";
    }
  }
  # TODO: implement for udp also
  my $proto         = 'tcp';
  my @fw_ports = $self->_find_free_ports(
    $start_port,
    scalar(@{$portlist->{$proto}}),
    $proto
  );

  foreach my $guest_port ( @{$portlist->{$proto}} ) {
    my $host_port = shift(@fw_ports);

    my $comment = " -m comment --comment 'Kanku:host:".$self->domain_name."'";

    my @cmds = (
      "iptables -t nat -I PREROUTING 1 -d $host_ip -p $proto --dport $host_port -j DNAT --to $guest_ip:$guest_port $comment",
      "iptables -I FORWARD 1 -d $guest_ip/32 -p $proto -m state --state NEW -m tcp --dport $guest_port -j ACCEPT $comment"
    );

    for my $cmd (@cmds) {
      $self->logger->debug("Executing command '$cmd'");
      print "Executing command '$cmd'\n";
      my @out = `$sudo$cmd 2>&1`;
      if ($?) {
        die "Error while adding rule by executing command:\n\t$cmd\n\n@out\n";
      }
    }
  }

};

sub _find_free_ports {
  my $self        = shift;
  my $start_port  = shift;
  my $count       = shift;
  my $proto       = shift;
  # TODO: make usable for tcp and udp
  my $port2check  = $start_port;
  my @result      = ();
  my $used_ports  = $self->_used_ports;

  while ( $count && $port2check <= 65535 ) {
    if ( ! $used_ports->{$port2check} ) {
      push(@result,$port2check);
      $count--;
    }
    $port2check++;
  }
  
  return @result;
};

has _used_ports => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  default => sub {
    my $self    = shift;
    my $hostip  = $self->host_ipaddress;
    my $result  = {};
    my $cmd     = "";
    # TODO: make usable for tcp and udp

    # prepare command to read PREROUTING chain
    $cmd = $self->sudo . "LANG=C netstat -ltn";

    # read PREROUTING rules
    foreach my $line (`$cmd`) {
      chomp $line;
      my ($proto,$recvQ,$sendQ,$localAddress,$foreignAddress,$state) 
        = split(/\s+/,$line);
      if ( $localAddress =~ /(.*):(\d+)$/ ) {
        if ( 
              $1 eq '0.0.0.0' or
              $1 eq $hostip  
              # or $1 eq '::' use only ipv4 for now
        ) {
          $result->{$2} = 1;
        }
      } 
    }

    # prepare command to read PREROUTING chain
    $cmd = $self->sudo . "LANG=C iptables -t nat -L PREROUTING -n";
    
    # read PREROUTING rules
    for my $line ( `$cmd` ) {
      chomp $line;
      my($target,$prot,$opt,$source,$destination,@opts) = split(/\s+/,$line);
      next if ($target ne 'DNAT');
      if (
          $destination eq '0.0.0.0' or
          $destination eq $hostip
      ){
        map { if ( $_ =~ /^dpt:(\d+)/ ) { $result->{$1} = 1 } } @opts;
      }
    }
    return $result; 
  }
);

sub sudo {

  my $sudo      = "";
  
  # if EUID not root
  if ( $> != 0 ) {
    $sudo = "sudo -n ";
  }

  return $sudo;
}

__PACKAGE__->meta->make_immutable;

1;
