#!/bin/bash
#
#  Initialize master GCP instances.
#
PNAME=${0##*\/}
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../etc/tdh-gcp-config.sh ]; then
    . ${tdh_path}/../etc/tdh-gcp-config.sh
fi

# -----------------------------------

names="m01 m02"
prefix="$TDH_GCP_PREFIX"

zone="$GCP_DEFAULT_ZONE"
mtype="$GCP_DEFAULT_MACHINETYPE"
bootsize="$GCP_DEFAULT_BOOTSIZE"
disksize="$GCP_DEFAULT_DISKSIZE"
master_id="master-id_rsa.pub"
master_id_file="${tdh_path}/../ansible/.ansible/${master_id}"
network="tdh-net"
subnet="tdh-net-west1"

myid=1
dryrun=1
noprompt=0
attach=0
ssd=0
pwfile=
action=
rt=

# -----------------------------------
# default overrides

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
    echo "  -b|--bootsize <xxGB>  : Size of boot disk, Default is $bootsize"
    echo "  -d|--disksize <xxGB>  : Size of attached disk, Default is $disksize"
    echo "  -h|--help             : Display usage and exit"
    echo "  -p|--prefix <name>    : Prefix name to use for instances"
    echo "                          Default prefix is '$prefix'"
    echo "  -P|--pwfile <file>    : File containing mysql root password"
    echo "                          Note this file is deleted at completion"
    echo "  -s|--server-id <n>    : Starting mysqld server-id, Default is 1"
    echo "                          1 is always master, all other ids are slaves"
    echo "  -S|--ssd              : Use SSD as attached disk type"
    echo "  -t|--type             : Machine type to use for instance(s)"
    echo "                          Default is '$mtype'"
    echo "  -y|--noprompt         : Will not prompt for password"
    echo "                          --pwfile must be provided for mysqld"
    echo "  -z|--zone <name>      : Set GCP zone to use. Default is '$zone'"
    echo ""
    echo " Where <action> is 'run' or other, where any other action enables a "
    echo " dryrun, followed by a list of names that become '\$prefix-\$name'."
    echo " eg. '$PNAME test m01 m02 m03' will dryrun 3 master nodes"
    echo " with the names: $prefix-m01, $prefix-m02, and $prefix-m03"
    echo ""
}


version()
{
    echo "$PNAME: v$TDH_GCP_VERSION"
}


read_password()
{
    local prompt="Password: "
    local pass=
    local pval=

    echo "Please provide the root mysqld password..."
    read -s -p "$prompt" pass
    echo ""
    read -s -p "Repeat $prompt" pval
    echo ""

    if [[ "$pass" != "$pval" ]]; then
        echo "ERROR! Passwords do not match!"
        return 1
    fi

    pwfile=$(mktemp /tmp/tdh-mysqlpw.XXXXXXXX)
    echo $pass > $pwfile

    return 0
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
        -P|--pwfile)
            pwfile="$2"
            shift
            ;;
        -n|--dryrun)
            dryrun=1
            ;;
        -S|-ssd)
            ssd=1
            ;;
        -s|--server-id)
            myid=$2
            shift
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
    echo "Using default 3 masters"
fi

if [ -z "$pwfile" ]; then
    if [ $noprompt -gt 0 ]; then
        echo "Error! Password File required with --noprompt"
        exit 1
    fi
    read_password
fi

echo "Creating masters for '$names'"
echo ""


for name in $names; do
    #
    # Create instance
    host="${prefix}-${name}"
    cmd="${tdh_path}/tdh-gcp-compute.sh --prefix ${prefix} --network ${network} --subnet ${subnet} \
    --type ${mtype} --bootsize ${bootsize}"

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
    sleep 5
fi

for name in $names; do
    host="${prefix}-${name}"
    #
    # Device format and mount
    if [ $attach -gt 0 ]; then
        device="/dev/sdb"
        mountpoint="/data"
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
    echo "( gcloud compute ssh $host --command 'sudo systemctl stop firewalld; sudo systemctl disable firewalld' )"
    if [ $dryrun -eq 0 ]; then
        ( gcloud compute ssh $host --command "sudo systemctl stop firewalld; sudo systemctl disable firewalld" )
    fi


    #
    # prereq's
    echo "( gcloud compute ssh ${host} --command ./tdh-prereqs.sh )"
    if [ $dryrun -eq 0 ]; then
        ( gcloud compute scp ${tdh_path}/../etc/bashrc ${host}:.bashrc )
        ( gcloud compute scp ${tdh_path}/tdh-prereqs.sh ${host}: )
        ( gcloud compute ssh ${host} --command 'chmod +x tdh-prereqs.sh' )
        ( gcloud compute ssh ${host} --command ./tdh-prereqs.sh )
        ( gcloud compute ssh ${host} --command 'sudo yum install -y ansible ansible-lint' )
    fi

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in tdh-prereqs for $host"
        break
    fi


    #
    # ssh
    echo "( gcloud compute ssh ${host} --command 'mkdir -p .ssh; chmod 700 .ssh; chmod 600 .ssh/authorized_keys')"
    if [ $dryrun -eq 0 ]; then
        ( gcloud compute ssh ${host} --command "ssh-keygen -t rsa -b 2048 -N '' -f '~/.ssh/id_rsa'; cat .ssh/id_rsa.pub >> .ssh/authorized_keys; chmod 600 .ssh/authorized_keys" )
        if [ -e $master_id_file ]; then
            ( gcloud compute scp ${master_id_file} ${host}:.ssh/ )
            ( gcloud compute ssh ${host} --command "cat .ssh/${master_id} >> .ssh/authorized_keys; chmod 700 .ssh; chmod 600 .ssh/authorized_keys" )
        else
            ( gcloud compute scp ${host}:.ssh/id_rsa.pub ${master_id_file} )
        fi
    fi


    #
    # mysqld
    if [ $myid -eq 1 ]; then
        role="master"
    else
        role="slave"
    fi

    echo "( $tdh_path/tdh-mysql-install.sh -s $myid -P $pwfile $host $role )"
    if [ $dryrun -eq 0 ]; then
        ( ${tdh_path}/tdh-mysql-install.sh -s ${myid} -P ${pwfile} ${host} ${role} )
    fi
    ((++myid))

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in tdh-mysql-install for $host"
        break
    fi


    #
    # push self for ansible playbooks
    echo "( ${tdh_path}/gcp-push.sh ${tdh_path}/.. tdh-gcp $host )"
    if [ $dryrun -eq 0 ]; then
        ( ${tdh_path}/gcp-push.sh ${tdh_path}/.. tdh-gcp $host )
    fi

    echo "Initialization complete for $host"
    echo ""
done

if [ -e $pwfile ]; then
    unlink $pwfile
fi

echo "$PNAME finished"
exit $rt
