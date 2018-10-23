# Install packages

```zypper in kanku-worker openvswitch libvirt```

# (On master) Copy ssh keys for access to worker

```
scp -r /etc/kanku/ssh <kanku-worker>:/etc/kanku/ssh
ssh <kanku-worker> chown kankurun:kanku -R /etc/kanku/ssh
```

# (On master) Copy ssl CA-cert for access to rabbitmq on master

'''
ssh <kanku-worker> mkdir -p /etc/kanku/ssl/
scp  /etc/rabbitmq/testca/certs/ca.cert.pem <kanku-worker>:/etc/kanku/ssl/cacert.pem
'''

# (On master) Add worker in /etc/kanku/kanku-config.yml

See section

'''
Kanku::LibVirt::HostList:
'''

# (On Worker) Configure openvswitch

## Configure /etc/kanku/kanku-config.yml

'''
Kanku::LibVirt::Network::OpenVSwitch:
  name:                kanku-ovs
  bridge:              kanku-br0
  vlan:                kanku-vlan1
  host_ip:             192.168.199.<INTER_WORKER_IP_HERE>
  network:             192.168.199.0/24
  dhcp_range:          192.168.199.66,192.168.199.254
  start_dhcp:          0
  is_gateway:          0

Kanku::Handler::CreateDomain:
  name:   kanku-ovs
  bridge: kanku-br0
'''

and

SEE README.setup-ovs.md

for further setup of openvswitch/libvirt

# (On worker) Create Pool for images

'''
virsh -c qemu+ssh://<kanku-worker>/system pool-define /etc/kanku/templates/cmd/setup/pool-default.xml 
virsh -c qemu+ssh://<kanku-worker>/system pool-start default
virsh -c qemu+ssh://<kanku-worker>/system pool-autostart default
'''

# Configure network for CreateDomain:

/etc/kanku/kanku-config.yml

'''
Kanku::Handler::CreateDomain:
  name:   kanku-ovs
  bridge: kanku-br0
'''

# (On worker) Add ssh-keys from master to authorized_keys

# (On worker) Create and populate database

The database is only needed for the download history.

'''
kanku db --create --server
'''

# (On worker) Start and enable kanku-worker

systemctl start kanku-worker
systemctl enable kanku-worker
