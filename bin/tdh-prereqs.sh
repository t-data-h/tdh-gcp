#!/bin/bash
#
#  Install host prerequisites
#
PNAME=${0##*\/}
rt=0

tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/tdh-gcp-config.sh ]; then
    . ${tdh_path}/tdh-gcp-config.sh
fi

# -------------
# Currently prereqs are handled during the ansible install playbook, but
# keeping this around as a hook for installing prior to ansible bootstrap


if [ $rt -gt 0 ]; then
    echo "Error in install."
fi

echo "$PNAME finished"

exit 0
