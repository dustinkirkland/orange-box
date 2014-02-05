#!/bin/bash
#Canonical
date
echo "checking for existing Juju environment..."
juju status && echo "Existing deployment found, exiting." && exit

echo "Deploying Juju Bootstrap node to Virtual machine: juju.local using tags=juju"
juju bootstrap --upload-tools=true --constraints "tags=juju"

echo "unset constraints"
juju set-constraints tags=""
echo "Deploying Juju-gui to bootstrap node"
juju deploy --to 0 juju-gui

date
echo "Running pre-deployment"
