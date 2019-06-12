#!/bin/bash
#
device="$1"
mount="$2"

if [ -z "$device" ] || [ -z "$mount" ]; then
    echo "Usage: $0 <device> <mountpoint>"
fi

# Format and mount attached disk
( sudo mkdir -p $mount )
( sudo mkfs.ext4 -F $device )
rt=$?

if [ $rt -gt 0 ]; then
    echo "Error formatting device"
    exit $rt
fi

devname=${device##*\/}

uuid=$( ls -l /dev/disk/by-uuid/ | grep $devname | awk '{ print $9 }' )

( cp /etc/fstab /tmp/fstab.new )
( echo "UUID=$uuid  $mount                  ext4     defaults         1 2" >> /tmp/fstab.new )
( sudo cp /tmp/fstab.new /etc/fstab )
( sudo mount $mount )
rt=$?

if [ $rt -gt 0 ]; then
    echo "Error mounting device"
    exit $rt
fi

echo "$0 finished."
exit $rt
