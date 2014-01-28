#!/bin/bash


echo "Deploying services to compute nodes"
juju deploy cs:mysql-29 --to 2/lxc/0
juju deploy cs:rabbitmq-server-16 --to 2/lxc/1

echo "waiting 30 seconds to deploy the rest of the services"
sleep 30

juju deploy cs:keystone-23 --config=havana.yaml --to 2/lxc/2
juju deploy cs:glance-26 --config=havana.yaml --to 2/lxc/3
juju deploy cs:openstack-dashboard-11 --config=havana.yaml --to 2/lxc/4

juju deploy cs:nova-cloud-controller-19 --config=havana.yaml --to 2/lxc/5
juju deploy cs:cinder-14 --config=havana.yaml --to 2/lxc/6

echo "Deploying Neutron"
juju deploy cs:quantum-gateway-12 --config=havana.yaml neutron-gateway --to 1

echo "Deploying nova-compute"
juju deploy nova-compute --config=havana.yaml --to 3
juju add-unit --num-units 3 nova-compute

echo "Deploying Ceph Storage nodes"
juju deploy ceph --config=havana.yaml 

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


