#!/bin/bash
#Services need to be deployed in correct order as machines are pre-deployed.
#node 1, 2 are KVM virtual hosts on physical node 0.
#node 3 is for Openstack management services using LXC on physical node 1.
#nodes 4-11 are the rest of the physical nodes.
echo "Deploy ubuntu to take place of LDS deploy."
juju deploy ubuntu --to 1

echo "Deploying Neutron"
juju deploy cs:quantum-gateway-12 --config=havana.yaml neutron-gateway --to 2

echo "Deploying services to compute nodes"
juju deploy cs:mysql-29 --to 3/lxc/0
juju deploy cs:rabbitmq-server-16 --to 3/lxc/1

juju deploy cs:keystone-23 --config=havana.yaml --to 3/lxc/2
juju deploy cs:glance-26 --config=havana.yaml --to 3/lxc/3
juju deploy cs:openstack-dashboard-11 --config=havana.yaml --to 3/lxc/4

juju deploy cs:nova-cloud-controller-19 --config=havana.yaml --to 3/lxc/5
juju deploy cs:cinder-14 --config=havana.yaml --to 3/lxc/6

echo "Deploying nova-compute"
juju deploy nova-compute --config=havana.yaml
juju add-unit --num-units 4 nova-compute

echo "Deploying Ceph Storage nodes to nova-compute nodes"
juju deploy ceph --config=havana.yaml --to 4
juju add-unit ceph --to 5
juju add-unit ceph --to 6
juju add-unit ceph --to 7
juju add-unit ceph --to 8

echo "Deploying Swift Storage nodes"
juju deploy swift-proxy --config=havana.yaml 
juju deploy swift-storage --config=havana.yaml swift-storage-z1
juju deploy swift-storage --config=havana.yaml swift-storage-z2

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

echo "Adding Swift relationships"
juju add-relation swift-proxy keystone
juju add-relation swift-proxy swift-storage-z1
juju add-relation swift-proxy swift-storage-z2

