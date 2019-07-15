#!/bin/bash
#
PNAME=${0##*\/}

if [ -f ${tdh_path}/tdh-gcp-config.sh ]; then
    . ${tdh_path}/tdh-gcp-config.sh
fi

# -----------------------------------

device="$1"
mount="$2"
devname=${device##*\/}

# -----------------------------------

if [ -z "$device" ] || [ -z "$mount" ]; then
    echo "Usage: $PNAME <device> <mountpoint>"
    exit 1
fi

# Format and mount attached disk
( sudo mkdir -p $mount )
( sudo mkfs.ext4 -F $device )

rt=$?
if [ $rt -gt 0 ]; then
    echo "Error formatting device"
    exit $rt
fi

sleep 3

# Get UUID
uuid=$( ls -l /dev/disk/by-uuid/ | grep $devname | awk '{ print $9 }' )

if [ -z "$uuid" ]; then
    echo "Error obtaining disk UUID from '/dev/disk/by-uuid'"
    exit 1
fi

echo " $device  UUID='$uuid'"

# add mount to fstab
fstab=$(mktemp /tmp/tdh-fstab.XXXXXXXX)

( cp /etc/fstab $fstab )
( echo "UUID=$uuid  $mount                  ext4     defaults         1 2" >> /tmp/fstab.new )
( sudo cp $fstab /etc/fstab; sudo chmod 644 /etc/fstab )
( sudo mount $mount )

rt=$?
if [ $rt -gt 0 ]; then
    echo "Error mounting device $device"
fi

echo "$PNAME finished."

exit $rt
