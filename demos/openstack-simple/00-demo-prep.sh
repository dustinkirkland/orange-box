#!/bin/bash
#
# Ameet Paranjape, 2 April 2014

echo "Demo prep runtime is about 5 minutes"
echo "checking for existing Juju environment..."
juju status && echo "Existing deployment found, exiting." && exit

echo "No existing environment found, we are good to go."
juju bootstrap
echo "Waiting for bootstrap node to deploy (5 minutes)"
sleep 300
juju deploy --to 0 juju-gui
juju deploy ubuntu

