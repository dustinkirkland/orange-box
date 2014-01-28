#!/bin/bash
set -ex
sudo apt-get install --yes libvirt-bin virtinst qemu-kvm
[ -d ~/isos ] || mkdir ~/isos
[ -f ~/isos/ubuntu-12.04.3-server-amd64.iso ] || wget http://releases.ubuntu.com/precise/ubuntu-12.04.3-server-amd64.iso -O ~/isos/ubuntu-12.04.3-server-amd64.iso

# Make Logical Volumes for the guests
sudo vgscan | grep BigDisk || sudo vgcreate BigDisk /dev/sdb1
sudo lvdisplay | grep juju_disk || sudo lvcreate -L20G -n juju_disk BigDisk
sudo lvdisplay | grep lds_disk || sudo lvcreate -L500G -n lds_disk BigDisk
sudo lvdisplay | grep neutron_disk || sudo lvcreate -L20G -n neutron_disk BigDisk

# Setup networking
# Add to /etc/network/interfaces
grep br0 /etc/network/interfaces || sudo tee -a /etc/network/interfaces <<EOF
auto br0
iface br0 inet dhcp
    bridge_ports eth0
    bridge_stp off
    bridge_fd 0
    bridge_maxwait 0

auto br1
iface br1 inet static
    address 10.0.0.1
    netmask 255.255.255.0
    broadcast 10.0.0.255
    network 10.0.0.0
    bridge_ports em1
    bridge_stp off
    bridge_fd 0
    bridge_maxwait 0
EOF
sudo ifup br0
sudo ifup br1
[ -d /home/maas ] || sudo install -d /home/maas --owner maas --group maas
sudo chsh maas -s /bin/bash
[ -d /home/maas/.ssh ] || echo -e "\n\n\n" | sudo -u maas ssh-keygen -N "" -t rsa -f /home/maas/.ssh/id_rsa
grep 'maas@' ~/.ssh/authorized_keys || sudo cat /home/maas/.ssh/id_rsa.pub | tee -a /home/ubuntu/.ssh/authorized_keys
# 10.0.0.1 known hosts
sudo virsh list --all --name | grep juju-bootstrap || sudo virt-install --name juju-bootstrap --ram 4096 --disk path=/dev/BigDisk/juju_disk --vcpus=2 --os-type=linux --pxe --network=bridge=br0,bridge=br1 || true
sudo virsh list --all --name | grep lds || sudo virt-install --name lds --ram 4096 --disk path=/dev/BigDisk/lds_disk --vcpus=2 --os-type=linux --pxe --network=bridge=br0,bridge=br1 || true
sudo virsh list --all --name | grep neutron || sudo virt-install --name neutron --ram 4096 --disk path=/dev/BigDisk/neutron_disk --vcpus=2 --os-type=linux --pxe --network=bridge=br0,bridge=br1 || true

for system in juju-bootstrap lds neutron; do
    mac=$(sudo virsh dumpxml $system | python -c 'import sys, lxml.etree; print list(lxml.etree.parse(sys.stdin).iter("mac"))[0].get("address")')
    system_id=$(maas-cli admin nodes list mac_address=$mac | grep system_id | cut -d'"' -f4)
    maas-cli admin node update $system_id hostname=$system.local power_type=virsh power_parameters_power_address=qemu+ssh://ubuntu@10.0.0.1/system power_parameters_power_id=$system
    maas-cli admin tags new name=$system || true
    maas-cli admin tag update-nodes $system add=$system_id
    maas-cli admin tag update-nodes use-fastpath-installer add=$system_id
    maas-cli admin node commission $system_id
done

