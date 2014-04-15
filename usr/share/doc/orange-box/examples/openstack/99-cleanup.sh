#!/bin/bash

#Destroy everything
juju destroy-environment maas
export AMT_PASSWORD=Password1+
for i in $(seq 11 19); do
	yes | amttool 10.14.4.$i powerdown >/dev/null 2>&1
done
