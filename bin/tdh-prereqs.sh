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

#sudo yum erase -y mariadb-libs
#sudo yum install -y java-1.8.0-openjdk-devel wget tmux htop

# xorg-x11-server-utils

rt=$?
if [ $rt -gt 0 ]; then
    echo "Error in install."
fi

echo "$PNAME finished"

exit 0
