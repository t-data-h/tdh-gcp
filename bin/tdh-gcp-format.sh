#!/bin/bash
#
PNAME=${0##*\/}

device="$1"
mount="$2"
devname=${device##*\/}

# -----------------------------------
if [ -z "$device" ] || [ -z "$mount" ]; then
    echo "Usage: $PNAME <device> <mountpoint>"
fi

# -----------------------------------
# Format and mount attached disk
( sudo mkdir -p $mount )
( sudo mkfs.ext4 -F $device )

rt=$?
if [ $rt -gt 0 ]; then
    echo "Error formatting device"
    exit $rt
fi

uuid=$( ls -l /dev/disk/by-uuid/ | grep $devname | awk '{ print $9 }' )

if [ -z "$uuid" ]; then
    echo "Error obtaining disk UUID from ''/dev/disk/by-uuid'"
    exit 1
fi

( cp /etc/fstab /tmp/fstab.new )
( echo "UUID=$uuid  $mount                  ext4     defaults         1 2" >> /tmp/fstab.new )
( sudo cp /tmp/fstab.new /etc/fstab )
( sudo mount $mount )

rt=$?
if [ $rt -gt 0 ]; then
    echo "Error mounting device"
    exit $rt
fi

echo "$PNAME finished."

exit $rt
