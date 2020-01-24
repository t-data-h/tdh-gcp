#!/bin/bash
#
# Initialize a GKE cluster
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/tdh-gcp-config.sh ]; then
    . ${tdh_path}/tdh-gcp-config.sh
fi

# -----------------------------------

gke="gcloud container"
cluster=
nodes=3
mtype="n1-standard-2"  # e2-medium = 2 x 4G
dsize="20GB"
ssd=0
network=
subnet=
zone="$GCP_ZONE"
ipalias=0
dryrun=0

# -----------------------------------
# default overrides

if [ -n "$GCP_MACHINE_TYPE" ]; then
    mtype="$GCP_MACHINE_TYPE"
fi

if [ -n "$GCP_NETWORK" ]; then
    network="$GCP_NETWORK"
fi

if [ -n "$GCP_SUBNET" ]; then
    subnet="$GCP_SUBNET"
fi

if [ -z "$zone" ]; then
    zone="$GCP_DEFAULT_ZONE"
fi

# -----------------------------------

usage() {
    echo ""
    echo "Usage: $TDH_PNAME [options] <action> <cluster_name>"
    echo " -a|--ipalias          : Enables ip-alias during cluster creation"
    echo " -c|--count <cnt>      : Number of nodes to deploy, Default is $nodes"
    echo " -h|--help             : Display usage info and exit"
    echo " -d|--disksize <xxGB>  : Size of boot disk. Default is $dsize"
    echo " --dryrun              : Enable dryrun"
    echo " -N|--network <name>   : Name of GCP Network if not default"
    echo " -n|--subnet <name>    : Name of GCP Subnet if not default"
    echo " -t|--type <type>      : GCP Instance machine-type"
    echo " -S|--ssd              : Use 'pd-ssd' as GCP disk type"
    echo " -z|--zone <name>      : Sets an alternate GCP Zone"
    echo " -V|--version          : Show Version Info and exit"
    echo ""
    echo "  Where <action> is one of the following:"
    echo "     create            : Initialize a new GKE cluster"
    echo "     delete            : Delete a GKE cluster"
    echo ""
    echo "  Default Machine Type is '$mtype'"
    echo "  Default Boot Disk size  '$dsize'"
    echo "  Default GCP Zone is     '$GCP_DEFAULT_ZONE'"
    echo ""
    echo " The following environment variables are honored for overrides:"
    echo "  GCP_MACHINE_TYPE, GCP_ZONE, GCP_NETWORK, GCP_SUBNET"
    echo ""
}

# -----------------------------------

action=
rt=0
cmd="$gke"

while [ $# -gt 0 ]; do
    case "$1" in
        -a|--ip-alias)
            ipalias=1
            ;;
        -c|--count)
            nodes=$2
            shift
            ;;
        -S|--ssd)
            ssd=1
            ;;
        -d|--disksize)
            dsize="$2"
            shift
            ;;
        --dryrun)
            dryrun=1
            echo " <DRYRUN> enabled"
            ;;
        -h|--help)
            usage
            exit $rt
            ;;
        -N|--network)
            network="$2"
            shift
            ;;
        -n|--subnet)
            subnet="$2"
            shift
            ;;
        -V|--version)
            tdh_version
            exit $rt
            ;;
        *)
            action="$1"
            cluster="$2"
            shift $#
            ;;
    esac
    shift
done


if [ -z "$cluster" ]; then
    echo "Name of cluster is required."
    usage
    exit 1
fi

if [ "$action" == "create" ]; then

    cmd="$cmd clusters create $cluster --machine-type=$type --disk-size=$dsize --num-nodes=$nodes"

    if [ $ssd -eq 1 ]; then
        cmd="$cmd --disk-type=pd-ssd"
    fi

    if [ -n "$subnet" ]; then
        if [ -z "$network" ]; then
            echo "Network must be defined!"
            exit 1
        fi
        cmd="$cmd --network $network --subnetwork $subnet"
    fi

    if [ ipalias -eq 1 ]; then
        cmd="$cmd --enable-ip-alias"
    else
        cmd="$cmd --no-enable-ip-alias"
    fi

    echo "( $cmd )"
    if [ $dryrun -eq 0 ]; then
        ( $cmd )
    fi

elif [ "$action" == "delete" ]; then

    cmd = "$cmd clusters delete $cluster"

    echo "( $cmd )"
    if [ $dryrun -eq 0 ]; then
        ( $cmd )
    fi
fi

rt=$?

exit $rt
