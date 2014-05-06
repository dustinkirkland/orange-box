#!/bin/bash
#
# Ameet Paranjape, 2 April 2014

set -x

juju status && echo "Existing deployment found, exiting." && exit 0
#juju bootstrap --constraints "tags=virtual" --show-log --upload-tools
#juju set-constraints "tags="
juju bootstrap --show-log --upload-tools
juju deploy --to 0 --repository=/srv/charmstore/ local:precise/juju-gui
juju expose juju-gui

