#!/bin/bash
#Darryl weaver, 26th January 2014

date
echo "checking for existing Juju environment..."
juju status && echo "Existing deployment found, exiting." && exit

echo "Deploying Juju Bootstrap node to Virtual machine: juju.local using tags=juju-bootstrap"
juju bootstrap --upload-tools=true --constraints "tags=juju-bootstrap"

echo "unset constraints"
juju set-constraints tags=""
echo "Deploying Juju-gui to bootstrap node"
juju deploy --to 0 juju-gui

echo "Now deploying landscape-client charm to register Bootstrap node to LDS"

#Create a landscape.yaml file

#Deploy it
[ -f landscape-client.yaml ] || echo > landscape-client.yaml <<EOF
landscape-client:
     origin: ppa:landscape/trunk
     exchange-interval: 60
     urgent-exchange-interval: 30
     ping-interval: 10
     script-users: ALL
     include-manager-plugins: ScriptExecution
EOF
juju deploy --config=landscape-client.yaml landscape-client

#Let's add the bootstrap node, which runs the juju-gui service
juju add-relation landscape-client:container juju-gui
juju add-relation landscape-client:registration juju-gui


echo "Landscape client charm deployed"

date
echo "Running pre-deployment"




