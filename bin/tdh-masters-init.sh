#!/bin/bash
#
#  Initialize master GCP instances.
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../etc/tdh-gcp-config.sh ]; then
    . ${tdh_path}/../etc/tdh-gcp-config.sh
fi

# -----------------------------------

names="m01 m02 m03"
prefix="$TDH_GCP_PREFIX"

zone=
mtype="$GCP_DEFAULT_MACHINETYPE"
bootsize="$GCP_DEFAULT_BOOTSIZE"
disksize="$GCP_DEFAULT_DISKSIZE"
network="tdh-net"
subnet="tdh-net-west1"

master_id="master-id_rsa.pub"
master_id_file="${tdh_path}/../ansible/.ansible/${master_id}"

gssh="gcloud compute ssh"
gscp="gcloud compute scp"

myid=1
dryrun=0
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
    echo "  -N|--network <name>   : Define a GCP Network to use for the instance."
    echo "  -n|--subnet <name>    : Used with --network to define the subnet"
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
    echo "  -z|--zone <name>      : Set GCP zone to use."
    echo ""
    echo " Where <action> is 'run' or other, where any other action enables a "
    echo " dryrun, followed by a list of names that become '\$prefix-\$name'."
    echo " eg.  '$PNAME test m01 m02 m03'"
    echo " will dryrun 3 master nodes: $prefix-m01, $prefix-m02, and $prefix-m03"
    echo ""
}


read_password()
{
    local prompt="Password: "
    local pass=
    local pval=

    read -s -p "$prompt" pass
    echo ""
    read -s -p "Repeat $prompt" pval
    echo ""

    if [[ "$pass" != "$pval" ]]; then
        return 1
    fi

    pwfile=$(mktemp /tmp/tdh-mysqlpw.XXXXXXXX)
    echo $pass > $pwfile

    return 0
}


# MAIN
#
rt=0

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
        --dryrun)
            dryrun=1
            ;;
        -n|--subnet)
            subnet="$2"
            shift
            ;;
        -N|--network)
            network="$2"
            shift
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
            tdh_version
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
    gssh="$gssh --zone $zone"
    gscp="$gscp --zone $zone"
fi

if [ -n "$namelist" ]; then
    names="$namelist"
else
    echo "Using default of 3 master instances"
fi

#
# Set mysqld password
if [ -z "$pwfile" ]; then
    if [ $noprompt -gt 0 ]; then
        echo "Error! Password File required with --noprompt"
        exit 1
    fi

    echo "Please provide the root mysqld password..."
    if [ $dryrun -eq 0 ]; then
        read_password
        if [ $? -gt 0 ]; then
            echo "ERROR! Passwords do not match!"
            exit 1
        fi
    fi
fi

echo "Creating master instances '$mtype' for { $names }"
echo ""

# Create instance
for name in $names; do
    host="${prefix}-${name}"
    cmd="${tdh_path}/tdh-gcp-compute.sh --prefix $prefix --type $mtype --bootsize $bootsize"
    
    if [ -n "$network" ]; then 
        cmd="$cmd --network $network --subnet $subnet"
    fi
    if [ -n "$zone" ]; then
        cmd="$cmd --zone $zone"
    fi
    if [ $dryrun -gt 0 ]; then
        cmd="$cmd --dryrun"
    fi
    if [ $attach -gt 0 ]; then
        cmd="$cmd --attach --disksize $disksize"
    fi
    if [ $ssd -gt 0 ]; then
        cmd="$cmd --ssd"
    fi

    cmd="$cmd create $name"
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
echo -n " -> Waiting for host to respond. . "

if [ $dryrun -eq 0 ]; then
    wait_for_host "$gssh $host"
    rt=$?
else
    echo "  <DRYRUN skipped>"
fi
echo ""

if [ $rt -ne 0 ]; then
    echo "Error in wait_for_host(), no response from host or timed out"
    echo "Will attempt to continue in 3...2.."
    sleep 3
fi

for name in $names; do
    host="${prefix}-${name}"

    #
    # Device format and mount
    if [ $attach -gt 0 ]; then
        device="/dev/sdb"
        mountpoint="/data"
        echo "( $gssh $host --command './tdh-gcp-format.sh $device $mountpoint' )"
        if [ $dryrun -eq 0 ]; then
            ( $gscp ${tdh_path}/tdh-gcp-format.sh ${host}: )
            ( $gssh $host --command 'chmod +x tdh-gcp-format.sh' )
            ( $gssh $host --command "./tdh-gcp-format.sh $device $mountpoint" )
        fi

        rt=$?
        if [ $rt -gt 0 ]; then
            echo "Error in tdh-gcp-format for $host"
            break
        fi
    fi


    #
    # disable  iptables and cups
    echo "( $gssh $host --command 'sudo systemctl stop firewalld; sudo systemctl disable firewalld' )"
    if [ $dryrun -eq 0 ]; then
        ( $gssh $host --command "sudo systemctl stop firewalld; sudo systemctl disable firewalld" )
    fi


    #
    # prereq's
    echo "( $gssh $host --command ./tdh-prereqs.sh )"

    if [ $dryrun -eq 0 ]; then
        ( $gscp ${tdh_path}/../etc/bashrc ${host}:.bashrc )
        ( $gscp ${tdh_path}/tdh-prereqs.sh ${host}: )
        ( $gssh $host --command 'chmod +x tdh-prereqs.sh' )
        ( $gssh $host --command ./tdh-prereqs.sh )
        ( $gssh $host --command 'sudo yum install -y ansible ansible-lint' )
    fi

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in tdh-prereqs for $host"
        break
    fi


    #
    # ssh
    echo "( $gssh $host --command \"ssh-keygen -t rsa -b 2048 -N '' -f ~/.ssh/id_rsa; \
      cat .ssh/id_rsa.pub >> .ssh/authorized_keys; chmod 600 .ssh/authorized_keys\" )"

    if [ $dryrun -eq 0 ]; then
        ( $gssh $host --command "ssh-keygen -t rsa -b 2048 -N '' -f ~/.ssh/id_rsa; \
          cat .ssh/id_rsa.pub >> .ssh/authorized_keys; chmod 600 .ssh/authorized_keys" )

        if [ -e "$master_id_file" ]; then
            ( $gscp ${master_id_file} ${host}:.ssh/ )
            ( $gssh $host --command "cat .ssh/${master_id} >> .ssh/authorized_keys; chmod 700 .ssh; chmod 600 .ssh/authorized_keys" )
        else
            ( $gscp ${host}:.ssh/id_rsa.pub ${master_id_file} )
        fi
    fi


    #
    # mysqld
    if [ $myid -eq 1 ]; then
        role="master"
    else
        role="slave"
    fi

    cmd="${tdh_path}/tdh-mysql-install.sh"

    if [ -n "$zone" ]; then
        cmd="$cmd --zone $zone"
    fi

    echo "( $cmd -s $myid -P $pwfile $host $role )"

    if [ $dryrun -eq 0 ]; then
        ( $cmd -s $myid -P $pwfile $host $role )
    fi
    ((++myid))

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in tdh-mysql-install for $host"
        break
    fi


    #
    # push self for ansible playbooks
    cmd="${tdh_path}/gcp-push.sh"

    if [ -n "$zone" ]; then
        cmd="$cmd --zone $zone"
    fi

    echo "( ${cmd} ${tdh_path}/.. tdh-gcp $host )"

    if [ $dryrun -eq 0 ]; then
        ( $cmd ${tdh_path}/.. tdh-gcp $host )
    fi

    echo "Initialization complete for $host"
    echo ""
done

if [ -e "$pwfile" ]; then
    ( rm $pwfile )
fi

echo "$TDH_PNAME finished"
exit $rt
