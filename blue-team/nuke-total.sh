#!/bin/bash
#
# BE FOREWARNED!
#
# THIS SCRIPT
#	TAKES NODES 1-9 BACK TO BASE READY STATE
#	ELIMINATES ALL KVMS FROM NODE 0
#	TAKES MAAS STATE BACK TO BASE LEVELS
#
# THIS SCRIPT WILL LEAVE ALONE
# 	The LVM setup
#	The networking setup (including DNS/DHCP info)
#	The MAAS basic setup (including maas user/ssh,
#	  but not juju environment/bootstrap info)
#

set -e
export PATH=~/test-bin:$PATH
echo -e "Clear juju environment with juju destroy-environment"
echo -e "This will set nodes 1-9 back to Ready state in MAAS"
echo -e "and delete the ~/.juju/environments dir."
sudo juju destroy-environment maas || true
sudo rm -rf ~/.juju/environments

echo -e " Delete virtual nodes from MAAS state"
nodes=$(maas-cli admin tag nodes virtual | grep system_id | sed -e 's/", $//' -e 's/^.*"//')
for node in $nodes;do 
	echo "Deleting virtual node: $node from MAAS."
	maas-cli admin node delete $node
done

echo -e "Deleting KVMs from node 0"

set +e # We want to try all of these
sudo virsh destroy juju
sudo virsh destroy lds
sudo virsh destroy neutron
sudo virsh undefine juju
sudo virsh undefine lds
sudo virsh undefine neutron
set -e

echo -e "Done."
