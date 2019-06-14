#!/bin/bash
#
#  Initialize our master instances
PNAME=${0##*\/}
tdh_path=$(dirname "$(readlink -f "$0")")

prefix="tdh"
names="m01 m02 m03"
mtype="n1-standard-4"
zone="us-west1-b"
disksize="200GB"
dryrun=1
action=
rt=

usage() {
    echo ""
    echo "Usage: $PNAME [options] <run>"
}


while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -d|--disksize)
            disksize="$2"
            shift
            ;;
        -p|--prefix)
            prefix="$2"
            shift
            ;;
        -n|--dryrun)
            dryrun=1
            ;;
        -t|--type)
            mtype="$2"
            shift
            ;;
        -z|--zone)
            zone="$2"
            shift
            ;;
        -V|--version)
            version
            exit 0
            ;;
        -y|--no-prompt)
            noprompt=1
            ;;
        *)
            action="$1"
            shift
            namelist="$@"
            shift $#
            ;;
    esac
    shift
done

if [ "$action" == "run" ]; then
    dryrun=0
else 
    echo "  <DRYRUN> enabled"
fi

if [ -n "$namelist" ]; then
    names="$namelist"
fi

echo "Creating masters for '$names'"
echo ""

for name in $names; do
    host="${prefix}-${name}"
   
    echo "( $tdh_path/bin/tdh-gcp-compute.sh --prefix ${prefix} --type $mtype --attach --disksize $disksize create ${name} )"
    if [ $dryrun -eq 0 ]; then
        ( $tdh_path/bin/tdh-gcp-compute.sh --prefix ${prefix} --type $mtype --attach --disksize $disksize create ${name} )
    fi

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in GCP initialization of $host" 
        break
    fi

    # Device format and mount
    device="/dev/sdb"
    mountpoint="/data"

    echo "( gcloud compute ssh ${host} < ${tdh_path}/bin/tdh-gcp-format.sh $device $mountpoint )"
    if [ $dryrun -eq 0 ]; then
        ( gcloud compute ssh ${host} < ${tdh_path}/bin/tdh-gcp-format.sh $device $mountpoint )
    fi

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in tdh-gcp-format for $host"
        break
    fi

    # prereq's
    #sudo yum install -y java-1.8.0-openjdk wget tmux
    #sudo yum erase mariadb-libs
    echo "Initialization complete for $host"
    echo ""
done

echo "$PNAME finished"
exit $rt