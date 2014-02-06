#!/bin/bash

juju destroy-environment maas

#Need to remove the Juju environments
rm -rf ~/.juju/

#Removing known hosts as all keys will be regenerated when re-deploying.
rm ~/.ssh/known_hosts

#Now re-create MAAS Juju environment.
mkdir ~/.juju

maas_oauth=$(maas-cli list | awk '{ print $3 }')

cat > ~/.juju/environments.yaml <<EOF
environments:
    maas:
        type: maas
        admin-secret: Password1+

        # maas-server specifies the location of the MAAS server. It must
        # specify the base path.
        maas-server: 'http://10.0.0.1/MAAS/'
        
        # maas-oauth holds the OAuth credentials from MAAS.
        maas-oauth: '$maas_oauth'
EOF


