#!/bin/bash


echo "Deploying services to compute nodes"
juju deploy cs:mysql-29 --to 3/lxc/7
juju deploy cs:rabbitmq-server-16 --to 3/lxc/8

juju deploy cs:keystone-23 --config=havana.yaml --to 3/lxc/9
juju deploy cs:glance-26 --config=havana.yaml --to 3/lxc/10
juju deploy cs:openstack-dashboard-11 --config=havana.yaml --to 3/lxc/11

juju deploy cs:nova-cloud-controller-19 --config=havana.yaml --to 3/lxc/12
juju deploy cs:cinder-14 --config=havana.yaml --to 3/lxc/13

echo "Deploying Neutron"
juju deploy cs:quantum-gateway-12 --config=havana.yaml neutron-gateway --to 2

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


