#!/bin/bash
#
#  Install host prerequisites
#
PNAME=${0##*\/}
rt=$?


sudo yum erase -y mariadb-libs
sudo yum install -y java-1.8.0-openjdk-devel wget tmux htop

# xorg-x11-server-utils

rt=$?
if [ $rt -gt 0 ]; then
    echo "Error in yum install."
fi

echo "$PNAME finished"

exit 0
