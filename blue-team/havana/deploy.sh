#!/bin/bash
#Services need to be deployed in correct order as machines are pre-deployed.
#node 1, 2 are KVM virtual hosts on the master MAAS node.
#node 3 is for Openstack management services using LXC
#nodes 4-11 are the rest of the physical nodes.
set -e
[ -d ~/landscape ] || bzr branch lp:landscape
cd ~/landscape/dev/charms
[ -f license.txt ] || echo "Need to create license.txt" && false
[ -f landscape.yaml ] || echo > landscape.yaml <<EOF
lds-quickstart:
  server_fqdn: lds.orangebox.org
  admin_email: admin@lds.orangebox.org
  admin_name: admin
  admin_password: Password1+
  license: |
    $(sed -e 's/^/    /' < license.txt)
EOF

echo "Deploy LDS"
juju deploy local:lds-quickstart --config=landscape.yaml --to 1
cd -

echo "Deploying Neutron"
juju deploy cs:quantum-gateway-12 --config=havana.yaml neutron-gateway --to 2

echo "Deploying services to management node"
juju deploy cs:mysql-29 --to 3/lxc/0
juju deploy cs:rabbitmq-server-16 --to 3/lxc/1

juju deploy cs:keystone-23 --config=havana.yaml --to 3/lxc/2
juju deploy cs:glance-26 --config=havana.yaml --to 3/lxc/3
juju deploy cs:openstack-dashboard-11 --config=havana.yaml --to 3/lxc/4

juju deploy cs:nova-cloud-controller-19 --config=havana.yaml --to 3/lxc/5
juju deploy cs:cinder-14 --config=havana.yaml --to 3/lxc/6

#now safe to use the rest of the nodes without numbering.

echo "Deploying nova-compute"
juju deploy nova-compute --config=havana.yaml
juju add-unit --num-units 3 nova-compute

echo "Deploying Ceph Storage nodes"
juju deploy ceph --config=havana.yaml
juju add-unit --num-units 2 ceph

echo "Adding Openstack relationships"
juju add-relation mysql keystone
juju add-relation mysql nova-cloud-controller
juju add-relation mysql glance
juju add-relation mysql cinder
juju add-relation mysql neutron-gateway
juju add-relation rabbitmq-server cinder
juju add-relation rabbitmq-server nova-cloud-controller
juju add-relation rabbitmq-server neutron-gateway
juju add-relation keystone nova-cloud-controller
juju add-relation keystone glance
juju add-relation keystone cinder
juju add-relation keystone openstack-dashboard
juju add-relation nova-cloud-controller glance 
juju add-relation nova-cloud-controller cinder
juju add-relation nova-cloud-controller neutron-gateway


echo "Adding Ceph relationships"
juju add-relation ceph mysql
juju add-relation ceph rabbitmq-server
juju add-relation ceph glance
juju add-relation ceph cinder
juju add-relation ceph nova-compute

echo "Adding Landscape client relationships"
for service in lds neutron-gateway mysql cinder keystone rabbitmq-server glance nova-cloud-computer openstack-dashboard nova-cloud-controller nova-compute ceph; do
    juju add-relation $service landscape-client:container
    juju add-relation $service landscape-client:registration
done
