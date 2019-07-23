#!/bin/bash
#
#  Initialize worker GCP instances.
#
PNAME=${0##*\/}
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/tdh-gcp-config.sh ]; then
    . ${tdh_path}/tdh-gcp-config.sh
fi

# -----------------------------------

names="d01 d02 d03"
prefix="$TDH_GCP_PREFIX"

zone="$GCP_DEFAULT_ZONE"
mtype="n1-highmem-8"
bootsize="$GCP_DEFAULT_BOOTSIZE"
disksize="$GCP_DEFAULT_DISKSIZE"
master_id="master-id_rsa.pub"
master_id_file="${tdh_path}/../ansible/.ansible/${master_id}"
network="tdh-net"
subnet="tdh-net-west1"

myid=1
attach=0
dryrun=1
ssd=0
action=
rt=

# ----------------------------------
# Default overrides

if [ -n "$GCP_ZONE" ]; then
    zone="$GCP_ZONE"
fi

if [ -n "$GCP_MACHINE_TYPE" ]; then
    mtype="$GCP_MACHINE_TYPE"
fi

if [ -n "$GCP_NETWORK" ]; then
    network="$GCP_NETWORK"
fi

if [ -n "$GCP_SUBNET" ]; then 
    subnet="$GCP_SUBNET" 
fi

# -----------------------------------

usage() {
    echo ""
    echo "Usage: $PNAME [options] <run>  host1 host2 ..."
    echo "  -A|--attach           : Create an attached volume"
    echo "  -b|--bootsize <xxGB>  : Size of boot disk in GB, Default is $bootsize"
    echo "  -d|--disksize <xxGB>  : Size of attached disk, Default is $disksize"
    echo "  -h|--help             : Display usage and exit"
    echo "  -N|--network <name>   : GCP Network name. Default is $network"
    echo "  -s|--subnet <name>    : GCP Network subnet name. Default is $subnet"
    echo "  -p|--prefix <name>    : Prefix name to use for instances"
    echo "                          Default prefix is '$prefix'"
    echo "  -S|--ssd              : Use SSD as attached disk type"
    echo "  -t|--type             : Machine type to use for instance(s)"
    echo "                          Default is '$mtype'"
    echo "  -z|--zone <name>      : Set GCP zone to use. Default is '$zone'"
    echo ""
    echo " Where <action> is 'run' or other, where any other action enables a "
    echo " dryrun,followed by a list of names that become '\$prefix-\$name'."
    echo " eg. '$PNAME test d01 d02 d03' will dryrun 3 worker nodes with"
    echo " the names: $prefix-d01, $prefix-d02, and $prefix-d03"
    echo ""
}


version()
{
    echo "$PNAME: v$TDH_GCP_VERSION"
}



while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -A|--attach)
            attach=1
            ;;
        -b|--bootsize)
            bootsize="$2"
            shift
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
        -N|--network)
            network="$2"
            shift
            ;;
        -s|--subnet)
            subnet="$2"
            shift
            ;;
        -S|-ssd)
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
        -V|--version)
            version
            exit 0
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

if [ -z "$action" ]; then
    version
    usage
    exit 1
fi

if [ "$action" == "run" ]; then
    dryrun=0
else
    echo "  <DRYRUN> enabled"
fi

if [ -n "$namelist" ]; then
    names="$namelist"
else
    echo "Using default 3 workers"
fi

echo "Creating worker instances for '$names'"
echo ""


for name in $names; do
    #
    # Create instance
    host="${prefix}-${name}"
    cmd="${tdh_path}/tdh-gcp-compute.sh --prefix ${prefix} --network ${network} --subnet ${subnet} --type ${mtype} --bootsize ${bootsize}"

    if [ $dryrun -gt 0 ]; then
        cmd="${cmd} --dryrun"
    fi
    if [ $attach -gt 0 ]; then
        cmd="${cmd} --attach --disksize ${disksize}"
    fi
    if [ $ssd -gt 0 ]; then
        cmd="${cmd} --ssd"
    fi

    cmd="${cmd} create ${name}"
    echo "( $cmd )"

    ( $cmd )

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in GCP initialization of $host"
        break
    fi
done

if [ $rt -gt 0 ]; then
    exit $rt
fi
echo ""
if [ $dryrun -eq 0 ]; then
    echo "Brief sleep... "
    sleep 5
fi

for name in $names; do
    #
    # Device format and mount
    host="${prefix}-${name}"
    if [ $attach -gt 0 ]; then
        device="/dev/sdb"
        mountpoint="/data1"
        echo "( gcloud compute ssh ${host} --command './tdh-gcp-format.sh $device $mountpoint' )"
        if [ $dryrun -eq 0 ]; then
            ( gcloud compute scp ${tdh_path}/tdh-gcp-format.sh ${host}: )
            ( gcloud compute ssh ${host} --command 'chmod +x tdh-gcp-format.sh' )
            ( gcloud compute ssh ${host} --command "./tdh-gcp-format.sh $device $mountpoint" )
        fi

        rt=$?
        if [ $rt -gt 0 ]; then
            echo "Error in tdh-gcp-format for $host"
            break
        fi
    fi

    #
    # disable  iptables and cups
    echo "( gcloud compute ssh $host --command 'sudo systemctl stop firewalld; sudo systemctl disable firewalld; sudo service cups stop; sudo chkconfig cups off' )"
    if [ $dryrun -eq 0 ]; then
        ( gcloud compute ssh $host --command "sudo systemctl stop firewalld; sudo systemctl disable firewalld; sudo service cups stop; sudo chkconfig cups off" )
    fi


    #
    # prereq's
    echo "( gcloud compute ssh ${host} --command ./tdh-prereqs.sh )"
    if [ $dryrun -eq 0 ]; then
        ( gcloud compute scp ${tdh_path}/../etc/bashrc ${host}:.bashrc )
        ( gcloud compute scp ${tdh_path}/tdh-prereqs.sh ${host}: )
        ( gcloud compute ssh ${host} --command 'chmod +x tdh-prereqs.sh' )
        ( gcloud compute ssh ${host} --command ./tdh-prereqs.sh )
    fi

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in tdh-prereqs for $host"
        break
    fi


    #
    # ssh
    echo "( gcloud compute scp ${master_id_file} ${host}:.ssh" 
    if [ $dryrun -eq 0 ]; then
        ( gcloud compute scp ${master_id_file} ${host}:.ssh/ )
        ( gcloud compute ssh ${host} --command "cat .ssh/${master_id} >> .ssh/authorized_keys; chmod 700 .ssh; chmod 600 .ssh/authorized_keys " )
    fi

    echo "Initialization complete for $host"
    echo ""
done

echo "$PNAME finished"
exit $rt
