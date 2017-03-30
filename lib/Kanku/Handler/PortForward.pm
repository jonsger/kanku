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
package Kanku::Handler::PortForward;

use Moose;
use Data::Dumper;

with 'Kanku::Roles::Handler';
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
      if ( $line =~ /^\s*inet\s+([0-9\.]*)\/.*/ ) {
        return $1
      }
    }
    return '';
  }
);

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



sub prepare {
  my $self = shift;

  if ( ! $self->guest_ipaddress ) {
    $self->guest_ipaddress($self->job()->context()->{ipaddress});
  }

  if ($self->forward_port_list ) {
    my @ports = split(',',$self->forward_port_list);
    $self->forward_ports(\@ports);
  }

  if ($self->job()->context()->{domain_name} ) {
    $self->domain_name(
      $self->job()->context()->{domain_name}
    );
  }


  return {
    code => 0,
    message => "Preparation successful"
  };
}

sub execute {
  my $self      = shift;
  my $results   = [];
  my $guest_ip  = $self->guest_ipaddress;
  my $host_ip   = $self->host_ipaddress;

  my $sudo      = "";

  die "Host IP not found\n" if (! $host_ip);
  die "Guest IP not found\n" if ( ! $guest_ip );

  # if EUID not root
  if ( $> != 0 ) {
    $sudo = "sudo -n";
  }

  for my $ports ( @{ $self->forward_ports } ) {
    my ($proto,$host_port,$guest_port);

    # we do not split here to avoid malicious input
    if ( $ports =~ /^\s*(udp|tcp):(\d+):(\d+)\s*$/ ) {
      ($proto,$host_port,$guest_port) = ($1,$2,$3);
    } else {
      die "malicious input detected '$ports'\n";
    }

    my $old_guest_ip = undef;
    my $rule_number_prerouting = 0;
    my $rule_number_forward = 0;
    # prepare cleanup PREROUTING
    my @prerouting_rules = `$sudo LANG=C iptables -t nat -v -L PREROUTING -n --line-numbers`;

    for my $line (@prerouting_rules) {
      # 8   480 DNAT       tcp  --  *      *       0.0.0.0/0            10.160.67.4          tcp dpt:5443 to:192.168.100.182:443
      if ($line =~ /^(\d+).*dpt:$host_port\s+to:([0-9\.]*):$guest_port/ ) {
        $rule_number_prerouting = $1;
        $old_guest_ip           = $2;
        $self->logger->debug("Found in PREROUTING in line $1 old_guest_ip: $2");
            $self->logger->debug($line);
        last;
      }
    }

    # prepare cleanup FORWARD
    if ( $old_guest_ip ) {
        my @forward_rules = `$sudo LANG=C iptables -v -L FORWARD -n --line-numbers`;
        for my $line (@forward_rules) {
          # 2        0     0 ACCEPT     tcp  --  *      *       0.0.0.0/0            192.168.100.182      state NEW tcp dpt:22
          #
          if ($line =~ /^(\d+).*ACCEPT.*$old_guest_ip.*state NEW $proto dpt:$guest_port/ ) {
            $self->logger->debug("Found in FORWARD in line $1");
            $self->logger->debug($line);
            $rule_number_forward = $1;
            last;
          }
        }
    }

    my $comment = " -m comment --comment 'Kanku:host:".$self->domain_name."'";

    my @cmds = (
      "iptables -t nat -I PREROUTING 1 -d $host_ip -p $proto --dport $host_port -j DNAT --to $guest_ip:$guest_port $comment",
      "iptables -I FORWARD 1 -d $guest_ip/32 -p $proto -m state --state NEW -m tcp --dport $guest_port -j ACCEPT $comment"
    );

    if ( $rule_number_forward) {
      unshift(@cmds,"iptables -D FORWARD $rule_number_forward");
    }

    if ( $rule_number_prerouting ) {
      unshift(@cmds,"iptables -t nat -D PREROUTING $rule_number_prerouting");
    }

    for my $cmd (@cmds) {
      $self->logger->debug("Executing command '$cmd'");
      my @out = `$sudo $cmd 2>&1`;
      if ($?) {
        die "Error while executing command '$cmd'\n@out\n";
      }
    }

  }


  return {
    code        => 0,
    message     => "All port forwarding rules for $guest_ip added successfully",
    subresults  => $results
  };
}

1;
