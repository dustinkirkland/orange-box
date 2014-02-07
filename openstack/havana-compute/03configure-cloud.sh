#!/bin/bash

echo "Configuring Openstack environment"
cd ../openstack-configuration/

[ -f ~/images/precise-server-cloudimg-amd64-disk1.img ] || ./get-cloud-images

./inspect-environment
source envrc

./prepare-cloud havana

echo "Skipping Juju config as no Object Storage available for Juju"

