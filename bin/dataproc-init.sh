#!/bin/bash
#
#  gcp-dataproc.sh -  Manage GCP Dataproc Clusters
#
#  @author Timothy C. Arland <tcarland at gmail dot com>
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../bin/tdh-gcp-env.sh ]; then
    . ${tdh_path}/../bin/tdh-gcp-env.sh
fi

# -----------------------------------

prefix="$TDH_GCP_PREFIX"
zone="${GCP_ZONE:-${GCP_DEFAULT_ZONE}}"
region="${GCP_REGION:-${GCP_DEFAULT_REGION}}"
master_mtype="${GCP_MACHINE_TYPE:-n4-standard-2}"
master_boottype="hyperdisk-balanced"
master_bootsize="$GCP_DEFAULT_BOOTSIZE"
worker_mtype="${GCP_MACHINE_TYPE:-n4-standard-4}"
worker_boottype="hyperdisk-balanced"
worker_bootsize="$GCP_DEFAULT_BOOTSIZE"
master_count=1
worker_count=4  
dataproc_image_version="2.2-debian12"
dataproc_properties=":=,spark:spark.dataproc.enhanced.optimizer.enabled=true,dataproc:dataproc.cluster.caching.enabled=true"
dataproc_max_idle="60m"
network="$GCP_NETWORK"
subnet="$GCP_SUBNET"

name=
action=

# -----------------------------------

usage="
Tool for initializing a GCP Dataproc cluster.

Synopsis:
  $TDH_PNAME [options] <action> <cluster_name>

Options:
   -h|--help                : Display usage info and exit.
   -b|--bootsize <xxGB>     : Size of boot disk. Default is '$master_bootsize'.
   -d|--disksize <xxGB>     : Size of worker boot disk. Default is '$worker_bootsize'.
   -i|--max-idle  <xxm>     : Dataproc cluster max idle time. Default is '$dataproc_max_idle'.
   -N|--network  <name>     : Name of GCP Network if not default.
   -n|--subnet   <name>     : Name of GCP Subnet if not default.
   -m|--masters   <cnt>     : Number of master nodes to deploy, Default is '$master_count'.
   -t|--type     <type>     : Worker Instance machine-type, Default is '$worker_mtype'.
   -T|--mtype    <type>     : Master Instance machine-type, Default is '$master_mtype'.
   -w|--workers   <cnt>     : Number of worker nodes to deploy, Default is '$worker_count'.
   -z|--zone     <name>     : Sets an alternate GCP Zone from default of '$GCP_DEFAULT_ZONE'.
   -V|--version             : Show Version Info and exit.

Where <action> is one of the following:
    create    : Create a new Dataproc cluster.
    start     : Start a Dataproc cluster.
    stop      : Stop a Dataproc cluster.
    delete    : Delete a Dataproc cluster.
    list      : List Dataproc clusters.

Default GCP Zone:    '$zone'
"


# -----------------------------------

action=
rt=0

while [ $# -gt 0 ]; do
    case "$1" in
        -a|--async)
            async=1
            ;;
        -b|--bootsize)
            master_bootsize="$2"
            shift
            ;;
        -d|--disksize)
            worker_bootsize="$2"
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
        -i|--max-idle)
            dataproc_max_idle="$2"
            shift
            ;;
        -m|--masters)
            master_count="$2"
            shift
            ;;
        -w|--workers)
            worker_count="$2"
            shift
            ;;
        -t|--type)
            worker_mtype="$2"
            shift
            ;;
        -T|--mtype)
            master_mtype="$2"
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

if [ -z "$zone" ]; then
    echo "$TDH_PNAME Error, zone is required" >&2
    exit 2
fi


case "$action" in

##      CREATE
create)
    if [ -z "$cluster" ]; then
        echo "$TDH_PNAME Error, cluster name is required for create action." >&2
        exit 3
    fi

    echo "Creating Dataproc cluster '$cluster' in zone '$zone' with $worker_count workers..."

    gcloud dataproc clusters create "$cluster" \
        --enable-component-gateway \
        --region "$retion" \
        --zone "$zone" \
        --subnet "$subnet" \
        --num-masters "$master_count" \
        --master-machine-type "$master_mtype" \
        --master-boot-disk-type "$master_boottype" \
        --master-boot-disk-size "$master_bootsize" \
        --num-workers "$worker_count" \
        --worker-machine-type "$worker_mtype" \
        --worker-boot-disk-type "$worker_boottype" \
        --worker-boot-disk-size "$worker_bootsize" \
        --image-version "$dataproc_image_version" \
        --properties "$dataproc_properties" \
        --stop-max-idle "$dataproc_max_idle" \
        --optional-components ICEBERG,DELTA \
        --scopes "https://www.googleapis.com/auth/cloud-platform" \
        --project "$GCP_PROJECT_NAME" 
    ;;

##     STOP
stop)
    if [ -z "$cluster" ]; then
        echo "$TDH_PNAME Error, cluster name is required for delete action." >&2
        exit 3
    fi

    echo "Stopping Dataproc cluster '$cluster' in zone '$zone'..."
    gcloud dataproc clusters stop "$cluster" \
        --region "$region" \
        --zone "$zone" \
        --project "$GCP_PROJECT_NAME"
    ;;

##    START
start)
    if [ -z "$cluster" ]; then
        echo "$TDH_PNAME Error, cluster name is required for start action." >&2
        exit 3
    fi 

    echo "Starting Dataproc cluster '$cluster' in zone '$zone'..."
    gcloud dataproc clusters start "$cluster" \
        --region "$region" \
        --zone "$zone" \
        --project "$GCP_PROJECT_NAME"
    ;;

##    DELETE
delete)
    if [ -z "$cluster" ]; then
        echo "$TDH_PNAME Error, cluster name is required for delete action." >&2
        exit 3
    fi

    echo "Deleting Dataproc cluster '$cluster' in zone '$zone'..."
    gcloud dataproc clusters delete "$cluster" \
        --region "$region" \
        --zone "$zone" \
        --project "$GCP_PROJECT_NAME"
    ;;

##    LIST
list)
    echo "Listing Dataproc clusters in zone '$zone'..."
    gcloud dataproc clusters list \
        --region "$region" \
        --zone "$zone" \
        --project "$GCP_PROJECT_NAME"
    ;;
*)
    echo "$TDH_PNAME Error, unknown action '$action'." >&2
    echo "$usage"
    exit 4
    ;;

esac

exit $?