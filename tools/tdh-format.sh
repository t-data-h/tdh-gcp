#!/bin/bash
#
#  Format an attached data disk. Intended to be ran directly on a remote
#  host. Note that this will format the device as a full block device
#  with no partition table.  `parted -s $dev mklabel loop`
#
#  scp $PNAME remote_host:
#  ssh $remote_host $PNAME /dev/sdb /data01
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

usage="
Format a raw block device as ext4 or xfs. 

Synopsis: 
  $PNAME [options] <device> <mountpoint>

Options:
  -f|--force    : Set force option on mkfs
  -h|--help     : Show usage info and exit
  -x|--use-xfs  : Use XFS Filesytem instead of default 'ext4'
 
eg. $PNAME -f -x /dev/sdb /data01
Note, use --force to avoid being prompted.
"

# -----------------------------------

while [ $# -gt 0 ]; do
    case "$1" in
        'help'|-h|--help)
            echo "$usage"
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
    echo "$usage"
    exit 1
fi

# Ensure mount for device does not already exist
mnt=$( mount | grep $device 2>/dev/null )
rt=$?
if [ $rt -eq 0 ]; then
    echo "Error! Mount appears to exist: '$mnt'" >&2
    exit 1
fi

# Format and mount attached disk
( sudo mkdir -p $mount )
rt=$?

if [ $rt -ne 0 ]; then
    echo "$PNAME: Error in mkdir of mount path: $mount" >&2
    exit $rt
fi

if [ $usexfs -eq 1 ]; then
    fstype="$xfstype"
    cmd="${cmd}.${xfstype}"
    if [ $force -eq 1 ]; then
        cmd="$cmd -f"
    fi
else
    cmd="${cmd}.${fstype}"
    if [ $force -eq 1 ]; then
        cmd="$cmd -F"
    fi
fi

echo "$PNAME Formatting device '$device' as $fstype..."

# Execute mkfs
cmd="$cmd $device"

echo "( $cmd )"
echo ""
( sudo $cmd )

rt=$?
if [ $rt -gt 0 ]; then
    echo "$PNAME Error formatting device" >&2
    exit $rt
fi

sleep 3  # allow for kernel to settle on new device

echo ""
echo " -> Format complete"

uuid=$( ls -l /dev/disk/by-uuid/ | grep $devname | awk '{ print $9 }' )

if [ -z "$uuid" ]; then
    echo "$PNAME Error obtaining disk UUID from '/dev/disk/by-uuid'" >&2
    exit 1
fi

echo "$device UUID='$uuid'"

# add mount to fstab
fstab=$(mktemp /tmp/tdh-fstab.XXXXXXXX)

echo " -> Created fstab tmp file: '$fstab'"
( cp /etc/fstab $fstab )
( printf "UUID=$uuid %15s  %10s  defaults,noatime    1 2\n" $mount $fstype >> $fstab )
( sudo cp $fstab /etc/fstab; sudo chmod 644 /etc/fstab )
( sudo mount $mount )

rt=$?
if [ $rt -gt 0 ]; then
    echo "$PNAME Error mounting device $device" >&2
else
    echo " -> Device '$device' mounted to '$mount'"
fi

echo "$PNAME finished."
exit $rt
