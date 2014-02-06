#!/bin/bash
#Pre-requisite: Must have set your Launchpad login for bzr.
bzr launchpad-login || ( echo "Please set your Launchpad login: bzr launchpad-login LAUNCHPAD_ID and re-run." && exit )

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

echo "Deployment finished"
