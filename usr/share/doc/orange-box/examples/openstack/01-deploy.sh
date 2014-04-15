#!/bin/bash

#Install juju-deployer package
#sudo apt-get install -y juju-deployer

#Deploy the bundle
#TODO: soft link to bundle to stable and bleeding edge charm revisions

set -x

juju-deployer -c havanaOB.yaml
