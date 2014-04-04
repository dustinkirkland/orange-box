#!/bin/bash

# Remove any stale ssh known hosts
rm -f ~/.ssh/known_hosts

# Bootstrap the juju environment
juju bootstrap --debug

# Deploy the juju-gui to the bootstrap node
juju deploy --to=0 juju-gui
juju expose juju-gui

# Deploy hadoop ( with HBase enabled )
juju deploy hadoop hadoop-master
juju set hadoop-master hbase=True
juju deploy hadoop hadoop-slavecluster -n 3
juju set hadoop-slavecluster hbase=True
juju add-relation hadoop-master:namenode hadoop-slavecluster:datanode
juju add-relation hadoop-master:jobtracker hadoop-slavecluster:tasktracker
juju expose hadoop-master

# Deploy hive ( with MySQL )
juju deploy hive -n 3
juju deploy mysql
juju set mysql binlog-format=ROW
juju add-relation hive:db mysql:db
juju add-relation hive:namenode hadoop-master:namenode
juju add-relation hive:jobtracker hadoop-master:jobtracker

ADMIN_SECRET=`cat ~/.juju/environments/maas.jenv | grep admin-secret | awk '{ print $2 }'`
JUJU_GUI=`juju status juju-gui | grep public-address | awk '{ print $2 }' | xargs host | grep address | awk '{ print $4 }'`
echo "Admin Secret: $ADMIN_SECRET"
echo "juju-gui: http://$JUJU_GUI"
