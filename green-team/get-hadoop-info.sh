#!/bin/bash
HADOOP_GUI=`juju status hadoop-master | grep public-address | awk '{ print $2 }' | xargs host | grep address | awk '{ print $4 }'`
echo "hadoop-master gui: http://$HADOOP_GUI:50030"

