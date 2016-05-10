use strict;
use warnings;

use Test::More tests => 4;
use FindBin;
use Path::Class qw/dir/;
use Data::Dumper;

require_ok('Kanku::Util::VM');

my $vm = Kanku::Util::VM->new(
  domain_name => "mandatory"
);

my $got;
my $expected;
$got = $vm->get_disk_list( xml =>
"
<domain>
  <devices>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/var/lib/libvirt/images/kanku-vm.qcow2'/>
      <target dev='hda' bus='ide'/>
      <address type='drive' controller='0' bus='0' target='0' unit='0'/>
    </disk>
  </devices>
</domain>
"
);

$expected = [
          {
            'target_device' => 'hda',
            'source_file' => '/var/lib/libvirt/images/kanku-vm.qcow2'
          }
        ];

is_deeply($got,$expected,"Checking single disk");

$got = $vm->get_disk_list( xml =>
"
<domain>
  <devices>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/var/lib/libvirt/images/kanku-vm.qcow2'/>
      <target dev='hda' bus='ide'/>
      <address type='drive' controller='0' bus='0' target='0' unit='0'/>
    </disk>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/var/lib/libvirt/images/hdb.qcow2'/>
      <target dev='hdb' bus='ide'/>
      <address type='drive' controller='0' bus='0' target='0' unit='0'/>
    </disk>
  </devices>
</domain>
"
);

$expected = [
          {
            'target_device' => 'hda',
            'source_file' => '/var/lib/libvirt/images/kanku-vm.qcow2'
          },
          {
            'target_device' => 'hdb',
            'source_file' => '/var/lib/libvirt/images/hdb.qcow2'
          }
        ];

is_deeply($got,$expected,"Checking two disk");

$got = $vm->get_disk_list( xml =>
"
<domain>
  <devices>
  </devices>
</domain>
"
);

$expected = [];

is_deeply($got,$expected,"Checking without disk");

exit 0;
