#!/bin/bash

echo "Configuring Openstack environment"
cd ../openstack-configuration/

./get-cloud-images

./inspect-environment
source envrc

./prepare-cloud havana

echo "Configuring Juju environment"
cd ../juju-config/
./generate-jujuenv


