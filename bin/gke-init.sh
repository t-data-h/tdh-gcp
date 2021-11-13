#!/bin/bash
#
# Initialize a GKE cluster
#
# @author Timothy C. Arland <tcarland@gmail.com>
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../bin/tdh-gcp-env.sh ]; then
    . ${tdh_path}/../bin/tdh-gcp-env.sh
fi

# -----------------------------------

cluster=
nodecnt=3
zone="${GCP_ZONE:-${GCP_DEFAULT_ZONE}}"
mtype="${GCP_MACHINE_TYPE:-${GCP_DEFAULT_MACHINETYPE}}"
network="$GCP_NETWORK"
subnet="$GCP_SUBNET"
dsize="20GB"
ssd=0
async=0
ipalias=0
dryrun=0
private=

# -----------------------------------

usage="
Tool for initializing a GKE cluster.

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
   -P|--private <prefix> : Enable GCP private cluster mode and allow prefix.
   -S|--ssd              : Use 'pd-ssd' as GCP disk type.
   -t|--type <type>      : GCP Instance machine-type.
   -z|--zone <name>      : Sets an alternate GCP Zone.
   -V|--version          : Show Version Info and exit.
   
Where <action> is one of the following:
   create       : Initialize a new GKE Cluster
   delete       : Delete a GKE Cluster
   list         : List Clusters
   update       : Update a Private GKE Cluster
   get          : Get cluster credentials
   
  Default Machine Type is '$mtype'
  Default Boot Disk size  '$dsize'
  Default GCP Zone is     '$GCP_DEFAULT_ZONE'
   
The following environment variables are honored for overrides:
  GCP_MACHINE_TYPE, GCP_ZONE, GCP_NETWORK, GCP_SUBNET
"

# -----------------------------------

action=
rt=0

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
            echo "$usage"
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
        -P|--private*)
            private="$2"
            ipalias=1
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
        echo "$usage"
        exit 1
    fi

    args=("--machine-type=$mtype" "--disk-size=$dsize" "--num-nodes=$nodecnt")

    if [ $ssd -eq 1 ]; then
        args+=("--disk-type=pd-ssd")
    fi

    if [ -n "$subnet" ]; then
        if [ -z "$network" ]; then
            echo "Network must be defined!"
            exit 1
        fi
        args+=("--network $network" "--subnetwork $subnet")
    fi

    if [ $ipalias -eq 1 ]; then
        args+=("--enable-ip-alias")
    else
        args+=("--no-enable-ip-alias")
    fi

    if [ -n "$private" ]; then
	args+=("--enable-master-authorized-networks" 
	       "--enable-private-nodes"
	       "--no-enable-basic-auth" 
	       "--no-issue-client-certificate"
	       "--master-authorized-networks ${private}"
	       "--master-ipv4-cidr 172.16.10.16/28")
    fi

    echo "( gcloud container clusters create $cluster ${args[@]} )"
    if [ $dryrun -eq 0 ]; then
        ( gcloud container clusters create $cluster ${args[@]} )
    fi
    ;;

update)
    if [ -z "$cluster" ]; then
        echo "Name of cluster is required."
        echo "$usage"
        exit 1
    fi
    if [ -n "$private" ]; then
        ( gcloud container clusters update $cluster --enable-master-authorized-networks --master-authorized-networks=$private )
    fi
    ;;

del|delete|destroy)
    if [ -z "$cluster" ]; then
        echo "Name of cluster is required."
        exit 1
    fi
    echo "( gcloud container clusters delete $cluster )"
    if [ $dryrun -eq 0 ]; then
        ( gcloud container clusters delete $cluster )
    fi
    ;;

list)
    ( gcloud container clusters list )
    ;;

describe|info)
    if [ -z "$cluster" ]; then
        echo "Name of cluster is required."
        exit 1
    fi
    ( gcloud container clusters describe $cluster )
    ;;

get)
    if [ -z "$cluster" ]; then
        echo "Name of cluster is required."
        exit 1
    fi
    ( gcloud container clusters get-credentails $cluster )
    ;;

help)
    echo "$usage"
    ;;

*)
    echo "Action not recognized."
    echo ""
    echo "$usage"
    ;;
esac

rt=$?
exit $rt
