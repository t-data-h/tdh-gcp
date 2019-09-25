#!/bin/bash
#
#  Initialize worker GCP instances.
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../etc/tdh-gcp-config.sh ]; then
    . ${tdh_path}/../etc/tdh-gcp-config.sh
fi

# -----------------------------------

names="d01 d02 d03 d04"
prefix="$TDH_GCP_PREFIX"

zone=
mtype="n1-highmem-16"
bootsize="$GCP_DEFAULT_BOOTSIZE"
disksize="$GCP_DEFAULT_DISKSIZE"
master_id="master-id_rsa.pub"
master_id_file="${tdh_path}/../ansible/.ansible/${master_id}"
network="tdh-net"
subnet="tdh-net-west1"

myid=1
attach=0
dryrun=0
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
    echo "Usage: $TDH_PNAME [options] <run>  host1 host2 ..."
    echo "  -A|--attach           : Create an attached volume"
    echo "  -b|--bootsize <xxGB>  : Size of boot disk in GB, Default is $bootsize"
    echo "  -d|--disksize <xxGB>  : Size of attached disk, Default is $disksize"
    echo "  -h|--help             : Display usage and exit"
    echo "  -N|--network <name>   : GCP Network name. Default is $network"
    echo "  -n|--subnet <name>    : GCP Network subnet name. Default is $subnet"
    echo "  -p|--prefix <name>    : Prefix name to use for instances"
    echo "                          Default prefix is '$prefix'"
    echo "  -S|--ssd              : Use SSD as attached disk type"
    echo "  -t|--type             : Machine type to use for instance(s)"
    echo "                          Default is '$mtype'"
    echo "  -z|--zone <name>      : Set GCP zone to use, if not gcloud default."
    echo ""
    echo " Where <action> is 'run' or other, where any other action enables a "
    echo " dryrun,followed by a list of names that become '\$prefix-\$name'."
    echo " eg. '$TDH_PNAME test d01 d02 d03' will dryrun 3 worker nodes with"
    echo " the names: $prefix-d01, $prefix-d02, and $prefix-d03"
    echo ""
}


# Main
#

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
        --dryrun)
            dryrun=1
            ;;
        -N|--network)
            network="$2"
            shift
            ;;
        -n|--subnet)
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
            tdh_version
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
    tdh_version
    usage
    exit 1
fi

if [ -n "$network" ] && [ -z "$subnet" ]; then
    echo "Error! Subnet must be provided with --network"
    exit 1
fi

echo ""
tdh_version

if [ "$action" == "run" ] && [ $dryrun -eq 0 ]; then
    dryrun=0
else
    dryrun=1  # action -ne run
    echo "  <DRYRUN> enabled"
fi

if [ -n "$zone" ]; then
    GSSH="$GSSH --zone $zone"
    GSCP="$GSCP --zone $zone"
fi

if [ -n "$namelist" ]; then
    names="$namelist"
else
    echo "Using default of 4 worker instances"
fi

echo "Creating worker instance '$mtype' for { $names }"
echo ""


for name in $names; do
    #
    # Create instance
    host="${prefix}-${name}"
    cmd="${tdh_path}/tdh-gcp-compute.sh --prefix $prefix --type $mtype --bootsize $bootsize"
    
    if [ -n "$network" ]; then
        cmd="$cmd --network $network --subnet $subnet"
    fi
    if [ -n "$zone" ]; then
        cmd="$cmd --zone ${zone}"
    fi
    if [ $dryrun -gt 0 ]; then
        cmd="${cmd} --dryrun"
    fi
    if [ $attach -gt 0 ]; then
        cmd="${cmd} --attach --disksize $disksize"
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
echo " -> Waiting for last host to respond. ."

if [ $dryrun -eq 0 ]; then
    wait_for_gcphost "$host"
    rt=$?
else
    echo "  <DRYRUN skipped>"
fi
echo ""

if [ $rt -ne 0 ]; then
    echo "Error in wait_for_gcphost(), no response from host or timed out"
    echo "Will attempt to continue in 3...2.."
    sleep 3
fi

for name in $names; do
    host="${prefix}-${name}"

    #
    # Device format and mount
    if [ $attach -gt 0 ]; then
        device="/dev/sdb"
        mountpoint="/data1"

        echo "( $GSSH ${host} --command './tdh-gcp-format.sh $device $mountpoint' )"

        if [ $dryrun -eq 0 ]; then
            ( $GSCP ${tdh_path}/tdh-gcp-format.sh ${host}: )
            ( $GSSH $host --command 'chmod +x tdh-gcp-format.sh' )
            ( $GSSH $host --command "./tdh-gcp-format.sh $device $mountpoint" )
        fi

        rt=$?
        if [ $rt -gt 0 ]; then
            echo "Error in tdh-gcp-format for $host"
            break
        fi
    fi

    #
    # disable  iptables and cups
    echo "( $GSSH $host --command 'sudo systemctl stop firewalld; sudo systemctl disable firewalld; sudo service cups stop; sudo chkconfig cups off' )"

    if [ $dryrun -eq 0 ]; then
        ( $GSSH $host --command "sudo systemctl stop firewalld; sudo systemctl disable firewalld; sudo service cups stop; sudo chkconfig cups off" )
    fi


    #
    # prereq's
    echo "( $GSSH $host --command ./tdh-prereqs.sh )"

    if [ $dryrun -eq 0 ]; then
        ( $GSCP ${tdh_path}/../etc/bashrc ${host}:.bashrc )
        ( $GSCP ${tdh_path}/tdh-prereqs.sh ${host}: )
        ( $GSSH $host --command 'chmod +x tdh-prereqs.sh' )
        ( $GSSH $host --command ./tdh-prereqs.sh )
    fi

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in tdh-prereqs for $host"
        break
    fi


    #
    # ssh
    echo "( $GSCP ${master_id_file} ${host}:.ssh" 

    if [ $dryrun -eq 0 ]; then
        ( $GSCP ${master_id_file} ${host}:.ssh/ )
        ( $GSSH $host --command "cat .ssh/${master_id} >> .ssh/authorized_keys; chmod 700 .ssh; chmod 600 .ssh/authorized_keys " )
    fi

    # mysql client
    role="client"
    cmd="${tdh_path}/tdh-mysql-install.sh"

    if [ -n "$zone" ]; then
        cmd="$cmd --zone $zone"
    fi

    echo "( $cmd $host $role )"
    if [ $dryrun -eq 0 ]; then
        ( $cmd $host $role )
    fi
    
    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in tdh-mysql-install for $host"
        break
    fi

    echo "Initialization complete for $host"
    echo ""
done

echo "$TDH_PNAME finished"
exit $rt
