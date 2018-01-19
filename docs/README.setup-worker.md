# Install packages

```zypper in kanku-worker openvswitch openvswitch-switch libvirt```

# (On worker) Copy ssh keys for access

e.g. /opt/kanku/etc/ssh

# (On worker) Copy ssl cert for access to rabbitmq on master

e.g. /opt/kanku/etc/ssl


# (On master) Add worker in /opt/kanku/etc/config.yml

See section

```
Kanku::LibVirt::HostList:
```

# (On Worker) Configure openvswitch

SEE README.setup-ovs.md

and configure 

```
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
```
# (On worker) Create Pool for images

vi pool-default.xml
virsh pool-define pool-default.xml 
virsh pool-start default
virsh pool-autostart default

# Configure network for CreateDomain:

/opt/kanku/etc/config.yml

```
Kanku::Handler::CreateDomain:
  name:   kanku-ovs
  bridge: kanku-br0
```


# (On worker) Add ssh-keys from master to authorized_keys

# (On worker) Create and populate database

The database is only needed for the download history

# (On worker) Start and enable kanku-worker

systemctl start kanku-worker
systemctl enable kanku-worker
