#!/bin/bash
#
#  Initialize our master instance

tdh_path=$(dirname "$(readlink -f "$0")")
prefix="tdh"
name="m01"
host="${prefix}-${name}"
rt=

# Create Instance
( $tdh_path/bin/tdh-gcp-compute.sh --prefix ${prefix} --type n1-standard-4 \
--attach --disksize 200GB create ${name} )

rt=$?

if [ $rt -gt 0 ]; then
    echo "Error in GCP initialization"
    exit $rt
fi

# Device format and mount
device="/dev/sdb"
mountpoint="/data"

( gcloud compute ssh ${host} < ${tdh_path}/bin/tdh-gcp-format.sh $device $mountpoint )

# prereq's
sudo yum install -y java-1.8.0-openjdk wget tmux
sudo yum erase mariadb-libs

exit 0