#!/bin/bash

# Remove any stale ssh known hosts
rm -f ~/.ssh/known_hosts

# Bootstrap the juju environment
juju bootstrap --debug

# Deploy the juju-gui to the bootstrap node
juju deploy --to=0 juju-gui
juju expose juju-gui

ADMIN_SECRET=`cat ~/.juju/environments/maas.jenv | grep admin-secret | awk '{ print $2 }'`
JUJU_GUI=`juju status juju-gui | grep public-address | awk '{ print $2 }' | xargs host | grep address | awk '{ print $4 }'`
echo "Admin Secret: $ADMIN_SECRET"
echo "juju-gui: http://$JUJU_GUI"
