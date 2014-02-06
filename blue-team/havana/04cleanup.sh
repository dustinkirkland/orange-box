#!/bin/bash

juju destroy-environment maas

#Need to remove the Openstack Juju environment from environments.yaml

#Removing known hosts as all keys will be regenerated when re-deploying.
rm ~/.ssh/known_hosts

