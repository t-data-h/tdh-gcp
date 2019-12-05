#!/bin/bash
#
#  Format an attached data disk. Intended to be ran directly on a
#  remote host. This assumes we are a full block data device and
#  thus we do not create partitions.
#  eg.
#  scp $PNAME remote_host:
#  ssh $remote_host $PNAME /dev/sdb /data1
#
PNAME=${0##*\/}

# -----------------------------------

device=
mount=
devname=
cmd="mkfs"
fstype="ext4"
xfstype="xfs"
force=0
usexfs=0

# -----------------------------------


usage()
{
    echo ""
    echo "Usage: $PNAME [options] <device> <mountpoint>"
    echo "  -f|--force   : Set force option on mkfs"
    echo "  -h|--help    : Show usage info and exit"
    echo "  -x|--use-xfs : Use XFS Filesytem instead of default ext4"
    echo ""
    echo " eg. $PNAME -x /dev/sdb /data1"
    echo ""
}

# -----------------------------------


while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -f|--force)
            force=1
            ;;
        -x|--use-xfs)
            usexfs=1
            ;;
        *)
            device="$1"
            mount="$2"
            shift $#
            ;;
    esac
    shift
done

devname=${device##*\/}

if [ -z "$device" ] || [ -z "$mount" ]; then
    usage
    exit 1
fi

# Ensure mount for device does not already exist
mnt=$( mount | grep $device 2>/dev/null )
rt=$?
if [ $rt -eq 0 ]; then
    echo "Error! Mount appears to exist: '$mnt'"
    exit 1
fi

# Format and mount attached disk
( sudo mkdir -p $mount )
rt=$?

if [ $rt -ne 0 ]; then
    echo "Error in mkdir of mount path: $mount"
    exit $rt
fi

if [ $usexfs -eq 1 ]; then
    fstype="$xfstype"
    cmd="${cmd}.${xfstype}"
    if [ $force -eq 1 ]; then
        cmd="$cmd -F"
    fi
else
    cmd="${cmd}.${fstype}"
    if [ $force -eq 1 ]; then
        cmd="$cmd -f"
    fi
fi

echo "$PNAME Formatting device '$device' as $fstype:"

# Execute our mkfs cmd
cmd="$cmd $device"
echo "( $cmd )"

( sudo $cmd )

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
echo "Created fstab tmp file: '$fstab'"

( cp /etc/fstab $fstab )
( echo "UUID=$uuid  $mount                  $fstype     defaults,noatime      1 2" >> $fstab )
( sudo cp $fstab /etc/fstab; sudo chmod 644 /etc/fstab )
( sudo mount $mount )

rt=$?
if [ $rt -gt 0 ]; then
    echo "Error mounting device $device"
fi

echo "$PNAME finished."
exit $rt
