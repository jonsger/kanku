package Kanku::Setup::LibVirt::Network;

use Moose;
use YAML qw/LoadFile/;
use Path::Class qw/file/;
use Net::IP;
use POSIX 'setsid';
use IPC::Run qw/run/;
use Kanku::LibVirt::HostList;

has cfg_file => (
  is      => 'rw',
  isa     => 'Str',
  lazy    => 1,
  default => "$FindBin::Bin/../etc/config.yml"
);

has cfg => (
	is => 'rw',
	isa => 'HashRef',
	lazy => 1,
	default => sub { LoadFile($_[0]->cfg_file) }
);

has logger => (
	is => 'rw',
	isa => 'Object',
	lazy => 1,
	default => sub { Log::Log4perl->get_logger() }
);


has dnsmasq_cfg_file => (
	is => 'rw',
	isa => 'Object',
	lazy => 1,
	default => sub { file('/var/lib/libvirt/dnsmasq/',$_[0]->cfg->{'Kanku::LibVirt::Network::OpenVSwitch'}->{name}.".conf") }
);

has dnsmasq_pid_file => (
	is => 'rw',
	isa => 'Object',
	lazy => 1,
	default => sub { file('/var/run/libvirt/network/',$_[0]->cfg->{libvirt_network}->{name}.".pid") }
);

sub prepare_ovs {
	my $self = shift;
	my $cfg  = $self->cfg;
	my $ncfg = $self->cfg->{'Kanku::LibVirt::Network::OpenVSwitch'};
	my $br   = $ncfg->{bridge};
	my $vlan = $ncfg->{vlan};

    # Standard mtu size is 1500 bytes
    # VXLAN header is 50 bytes
    # 1500 - 50 = 1450
    my $mtu  = $ncfg->{mtu} || '1450';
    my $lvhl = Kanku::LibVirt::HostList->new();
	my $out;
	my $fh;

	system('ovs-vsctl','br-exists',$br);

	if ( $? > 0 ) {
		$self->logger->info("Creating bridge $br");
		system('ovs-vsctl','add-br',$br);
	} else {
		$self->logger->info("Bridge $br already exists");
	}

	my $port_counter = 0;
	for my $remote ( @{$lvhl->get_remote_ips} ) {
		my $port = "$vlan-$port_counter";
		system('ovs-vsctl','port-to-br',$port);
		if ( $? > 0 ) {

				$self->logger->info("Adding port $port on bridge $br");
				system('ovs-vsctl','add-port',$br,$port);
				system('ovs-vsctl','set','Interface',$port,'type=vxlan',"options:remote_ip=$remote");
		} else {
			$self->logger->info("Port $port already exists on bridge $br");
		}
	}

        # Set ip address for bridge interface
	my $ip = new Net::IP ($ncfg->{network});

	my @cmd = ("ifconfig",$br,$ncfg->{host_ip},'netmask',$ip->mask);

	$self->logger->debug("Configuring interface with command '@cmd'");

	system(@cmd);

	# Set MTU for bridge interface
	@cmd=(qw/ip link set mtu/, $mtu, $br);

	$self->logger->debug("Configuring interface with command '@cmd'");

	system(@cmd);
}

sub bridge_down {
	my $self = shift;
	my $ncfg = $self->cfg->{'Kanku::LibVirt::Network::OpenVSwitch'};
	my $br   = $ncfg->{bridge};

	$self->logger->info("Deleting bridge $br");

	system('ovs-vsctl','del-br',$br);

	if ( $? > 0 ) {
		$self->logger->error("Deleting bridge $br failed");
	}
}

sub prepare_dns {
	my $self       = shift;
	my $cfg        = $self->cfg;
	my $net_cfg    = $cfg->{'Kanku::LibVirt::Network::OpenVSwitch'};

	return if (! $net_cfg->{start_dhcp} );

	my $pid_file = $self->dnsmasq_pid_file->stringify ;

	my $dns_config = <<EOF
##WARNING:  THIS IS AN AUTO-GENERATED FILE. CHANGES TO IT ARE LIKELY TO BE
##OVERWRITTEN AND LOST.  Changes to this configuration should be made using:
##    virsh net-edit default
## or other application using the libvirt API.
##
## dnsmasq conf file created by kanku
strict-order
pid-file=$pid_file
except-interface=lo
bind-dynamic
interface=$net_cfg->{bridge}
dhcp-range=$net_cfg->{dhcp_range}
dhcp-no-override
dhcp-lease-max=253
dhcp-hostsfile=/var/lib/libvirt/dnsmasq/$net_cfg->{name}.hostsfile
addn-hosts=/var/lib/libvirt/dnsmasq/$net_cfg->{name}.addnhosts
EOF
;
	$self->dnsmasq_cfg_file->spew($dns_config);

}

sub start_dhcp {
	my $self       = shift;
	my $cfg        = $self->cfg;
	my $net_cfg    = $cfg->{'Kanku::LibVirt::Network::OpenVSwitch'};
	return if (! $net_cfg->{start_dhcp} );

	$ENV{VIR_BRIDGE_NAME} = $net_cfg->{bridge};

	defined (my $kid = fork) or die "Cannot fork: $!\n";
	if ($kid) {
		# Parent runs this block
		$self->logger->debug("Setting iptables commands");
		system("iptables","-I","INPUT","1","-p","tcp","-i",$net_cfg->{bridge},"--dport","67","-j","ACCEPT");
		system("iptables","-I","INPUT","1","-p","udp","-i",$net_cfg->{bridge},"--dport","67","-j","ACCEPT");
		system("iptables","-I","INPUT","1","-p","tcp","-i",$net_cfg->{bridge},"--dport","53","-j","ACCEPT");
		system("iptables","-I","INPUT","1","-p","udp","-i",$net_cfg->{bridge},"--dport","53","-j","ACCEPT");
		system("iptables","-I","OUTPUT","1","-p","udp","-o",$net_cfg->{bridge},"--dport","68","-j","ACCEPT");

	}
	else {
		# Child runs this block
		setsid or die "Can't start a new session: $!";
		my @cmd = ('/usr/sbin/dnsmasq',"--conf-file=/var/lib/libvirt/dnsmasq/$net_cfg->{name}.conf","--leasefile-ro","--dhcp-script=/usr/lib64/libvirt/libvirt_leaseshelper");
		$self->logger->debug("@cmd");
		system(@cmd);
		exit 0;
	}


}

sub configure_iptables {
	my $self	= shift;
	my $ncfg	= $self->cfg->{'Kanku::LibVirt::Network::OpenVSwitch'};
	$self->logger->debug("Starting configuration of iptables");

	return if (! $ncfg->{is_gateway} );

	if ( ! $ncfg->{network} ) {
		$self->logger->error("No netmask configured");
		return 1;
	}

	my $ip = new Net::IP ($ncfg->{network});
	if ( ! $ip ) {
		$self->logger->debug("Bad network configuration");
		return 0;
	}

	my $prefix = $ip->prefix;

	$self->logger->debug("prefix: $prefix");

	my $rules = [
		["-I","FORWARD","1","-i",$ncfg->{bridge},"-j","REJECT","--reject-with","icmp-port-unreachable"],
		["-I","FORWARD","1","-o",$ncfg->{bridge},"-j","REJECT","--reject-with","icmp-port-unreachable"],
		["-I","FORWARD","1","-i",$ncfg->{bridge},"-o","$ncfg->{bridge}","-j","ACCEPT"],
		["-I","FORWARD","1","-s",$prefix,"-i",$ncfg->{bridge},"-j","ACCEPT"],
		["-I","FORWARD","1","-d",$prefix,"-o",$ncfg->{bridge},"-m","conntrack","--ctstate","RELATED,ESTABLISHED","-j","ACCEPT"],
		["-t","nat","-I","POSTROUTING","-s",$prefix,"!","-d",$prefix,"-j","MASQUERADE"],
		["-t","nat","-I","POSTROUTING","-s",$prefix,"!","-d",$prefix,"-p","udp","-j","MASQUERADE","--to-ports","1024-65535"],
		["-t","nat","-I","POSTROUTING","-s",$prefix,"!","-d",$prefix,"-p","tcp","-j","MASQUERADE","--to-ports","1024-65535"],
		["-t","nat","-I","POSTROUTING","-s",$prefix,"-d","255.255.255.255/32","-j","RETURN"],
		["-t","nat","-I","POSTROUTING","-s",$prefix,"-d","224.0.0.0/24","-j","RETURN"],
	];

	for my $rule (@{$rules}) {
		$self->logger->debug("Adding rule: iptables @{$rule}");
		my @ipt;
		my @cmd = ("iptables",@{$rule});
		run \@cmd, \$ipt[0],\$ipt[1],\$ipt[2];
		if ( $? ) {
			$self->logger->error("Failed while executing '@cmd'");
			$self->logger->error("Error: $ipt[2]");
		} 
	}

	return 0;
}

sub kill_dhcp {
	my $self = shift;

	return if ( ! -f $self->dnsmasq_pid_file );

	my $pid = $self->dnsmasq_pid_file->slurp;
	$self->logger->debug("Killing dnsmasq with pid $pid");

	kill 'TERM', $pid;
}

sub cleanup_iptables {
	my $self = shift;
	my $ncfg = $self->cfg->{'Kanku::LibVirt::Network::OpenVSwitch'};
	my $rules_to_delete = {
		'filter' => {
			'INPUT' 	=> [],
			'OUTPUT'	=> [],
			'FORWARD'	=> [],
		},
		'nat' => {
			'POSTROUTING'	=> [],
		}
	};

	$self->logger->info("Cleaning iptables rules");
	my @cmdout;
	@cmdout = `iptables -L OUTPUT -n -v --line-numbers`;

	for my $line (@cmdout ) {
		my @args = split(/\s+/,$line,10);
		# check if outgoing interface matches
		$self->logger->debug("Values: $args[7] eq $ncfg->{bridge}");
		if ( $args[7] eq $ncfg->{bridge} ) {
			# remember line numbers
			push(@{$rules_to_delete->{filter}->{OUTPUT}},$args[0]);
		}
	}

	@cmdout = `iptables -L INPUT -n -v --line-numbers`;

	for my $line (@cmdout ) {
		my @args = split(/\s+/,$line,10);
		# check if incomming interface matches
		$self->logger->debug("Values: $args[6] eq $ncfg->{bridge}");
		if ( $args[6] eq $ncfg->{bridge} ) {
			# remember line numbers
			push(@{$rules_to_delete->{filter}->{INPUT}},$args[0]);
		}
	}


	my $ip = new Net::IP ($ncfg->{network});
	if ( ! $ip ) {
		$self->logger->debug("Bad network configuration");
		return 0;
	}

	my $prefix = $ip->prefix;
	my $netreg = qr/!?\Q$prefix\E/;
	my $brreg  = $ncfg->{bridge};

	@cmdout = `iptables -L FORWARD -n -v --line-numbers`;

	for my $line (@cmdout ) {
		my @args = split(/\s+/,$line,11);
		# check if incomming interface matches
		$self->logger->debug("Values: $netreg -> $args[8] / $args[9]");
		if ( 
			$args[8] =~ $netreg 
			|| $args[9] =~ $netreg
			|| $args[7] =~ /$brreg/
			|| $args[6] =~ /$brreg/
		) {
			# remember line numbers
			push(@{$rules_to_delete->{filter}->{FORWARD}},$args[0]);
		}
	}

	@cmdout = `iptables -t nat -L POSTROUTING -n -v --line-numbers`;

	for my $line (@cmdout ) {
		my @args = split(/\s+/,$line,11);
		# check if incomming interface matches
		$self->logger->debug("Values: $netreg -> $args[8] / $args[9]");
		if ( 
			$args[8] =~ $netreg 
			|| $args[9] =~ $netreg
			|| $args[7] =~ /$brreg/
			|| $args[6] =~ /$brreg/
		) {
			# remember line numbers
			$self->logger->debug("Adding line $args[0]");
			push(@{$rules_to_delete->{nat}->{POSTROUTING}},$args[0]);
		}
	}

	for my $table (keys(%{$rules_to_delete})) {
		for my $chain (keys(%{$rules_to_delete->{$table}}) ) {
			# cleanup from the highest number to keep numbers consistent
			$self->logger->debug("Cleaning chain $chain in table $table");
			for my $number ( reverse @{$rules_to_delete->{$table}->{$chain}} ) {
				$self->logger->debug("... deleting from chain $chain rule number $number");
				# security not relevant here because we have trusted input
				# from 'iptables -L ...'
				my @cmd_output = `iptables -t $table -D $chain $number 2>&1`;
				if ( $? ) {
					$self->logger->error("An error occured while deleting rule $number from chain $chain : @cmd_output");
				}
			}

		}
	}

}
1;

