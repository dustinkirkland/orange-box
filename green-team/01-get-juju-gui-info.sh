#!/bin/bash
ADMIN_SECRET=`cat ~/.juju/environments/maas.jenv | grep admin-secret | awk '{ print $2 }'`
JUJU_GUI=`juju status juju-gui | grep public-address | awk '{ print $2 }' | xargs host | grep address | awk '{ print $4 }'`
echo "Admin Secret: $ADMIN_SECRET"
echo "juju-gui: http://$JUJU_GUI"

