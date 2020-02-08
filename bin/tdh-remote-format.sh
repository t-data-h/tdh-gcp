#!/bin/bash
#
#  Bulk format attached volumes across multiple instances.
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/tdh-gcp-config.sh ]; then
    . ${tdh_path}/tdh-gcp-config.sh
fi

# -----------------------------------

devtypes=( "sd" "xvd" )
devtype="${devtypes[0]}"
format="$TDH_FORMAT"

pathpfx=
volnum=1
usexfs=0
dryrun=0
usegcp=0
ident=
force=
zone=
user="$USER"


usage()
{
    echo "Format and mount multiple sequentially ordered block devices"
    echo "on a set of hosts via ssh."
    echo ""
    echo "Usage: $TDH_PNAME [options] [host1] [host2] ..."
    echo "  -D|--disknum  <n>     : Number of disk volumes to mount (default=1)"
    echo "  -f|--force            : Set force option on 'mkfs'"
    echo "  -G|--use-gcp          : Use Google API for connecting to hosts"
    echo "  -h|--help             : Show usage info and exit"
    echo "  -i|--indentity <file> : SSH Identity file to use for hosts"
    echo "  -n|--dryrun           : Enable dryrun (no actions are taken)"
    echo "  -p|--prefix  <path>   : Pathname prefix (default is /data)"
    echo "  -u|--user    <name>   : Name of remote user if not '$user'"
    echo "  -x|--use-xfs          : Use XFS instead of default EXT4"
    echo "  -z|--zone   <zoneid>  : GCP zone of target, if GCP and not default"
    echo "  -V|--version          : Show version info and exit"
    echo ""
    echo "  eg. $TDH_PNAME -n 5 -x host1"
    echo "  Will format and mount 5 drives (sdb through sdf) "
    echo "  as /data01 through /data05"
    echo ""
}

rt=0
chars=( {b..z} )
maxvols=${#chars[@]}
ssh="ssh"
scp="scp"

while [ $# -gt 0 ]; do
    case "$1" in
        -D|--disknum)
            volnum=$2
            shift
            ;;
        -f|--force)
            force=1
            ;;
        -G|--use-gcp)
            usegcp=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -i|--identity)
            ident="$2"
            shift
            ;;
        -n|--dryrun)
            dryrun=1
            ;;
        -p|--prefix)
            pathpfx="$2"
            shift
            ;;
        -u|--user)
            user="$2"
            shift
            ;;
        -x|--use-xfs)
            usexfs=1
            ;;
        -z|--zone)
            zone="$2"
            shift
            ;;
        -V|--version)
            tdh_version
            exit 0
            ;;
        *)
            hosts="$@"
            shift $#
            ;;
    esac
    shift
done

if [ -z "$hosts" ]; then
    usage
    exit 1
fi

if [ $usegcp -eq 1 ]; then
    ssh="$GSSH"
    scp="$GSCP"
    if [ -n "$zone" ]; then
        ssh="$ssh --zone $zone"
        scp="$scp --zone $zone"
    fi
else
    if [ -n "$ident" ]; then
        ssh="$ssh -i $ident"
    fi
fi

hostssh=

for host in $hosts; do
    hostssh="$ssh"

    if [ $usegcp -eq 1 ]; then
        hostssh="$hssh $user@$host --command"
    else
        hostssh="$hostssh $user@$host"
    fi

    echo "( $scp ${tdh_path}/${format} ${user}@${host}: )"
    echo "( $hostssh 'chmod +x ./$format' )"
    if [ $dryrun -eq 0 ]; then
        ( $scp ${tdh_path}/${format} ${user}@${host}: )
        ( $hostssh 'chmod +x ./$format' )
    fi

    for (( i=0; i<$volnum; )); do
        device="/dev/${devtype}${chars[i++]}"
        dnum=$( printf "%02d" $i )
        mnt="/${pathpfx}${dnum}"

        cmd="$hostssh './$format"

        if [ $force -eq 1 ]; then
            cmd="$cmd --force"
        fi

        if [ $usexfs -eq 1 ]; then
            cmd="$cmd --use-xfs"
        fi

        cmd="$cmd $device $mnt'"

        echo "( $cmd )"
        if [ $dryrun -eq 0 ]; then
            ( $cmd )
            rt=$?
        fi

        if [ $rt -gt 0 ]; then
            echo "Error in $format"
            break
        fi
    done

    if [ $rt -gt 0 ]; then
        break
    fi
done

echo "$TDH_PNAME Finished."

exit $rt
