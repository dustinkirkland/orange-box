#!/bin/bash
#Darryl Weaver, 26th January 2014
export PATH=~/test-bin:$PATH

date
echo "Pre-deployment script to add machines to environment in advance of a demo"

juju add-machine --constraints tags=lds
juju add-machine --constraints tags=neutron
juju add-machine
echo "Attempting to bring up br0 on LXC host"
run-one-until-success juju ssh 3 "[ -f /etc/network/eth0.config ] && sudo ifup br0"

for v in `seq 1 7`;
       	do
               	juju add-machine lxc:3
       	done
date
juju status
echo "Run juju status to check if all machines in started state."
date
echo "Then run deploy.sh to deploy demo"

