#!/bin/bash
set -ex
sudo apt-get install --yes libvirt-bin virtinst qemu-kvm juju iptables-persistent juju-deployer \
  python-keystoneclient python-novaclient python-cinderclient python-glanceclient python-neutronclient \
  python-nose git python-swiftclient uuid
[ -d ~/isos ] || mkdir ~/isos
[ -f ~/isos/ubuntu-12.04.3-server-amd64.iso ] || wget http://releases.ubuntu.com/precise/ubuntu-12.04.3-server-amd64.iso -O ~/isos/ubuntu-12.04.3-server-amd64.iso

grep 'libvirtd.*ubuntu' /etc/group || (echo "Adding ubuntu user to libvirtd group" && sudo adduser ubuntu libvirtd && echo "Please re-login and run again" && exit 0)

[ -f /home/ubuntu/.ssh/id_rsa ] || echo -e "\n\n\n" | ssh-keygen -N "" -t rsa -f /home/ubuntu/.ssh/id_rsa
maas-cli admin sshkeys list | grep id || maas-cli admin sshkeys new key="$(cat ~/.ssh/id_rsa.pub)"

# Make Logical Volumes for the guests
echo "Skipping setup of LVMs"
# sudo vgscan | grep BigDisk || sudo vgcreate BigDisk /dev/sdb1

# for service in juju lds neutron; do
#     sudo lvdisplay | grep ${service}_disk && sudo lvremove -f BigDisk/${service}_disk
# done
# sudo lvcreate -L20G -n juju_disk BigDisk
# sudo lvcreate -L800G -n lds_disk BigDisk
# sudo lvcreate -L20G -n neutron_disk BigDisk

sudo tee /etc/init/maas-pserv.override << EOF
# Don't start maas-pserv until bridge has started
start on net-device-up IFACE=br1
EOF

# Setup networking
# Add to /etc/network/interfaces
grep br0 /etc/network/interfaces || sudo tee /etc/network/interfaces <<EOF
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback


# USB NIC; connect to LAN.
#auto em1
#iface em1 inet dhcp

#auto eth0
#iface eth0 inet dhcp

# External connectivity
auto br0
iface br0 inet dhcp
    bridge_ports eth0
    bridge_stp off
    bridge_fd 0
    bridge_maxwait 0

# The interface to the internal network.
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
    dns-nameservers 10.0.0.1
    dns-search orangebox.org

EOF

sudo sed -i -e's/eth0/br0/g' /etc/iptables/rules.v4
sudo sed -i -e's/em1/br1/g' /etc/iptables/rules.v4
sudo service iptables-persistent restart

cluster_controller_uuid=$(maas-cli admin node-groups list | grep uuid | cut -d'"' -f4)
# Replace MAAS management of em1 with br1
maas-cli admin node-group-interface delete ${cluster_controller_uuid} em1 && maas-cli admin node-group-interfaces new ${cluster_controller_uuid} interface=br1 ip=10.0.0.1 subnet_mask=255.255.255.0 broadcast_ip=10.0.0.255 router_ip=10.0.0.1 ip_range_low=10.0.0.10 ip_range_high=10.0.0.254 management=2 && sudo service maas-dhcp-server restart && sudo service maas-pserv restart && sudo service maas-cluster-celery restart && sudo service maas-region-celery restart

sudo sed -ie 's/#prepend domain-name-servers 127.0.0.1;/prepend domain-name-servers 10.0.0.1;/' /etc/dhcp/dhclient.conf
virsh net-info default && virsh net-destroy default && virsh net-undefine default

# create bridge on 172.16.1.0/24 for neutron
virsh net-info bridge2 || ( virsh net-define ~/micro-cluster/blue-team/bridge2.xml && virsh net-autostart bridge2 && virsh net-start bridge2 )

# cat >/tmp/maas-private.xml <<EOF
# <network>
#   <name>maas-private</name>
#   <uuid>c46a86d4-3111-ddfa-1118-922b78d37600</uuid>
#   <bridge name='virbr1' stp='on' delay='0' />
#   <mac address='52:54:11:26:F2:BC'/>
# </network>
# EOF

# cat >/tmp/maas-external.xml <<EOF
# <network>
#   <name>maas-external</name>
#   <uuid>c46a86d4-3111-ddfa-1118-922b78201208</uuid>
#   <bridge name='virbr2' stp='on' delay='0' />
#   <mac address='52:54:11:26:F2:BD'/>
# </network>
# EOF
# for net in maas-private maas-external; do
#     virsh net-define /tmp/$net.xml
#     virsh net-autostart $net
#     virsh net-start $net
# done
sudo ifup br0
sudo ifup br1
[ -d /home/maas ] || sudo install -d /home/maas --owner maas --group maas
sudo chsh maas -s /bin/bash
[ -d /home/maas/.ssh ] || echo -e "\n\n\n" | sudo -u maas ssh-keygen -N "" -t rsa -f /home/maas/.ssh/id_rsa
[ -f /home/maas/.ssh/config ] || sudo -u maas tee /home/maas/.ssh/config <<EOF
Host *
   UserKnownHostsFile /dev/null
   StrictHostKeyChecking no
EOF
grep 'maas@' ~/.ssh/authorized_keys || sudo cat /home/maas/.ssh/id_rsa.pub | tee -a /home/ubuntu/.ssh/authorized_keys
# 10.0.0.1 known hosts

# create the kvms, not in loop due to neutron being different
echo -e "virt-install juju instance"
virsh list --all --name | grep juju || sudo virt-install --name juju --ram 4096 --disk path=/mnt/juju_disk,size=20 --vcpus=2 --os-type=linux --pxe --network=bridge=br1 --boot network || true
echo -e "virt-install lds instance"
virsh list --all --name | grep lds || sudo virt-install --name lds --ram 4096 --disk path=/mnt/lds_disk,size=20 --vcpus=2 --os-type=linux --pxe --network=bridge=br1 --boot network || true
echo -e "virt-install neutron instance"
virsh list --all --name | grep neutron || sudo virt-install --name neutron --ram 4096 --disk path=/mnt/neutron_disk,size=20 --vcpus=2 --os-type=linux --pxe --network=bridge=virbr1 --network=bridge=br1 --boot network || true

# loop to fixup the kvms
for system in juju lds neutron; do
    mac=$(virsh dumpxml $system | python -c 'import sys, lxml.etree; print list(lxml.etree.parse(sys.stdin).iter("mac"))[0].get("address")')
    system_id=$(maas-cli admin nodes list mac_address=$mac | grep system_id | cut -d'"' -f4)
    # until [ $system_id ]; do
    #     system_id=$(maas-cli admin nodes list mac_address=$mac | grep system_id | cut -d'"' -f4)
    #     sleep 10
    # done
    maas-cli admin node update $system_id hostname=$system.master power_type=virsh power_parameters_power_address=qemu+ssh://ubuntu@10.0.0.1/system power_parameters_power_id=$system
    maas-cli admin tags new name=$system || true
    maas-cli admin tag update-nodes $system add=$system_id
    maas-cli admin tag update-nodes use-fastpath-installer add=$system_id
    maas-cli admin node commission $system_id || true
done


for system in juju lds neutron; do
    mac=$(virsh dumpxml $system | python -c 'import sys, lxml.etree; print list(lxml.etree.parse(sys.stdin).iter("mac"))[0].get("address")')
    system_id=$(maas-cli admin nodes list mac_address=$mac | grep system_id | cut -d'"' -f4)
    echo "Waiting for $system to be Ready"
    until maas-cli admin node read $system_id | grep status | awk {'print $2'} | grep '4,'; do echo -n '.'; sleep 5; done
done


# set all physical nodes to use fast installer

for system in node1 node2 node3 node4 node5 node6 node7 node8 node9; do
   system_id=$(maas-cli admin nodes list hostname=$system.master | grep system_id | cut -d'"' -f4)
   maas-cli admin tag update-nodes use-fastpath-installer add=$system_id
done

#Add Tag NUC to identify physical nodes
maas-cli admin tag new name='nuc' comment='physical nuc nodes' definition='//node[@id="core"]/product = "D53427RKE"'

# DNS forwarding, /etc/bind/named.conf.options

[ -d ~/.juju ] || mkdir ~/.juju

maas_oauth=$(maas-cli list | awk '{ print $3 }')

cat > ~/.juju/environments.yaml <<EOF
environments:
    maas:
        type: maas
        admin-secret: Password1+

        # maas-server specifies the location of the MAAS server. It must
        # specify the base path.
        maas-server: 'http://10.0.0.1/MAAS/'
        
        # maas-oauth holds the OAuth credentials from MAAS.
        maas-oauth: '$maas_oauth'
EOF

echo "Install script finished"
