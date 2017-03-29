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
use Kanku::Util::VM::Image;
use Sys::Virt::StorageVol;
use Data::Dumper;
use XML::XPath;
use Try::Tiny;

has [qw/
      image_file    domain_name   vcpu        memory
      images_dir    login_user    login_pass  template_file
      ipaddress     uri           disks_xml
      management_interface        management_network
      network_name  network_bridge
    / ]  => ( is=>'rw', isa => 'Str');

has job_id        => ( is => 'rw', isa => 'Int' );
has root_disk     => ( is => 'rw', isa => 'Object' );
has use_9p        => ( is => 'rw', isa => 'Bool' );
has empty_disks   => ( is => 'rw', isa => 'ArrayRef', default => sub {[]});
has '+uri'        => ( default => 'qemu:///system');
#has "+ipaddress"  => ( lazy => 1, default => sub { $self->get_ipaddress } );

has vmm => (
  is => 'rw',
  isa => 'Object|Undef',
  lazy => 1,
  default => sub {
    my $self = shift;
    try {
      return Sys::Virt->new(uri => $self->uri);
    }
    catch {
      my ($e) = @_;
      if ( ref($e) eq 'Sys::Virt::Error' ){
        die $e->stringify();
      } else {
        die $e
      }
    };
  }
);

has dom => (
  is => 'rw',
  isa => 'Object|Undef',
  lazy => 1,
  default => sub {
    my $self = shift;
    die "Could not find domain_name\n" if ! $self->domain_name;
    my $dom_o = undef;
    try {
      my $vmm = $self->vmm();
      for my $dom ( $vmm->list_all_domains() ) {
        if ( $self->domain_name eq $dom->get_name ) {
          $self->logger->debug("Found domain with name ".$self->domain_name);
          $dom_o = $dom;
          return $dom;
        }
      }
    }
    catch {
      my ($e) = @_;
      if ( ref($e) eq 'Sys::Virt::Error' ){
        die $e->stringify();
      } else {
        die $e
      }
    };
    return $dom_o;
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
        login_user  => $self->login_user,
        login_pass  => $self->login_pass,
        job_id      => $self->job_id
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

has wait_for_network => (
  is => 'rw',
  isa => 'Int',
  lazy => 1,
  default => 120
);

has network_name => (
  is      => 'rw',
  isa     => 'Str',
  lazy    => 1,
  default => 'default'
);

sub process_template {
  my ($self,$disk_xml) = @_;

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
      vcpu            => $self->vcpu        ,
      memory          => $self->memory      ,
      domain_name     => $self->domain_name ,
      images_dir      => $self->images_dir  ,
      image_file      => $self->image_file  ,
      network_name    => $self->network_name  ,
      network_bridge  => $self->network_bridge  ,
      hostshare       => "",
      disk_xml        => $disk_xml
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
    $self->logger->warn("Template file $template_path$input not found");
    $self->logger->warn("Using internal template");
    my $template;
    my $start = tell DATA;
    while ( <DATA> ) { $template .= $_ };
    seek DATA, $start,0;
    $input = \$template;
    $self->logger->trace("template:\n${$input}");
  } else {
    $self->logger->info("Using template file '$template_path$input'");
  }
  my $output = '';
  # process input template, substituting variables
  $template->process($input, $vars, \$output)
               || die $template->error()->as_string();

  return $output;

}

sub _generate_disk_xml {
    my ($self,$unit,$file,$format) = @_;

    # ASCII 97 = a + 0
    my $drive = "hd" . chr(97+$unit);
    my $source = '';

    return "
    <disk type='file' device='disk'>
      <driver name='qemu' type='".$format."'/>
      <source file='$file'/>
      <target dev='$drive' bus='ide'/>
      <address type='drive' controller='0' bus='0' target='0' unit='$unit'/>
    </disk>
";

}

sub create_empty_disks  {
  my ($self) = @_;
  my $unit   = 1;
  my $xml    = "";

  for my $disk (@{$self->empty_disks}) {
    my $img = Kanku::Util::VM::Image->new(
                vol_name  => $self->domain_name ."-".$disk->{name}.".qcow2",
                size      => $disk->{size},
                vmm       => $self->vmm,
                pool_name => $disk->{pool}   || 'default',
		format    => $disk->{format} || 'qcow2'
              );
    my $vol = $img->create_volume();

    $xml .= $self->_generate_disk_xml($unit,$vol->get_path,$img->format);
    $unit++;
  }

  return $xml;
}

sub create_domain {
  my $self  = shift;

  my $disk_xml = $self->_generate_disk_xml(0,$self->image_file,$self->root_disk->format);

  $disk_xml .= $self->create_empty_disks();

  my $xml   = $self->process_template($disk_xml);
  my $vmm;
  my $dom;

  $self->logger->trace("disk_xml:\n$xml");

  # connect to libvirtd
  try {
    $vmm = Sys::Virt->new(uri => 'qemu:///system');
  }
  catch {
    my ($e) = @_;
    if ( ref($e) eq 'Sys::Virt::Error' ){
      die $e->stringify();
    } else {
      die $e
    }
  };

  die $@->message . "\n" if ($@);

  # create domain
  try {
    $dom = $vmm->define_domain($xml);
    $dom->create;
  }
  catch {
    my ($e) = @_;
    if ( ref($e) eq 'Sys::Virt::Error' ){
      die $e->stringify();
    } else {
      die $e
    }
  };

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
    try {
      return $self->_get_ip_from_dhcp();
    } catch {
      return $self->_get_ip_from_console();
    }

  }


}

sub remove_domain {
  my $self    = shift;
  my $dom     = $self->dom;

  $self->logger->debug("Trying to remove domain '".$self->domain_name."'");

  if ( ! $dom ) {
    $self->logger->info("Domain with name '".$self->domain_name."' not found");
    return 0;
  }


  try {
    # Shutdown domain immediately (poweroff)
    my ($dom_state, $reason) = $dom->get_state;
    if ($dom_state == Sys::Virt::Domain::STATE_RUNNING ) {
      $self->logger->debug("Trying to destroy domain '".$dom->get_name."'");
      $dom->destroy();
    }

    $self->logger->debug("Checking for snapshots of domain '".$dom->get_name."'");
    my @snapshots = $dom->list_snapshots();
    for my $snap (@snapshots) {
      $snap->delete;
    }

    $self->logger->debug("Undefine domain '".$dom->get_name."'");
    $dom->undefine(
      Sys::Virt::Domain::UNDEFINE_MANAGED_SAVE
    );

    $self->logger->debug("Successfully undefined domain '".$dom->get_name."'");
  } catch {
    die $_->message ."\n";
  };

  return 0;
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
  my $interface   = $self->management_interface() || 'eth0';


  my $con  = $self->console;

  if (! $con->user_is_logged_in ) {
    $con->login;
  }

  my $result = $con->cmd("LANG=C ip addr show $interface");

  my $wait = $self->wait_for_network;

  while ( $wait > 0) {

    my $ipaddress  = undef;

    map { if ( $_ =~ /^\s+inet\s+([0-9\.]+)\// ) { $ipaddress = $1 } } split(/\n/,$result->[0]);

    if ($ipaddress) {
      $self->ipaddress($ipaddress);
      last;
    } else {
      $self->logger->debug("Could not get ip address form interface $interface.");
      $self->logger->debug("Waiting another $wait seconds for network to come up");
      $wait--;
      sleep 1;
    }
  }

  $con->logout;

  if (! $self->ipaddress) {
    die "Could not get ip address for interface $interface within "
      . $self->wait_for_network." seconds.";
  }

  return $self->ipaddress();
}

sub _get_ip_from_dhcp {
  my $self          = shift;
  my $domain_name   = $self->domain_name;
  my $dom           = $self->dom;
  my @nics          = $dom->get_interface_addresses(
                          Sys::Virt::Domain::INTERFACE_ADDRESSES_SRC_LEASE
                      );
  my $ipaddress;


  my $wait = $self->wait_for_network;

  while ( $wait > 0) {

      if (! $self->management_network() ) {
        $ipaddress = $nics[0]->{addrs}->[0]->{addr};
      } else {
          my $mgmt_range    = Net::IP->new($self->management_network());

          for my $nic (@nics) {
            for my $addr (@{$nic->{addrs}}) {
              my $ip = Net::IP->new($addr->{addr});
              if ( $ip->overlaps($mgmt_range) == $IP_A_IN_B_OVERLAP ) {
                $ipaddress = $ip->ip;
              }
            }
          }
      }
      last if $ipaddress;

      $wait--;

      sleep 1;

      $self->logger->debug("Could not get ip address form interface.");
      $self->logger->debug("Waiting another $wait seconds for network to come up");

  }

  if (! $ipaddress) {
    die "Could not get ip address for interface within "
      . $self->wait_for_network." seconds.";
  }

  return $self->ipaddress($ipaddress);

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
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-kvm</emulator>
    [% domain.disk_xml %]
    <controller type='pci' index='0' model='pci-root'>
      <alias name='pci.0'/>
    </controller>
    <controller type='sata' index='0'>
      <alias name='sata0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </controller>
    <interface type='network'>
      <source network='[% domain.network_name %]' bridge='[% domain.network_bridge %]'/>
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
    <memballoon model='virtio'>
      <alias name='balloon0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
    </memballoon>

[% domain.hostshare %]

  </devices>
</domain>
