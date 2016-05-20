# Copyright (c) 2015 SUSE LLC
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
package Kanku::Util::VM;

use Moose;

use Sys::Virt;
use Sys::Virt::Stream;
use Expect;
use YAML;
use Template;
use Cwd;
use Net::IP;
use Kanku::Util::VM::Console;
use Data::Dumper;
use XML::XPath;
use Try::Tiny;

has [qw/
      image_file    domain_name   vcpu        memory
      images_dir    login_user    login_pass  template_file
      ipaddress     uri
      management_interface        management_network
    / ]  => ( is=>'rw', isa => 'Str');

has _console      => ( is=>'rw', isa => 'Object' );
has use_9p        => ( is=>'rw', isa => 'Bool' );

has '+uri'        => ( default => 'qemu:///system');
#has "+ipaddress"  => ( lazy => 1, default => sub { $self->get_ipaddress } );

has dom => (
  is => 'rw',
  isa => 'Object|Undef',
  lazy => 1,
  default => sub {
    my $self = shift;
	die "Could not find domain_name\n" if ! $self->domain_name;
    my $vmm = Sys::Virt->new(uri => $self->uri);
    for my $dom ( $vmm->list_all_domains() ) {
      if ( $self->domain_name eq $dom->get_name ) {
        return $dom
      }
    }
    return undef;
  }
);

has console => (
  is => 'rw',
  isa => 'Object',
  lazy => 1,
  default => sub {
      my $self = shift;
      my $con = Kanku::Util::VM::Console->new(
        domain_name => $self->domain_name,
        # log_file    => $self->app_base_path->stringify . '/var/log/vm_console/console.log',
        login_user  => $self->login_user,
        login_pass  => $self->login_pass,
      );

      $con->init();

      return $con
  }
);
has logger => (
  is => 'rw',
  isa => 'Object',
  lazy => 1,
  default => sub { Log::Log4perl->get_logger(); }
);


sub process_template {
  my $self = shift;

  # some useful options (see below for full list)
  my $template_path = Kanku::Config->instance->app_base_path->stringify . '/etc/templates/';
  my $config = {
    INCLUDE_PATH => $template_path,
    INTERPOLATE  => 1,               # expand "$var" in plain text
    POST_CHOMP   => 1,               # cleanup whitespace
    #PRE_PROCESS  => 'header',        # prefix each template
    #EVAL_PERL    => 1,               # evaluate Perl code blocks
    #RELATIVE     => 1
  };

  # create Template object
  my $template  = Template->new($config);

  # define template variables for replacement
  my $vars = {
    domain => {
      vcpu          => $self->vcpu        ,
      memory        => $self->memory      ,
      domain_name   => $self->domain_name ,
      images_dir    => $self->images_dir  ,
      image_file    => $self->image_file  ,
      hostshare     => ""
    }
  };

  $self->logger->debug(" --- use_9p:".$self->use_9p);
  if ( $self->use_9p ) {


    $vars->{domain}->{hostshare} = "
    <filesystem type='mount' accessmode='passthrough'>
      <source dir='".getcwd()."'/>
      <target dir='kankushare'/>
      <alias name='fs0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
    </filesystem>
";

  }

  # specify input filename, or file handle, text reference, etc.
  my $input;

  if ( $self->template_file ) {
    $input = $self->template_file
  } else {
    $input = $self->domain_name . '.tt2';
  }

  if ( ! -f $template_path.$input ) {
    my $template;
    while ( <DATA> ) { $template .= $_ };
    $input = \$template;
  }

  my $output = '';
  # process input template, substituting variables
  $template->process($input, $vars, \$output)
               || die $template->error()->as_string();

  return $output;

}

sub create_domain {
  my $self  = shift;
  my $xml   = $self->process_template();
  my $vmm   = undef;
  my $dom   = undef;

  # connect to libvirtd
  eval {
    $vmm = Sys::Virt->new(uri => 'qemu:///system');
  };

  die $@->message . "\n" if ($@);

  # create domain
  eval {
    $dom = $vmm->define_domain($xml);
    $dom->create;
  };

  die $@->message . "\n" if ($@);

  # return domain
  return $dom
}

sub get_ipaddress {
  my $self        = shift;
  my %opts        = @_;

  if ( $opts{management_network} ) {
    $self->management_network($opts{management_network});
  }

  if ( $opts{management_interface} ) {
    $self->management_interface($opts{management_interface})
  }

  if ( ( $opts{mode} || '' ) eq 'console' ) {

    return $self->_get_ip_from_console();

  } else {

    return $self->_get_ip_from_dhcp();

  }


}

sub remove_domain {
  my $self    = shift;
  my $dom     = $self->dom;

  try {
    # Shutdown domain immediately (poweroff)
    my ($dom_state, $reason) = $dom->get_state;
    if ($dom_state == Sys::Virt::Domain::STATE_RUNNING ) {
      $self->logger->debug("Trying to destroy domain");
      $dom->destroy();
    }

    my @snapshots = $dom->list_snapshots();
    for my $snap (@snapshots) {
      $snap->delete;
    }

    $dom->undefine(
      Sys::Virt::Domain::UNDEFINE_MANAGED_SAVE
    );

  } catch {
    die $_->message ."\n";
  };
}

sub create_snapshot {
  my $self    = shift;
  my $dom     = $self->dom;

  my $disks   = $self->get_disk_list;


}

sub get_disk_list {
  my $self    	= shift;
  my %opts    	= @_;
  my $result    = [];
  my $dom     	= $self->dom;
  my $xml     	= $opts{xml} || $dom->get_xml_description;

  my $xp        = XML::XPath->new( xml => $xml );
  my $xp_result = $xp->find("//domain/devices/disk");

  foreach my $node ($xp_result->get_nodelist) {
	my $disk = {};
	my $sources = $xp->find('./source',$node);
	foreach my $source ( $sources->get_nodelist ) {
	  $disk->{source_file} = $source->getAttribute("file");
	}
	my $targets = $xp->find('./target',$node);
	foreach my $target ( $targets->get_nodelist ) {
	  $disk->{target_device} = $target->getAttribute("dev");
	}
	push(@{$result},$disk);
  }

  return $result;
}

sub _get_ip_from_console {
  my $self        = shift;
  my $interface   = $self->management_interface();


  my $ip_address  = undef;
  my $con  = $self->console;

  if (! $con->user_is_logged_in ) {
    $con->login;
  }

  my $result = $con->cmd("LANG=C ip addr show $interface");

  map { if ( $_ =~ /^\s+inet\s+([0-9\.]+)\// ) { $ip_address = $1 } } split(/\n/,$result->[0]);

  $self->ipaddress($ip_address);

  return $ip_address;
}

sub _get_ip_from_dhcp {
  my $self          = shift;
  my $domain_name   = $self->domain_name;
  my $dom           = $self->dom;
  my @nics          = $dom->get_interface_addresses(
                          Sys::Virt::Domain::INTERFACE_ADDRESSES_SRC_LEASE
                      );

  if (! $self->management_network() ) {
    return $self->ipaddress($nics[0]->{addrs}->[0]->{addr});
  }

  my $mgmt_range    = Net::IP->new($self->management_network());

  for my $nic (@nics) {
    for my $addr (@{$nic->{addrs}}) {
      my $ip = Net::IP->new($addr->{addr});
      if ( $ip->overlaps($mgmt_range) == $IP_A_IN_B_OVERLAP ) {
        return $self->ipaddress($ip->ip);
      }
    }
  }

  return undef;
}

__PACKAGE__->meta->make_immutable;

1;

__DATA__
<domain type='kvm'>
  <name>[% domain.domain_name %]</name>
  <memory unit='KiB'>[% domain.memory %]</memory>
  <currentMemory unit='KiB'>[% domain.memory %]</currentMemory>
  <vcpu placement='static'>[% domain.vcpu %]</vcpu>
  <os>
    <type arch='x86_64' machine='pc-i440fx-2.3'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <pae/>
  </features>
  <cpu mode='host-model'>
    <model fallback='allow'>qemu64</model>
  </cpu>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-kvm</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='[% domain.image_file %]'/>
      <target dev='hda' bus='ide'/>
      <address type='drive' controller='0' bus='0' target='0' unit='0'/>
    </disk>
    <controller type='usb' index='0'>
      <alias name='usb'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x2'/>
    </controller>
    <controller type='pci' index='0' model='pci-root'>
      <alias name='pci.0'/>
    </controller>
    <controller type='sata' index='0'>
      <alias name='sata0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </controller>
    <interface type='network'>
      <source network='default' bridge='virbr0'/>
      <model type='virtio'/>
      <alias name='net0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
    </interface>
    <serial type='pty'>
      <source path='/dev/pts/8'/>
      <target port='0'/>
      <alias name='serial0'/>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
      <alias name='serial0'/>
    </console>
    <input type='mouse' bus='ps2'/>
    <input type='keyboard' bus='ps2'/>
    <graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'>
      <listen type='address' address='127.0.0.1'/>
    </graphics>
    <video>
      <model type='cirrus' vram='16384' heads='1'/>
      <alias name='video0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </video>
    <memballoon model='virtio'>
      <alias name='balloon0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
    </memballoon>

[% domain.hostshare %]

  </devices>
</domain>
