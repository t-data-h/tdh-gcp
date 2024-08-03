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
tags=

# private cluster options
master_ipv4="172.16.10.0/28"
cluster_ipv4="10.12.0.0/16"
services_ipv4="10.10.128.0/20"
cluster_vers=

# -----------------------------------

usage="
Tool for initializing a GKE cluster.

Synopsis:
  $TDH_PNAME [options] <action> <cluster_name>

Options:
   -a|--async               : Run actions asynchronously.
   -A|--ipalias             : Enables ip-alias during cluster creation.
   -c|--count    <cnt>      : Number of nodes to deploy, Default is $nodecnt.
   -h|--help                : Display usage info and exit.
   -d|--disksize <xxGB>     : Size of boot disk. Default is $dsize.
      --dryrun              : Enable dryrun.
   -N|--network  <name>     : Name of GCP Network if not default.
   -n|--subnet   <name>     : Name of GCP Subnet if not default.
   -P|--private  <cidr,..>  : Set as private cluster by defining allow prefixes.
                              The list of networks is a comma delimited list.
   -S|--ssd                 : Use 'pd-ssd' as GCP disk type.
   -t|--type     <type>     : GCP Instance machine-type.
   -T|--tags     <tag1,..>  : List of Compute Engine tags to apply to nodes.
   -z|--zone     <name>     : Sets an alternate GCP Zone.
   -V|--version             : Show Version Info and exit.
   
Where <action> is one of the following:
    create      <name>      : Initialize a new GKE Cluster
    delete      <name>      : Delete a GKE Cluster
    list                    : List Clusters
    update <name> <cidr1,>  : Update a private cluster 'master-authorized-networks'.
                              The provided list is an overwrite, not an append.
    get-credentials <name>  : Get cluster credentials

The following environment variables are honored for overrides:
    GCP_MACHINE_TYPE, GCP_ZONE, GCP_NETWORK, GCP_SUBNET

When GCP Private Clusters are used, the various internal CIDR blocks can be 
customized with the following settings:
  --cluster-ipv4-cidr  <cidr>  : Set the cluster network, default=$cluster_ipv4
  --master-ipv4-cidr   <cidr>  : Set the master network, default=$master_ipv4 
  --services-ipv4-cidr <cidr>  : Set the services network, default=$services_ipv4
                                 requires --ipalias to be set.
  --cluster-version    <vers>  : Override GKE K8s default version.
    Use 'gcloud container get-server-config' to see available versions.

Default Machine Type is '$mtype'
Default Boot Disk size  '$dsize'
Default GCP Zone is     '$GCP_DEFAULT_ZONE'
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
        --cluster-version)
            cluster_vers="$2"
            shift
            ;;
        --cluster-ipv4-cidr)
            cluster_ipv4="$2"
            shift
            ;;
        --master-ipv4-cidr)
            master_ipv4="$2"
            shift
            ;;
        --services-ipv4-cidr)
            services_ipv4="$2"
            shift
            ;;
        -d|--disksize)
            dsize="$2"
            shift
            ;;
        --dryrun|--dry-run)
            dryrun=1
            echo "   <DRYRUN> enabled"
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
        -T|--tags)
            tags="$2"
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

if [ -z "$GCP" ]; then
    echo "$TDH_PNAME ERROR, gcloud not available" >&2
    exit 1
fi

cluster_vers=$(gcloud container get-server-config 2>/dev/null | \
  grep 'defaultClusterVersion:' | \
  awk -F: '{ print $2 }' | sed 's/^[[:space:]]*//')

case "$action" in
create)
    if [ -z "$cluster" ]; then
        echo "$TDH_PNAME ERROR, name of cluster is required." >&2
        exit 1
    fi

    args=("--machine-type=$mtype" "--disk-size=$dsize" "--num-nodes=$nodecnt")

    if [ $ssd -eq 1 ]; then
        args+=("--disk-type=pd-ssd")
    fi

    if [ -n "$cluster_vers" ]; then
        args+=("--cluster-version=${cluster_vers}")
    fi

    if [ -n "$subnet" ]; then
        if [ -z "$network" ]; then
            echo "$TDH_PNAME ERROR, Network must be defined!" >&2
            exit 2
        fi
        args+=("--network $network" "--subnetwork $subnet")
    fi

    if [ $ipalias -eq 1 ]; then
        args+=("--enable-ip-alias")
    else
        args+=("--no-enable-ip-alias")
    fi

    if [ -n "$private" ]; then
	    args+=("--enable-private-nodes"
               "--enable-master-authorized-networks" 
	           "--no-enable-basic-auth" 
	           "--no-issue-client-certificate"
	           "--master-authorized-networks=${private}"
	           "--master-ipv4-cidr=${master_ipv4}"
               "--cluster-ipv4-cidr=${cluster_ipv4}")
        if [ $ipalias -eq 1 ]; then
            args+=("--services-ipv4-cidr=${services_ipv4}")
        fi
    fi

    echo "( gcloud container clusters create $cluster ${args[@]} )"

    if [ $dryrun -eq 0 ]; then
        ( gcloud container clusters create $cluster ${args[@]} )
    fi
    ;;

update)
    if [ -z "$cluster" ]; then
        echo "$TDH_PNAME ERROR, name of cluster is required." >&2
        exit 1
    fi
    if [ -z "$private" ]; then
        echo "$TDH_NAME ERROR, private access addresses not provided." >&2
        exit 1

    ( gcloud container clusters update $cluster --enable-master-authorized-networks --master-authorized-networks=$private )
    ;;

del|delete|destroy)
    if [ -z "$cluster" ]; then
        echo "$TDH_PNAME ERROR, name of cluster is required." >&2
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
        echo "$TDH_PNAME ERROR, name of cluster is required." >&2
        exit 1
    fi
    ( gcloud container clusters describe $cluster )
    ;;

get-cred*|get)
    if [ -z "$cluster" ]; then
        echo "$TDH_PNAME ERROR, name of cluster is required." >&2
        exit 1
    fi
    ( gcloud container clusters get-credentials $cluster )
    ;;

help)
    echo "$usage"
    ;;

*)
    echo "$TDH_PNAME ERROR, Action not recognized." >&2
    echo ""
    echo "$usage"
    ;;
esac

rt=$?
exit $rt
