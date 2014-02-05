#!/bin/bash
#Services need to be deployed in correct order as machines are pre-deployed.
#node 1, 2 are KVM virtual hosts on the master MAAS node.
#node 3 is for Openstack management services using LXC
#nodes 4-11 are the rest of the physical nodes.
set -ex
[ -d ~/landscape ] || bzr branch lp:landscape ~/landscape

[ -f license.txt ] || (echo "Need to create license.txt" && false)

if [ ! -d precise/lds ]; then
  mkdir -p precise
  cp -r ~/landscape/dev/charms/precise/lds-quickstart precise/lds
  (
    cd precise/lds
    bzr init
    bzr add
    bzr commit -m "Fake lds charm"
  )
fi

juju-deployer -c bundle.yaml -d

# NOTE: add relation not encompassed in bundle
juju add-relation landscape-client:container juju-gui
