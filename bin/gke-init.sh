#!/bin/bash
#
# Initialize a GKE cluster
#
#  @author Timothy C. Arland <tcarland@gmail.com>
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../bin/tdh-gcp-config.sh ]; then
    . ${tdh_path}/../bin/tdh-gcp-config.sh
fi

# -----------------------------------

gke="gcloud container"
cluster=
nodecnt=3
mtype="n1-standard-2"  # e2-medium = 2 x 4G
dsize="20GB"
ssd=0
network=
subnet=
zone="$GCP_ZONE"
async=0
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

usage="
Script for initializing a GKE cluster.

Synopsis:
  $TDH_PNAME [options] <action> <cluster_name>

Options:
   -a|--async            : Run actions asynchronously.
   -A|--ipalias          : Enables ip-alias during cluster creation.
   -c|--count <cnt>      : Number of nodes to deploy, Default is $nodecnt.
   -h|--help             : Display usage info and exit.
   -d|--disksize <xxGB>  : Size of boot disk. Default is $dsize.
      --dryrun           : Enable dryrun.
   -N|--network <name>   : Name of GCP Network if not default.
   -n|--subnet <name>    : Name of GCP Subnet if not default.
   -S|--ssd              : Use 'pd-ssd' as GCP disk type.
   -t|--type <type>      : GCP Instance machine-type.
   -z|--zone <name>      : Sets an alternate GCP Zone.
   -V|--version          : Show Version Info and exit.
   
Where <action> is one of the following:
   create       : Initialize a new GKE cluster
   delete       : Delete a GKE cluster
   
  Default Machine Type is '$mtype'
  Default Boot Disk size  '$dsize'
  Default GCP Zone is     '$GCP_DEFAULT_ZONE'
   
The following environment variables are honored for overrides:
  GCP_MACHINE_TYPE, GCP_ZONE, GCP_NETWORK, GCP_SUBNET
"


# -----------------------------------

action=
rt=0
cmd=

while [ $# -gt 0 ]; do
    case "$1" in
        -a|--async)
            async=1
            ;;
        -A|--ip-alias)
            ipalias=1
            ;;
        -c|--count)
            nodecnt=$2
            shift
            ;;
        -d|--disksize)
            dsize="$2"
            shift
            ;;
        --dryrun|--dry-run)
            dryrun=1
            echo " <DRYRUN> enabled"
            ;;
        'help'|-h|--help)
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
        -S|--ssd)
            ssd=1
            ;;
        -t|--type)
            mtype="$2"
            shift
            ;;
        -z|--zone)
            zone="$2"
            shift
            ;;
        'version'|-V|--version)
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

case "$action" in
create)
    if [ -z "$cluster" ]; then
        echo "Name of cluster is required."
        usage
        exit 1
    fi

    cmd="$gke"
    cmd="$cmd clusters create $cluster --machine-type=$mtype --disk-size=$dsize --num-nodes=$nodecnt"

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

    if [ $ipalias -eq 1 ]; then
        cmd="$cmd --enable-ip-alias"
    else
        cmd="$cmd --no-enable-ip-alias"
    fi

    echo "( $cmd )"
    if [ $dryrun -eq 0 ]; then
        ( $cmd )
    fi
    ;;

del|delete|destroy)
    cmd="$gke clusters delete $cluster"

    echo "( $cmd )"
    if [ $dryrun -eq 0 ]; then
        ( $cmd )
    fi
    ;;
list)
    ( $gke clusters list )
    ;;
describe|info)
    ( $gke clusters describe $cluster )
    ;;
help)
    usage
    ;;
*)
    echo "Action not recognized."
    echo ""
    ;;
esac

rt=$?

exit $rt
