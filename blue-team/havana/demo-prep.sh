#!/bin/bash
#Canonical
export PATH=~/test-bin:$PATH
date
echo "checking for existing Juju environment..."
juju status && echo "Existing deployment found, exiting." && exit

echo "Deploying Juju Bootstrap node to Virtual machine: juju.local using tags=juju"
juju bootstrap --upload-tools=true --constraints "tags=juju"

echo "unset constraints"
juju set-constraints tags=""
echo "Deploying Juju-gui to bootstrap node"
juju deploy --to 0 juju-gui

echo "Now deploying landscape-client charm to register Bootstrap node to LDS"

#Create a landscape.yaml file

#Deploy it
[ -f landscape-client.yaml ] || cat > landscape-client.yaml <<EOF
landscape-client:
     origin: ppa:landscape/trunk
     exchange-interval: 60
     urgent-exchange-interval: 30
     ping-interval: 10
     script-users: ALL
     include-manager-plugins: ScriptExecution
EOF
juju deploy --config=landscape-client.yaml cs:landscape-client

#Let's add the bootstrap node, which runs the juju-gui service
juju add-relation landscape-client:container juju-gui


echo "Landscape client charm deployed"

date
echo "Running pre-deployment"
