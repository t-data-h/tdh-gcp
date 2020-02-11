#!/bin/bash
#
#  Initialize Master GCP instances.
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/tdh-gcp-config.sh ]; then
    . ${tdh_path}/tdh-gcp-config.sh
fi

# -----------------------------------

names="m01 m02 m03"
prefix="$TDH_GCP_PREFIX"

zone=
mtype="$GCP_DEFAULT_MACHINETYPE"
bootsize="$GCP_DEFAULT_BOOTSIZE"
disksize="$GCP_DEFAULT_DISKSIZE"
format="$TDH_FORMAT"
network=
subnet=

gcpcompute="${tdh_path}/gcp-compute.sh"
master_id="master-id_rsa.pub"
master_id_file="${tdh_path}/../ansible/.ansible/${master_id}"
mysqlinstall="tdh-mysql-install.sh"

myid=1
dryrun=0
noprompt=0
attach=0
ssd=0
pwfile=
tags=
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
    echo "Usage: $TDH_PNAME [options] <action>  host1 host2 ..."
    echo "  -A|--attach           : Create an attached volume"
    echo "  -b|--bootsize <xxGB>  : Size of boot disk, Default is $bootsize"
    echo "  -d|--disksize <xxGB>  : Size of attached disk, Default is $disksize"
    echo "  -h|--help             : Display usage and exit"
    echo "     --dryrun           :  Enable dryrun, no action is taken"
    echo "  -N|--network <name>   : Define a GCP Network to use for instances."
    echo "  -n|--subnet <name>    : Used with --network to define the subnet"
    echo "  -p|--prefix <name>    : Prefix name to use for instances."
    echo "                          Default prefix is '$prefix'"
    echo "  -P|--pwfile <file>    : File containing mysql root password."
    echo "  -s|--server-id <n>    : Starting mysqld server-id, Default is 1"
    echo "                          1 is always master, all other ids are slaves"
    echo "  -S|--ssd              : Use SSD as attached disk type"
    echo "  -t|--type             : Machine type to use for instances"
    echo "                          Default is '$mtype'"
    echo "  -T|--tags <tag1,..>   : List of tags to use for instances"
    echo "  -x|--use-xfs          : Use the XFS filesystem for attached disks"
    echo "  -y|--noprompt         : Will not prompt for password"
    echo "                          --pwfile must be provided for mysqld"
    echo "  -z|--zone <name>      : Set GCP zone to use if not gcloud default."
    echo ""
    echo " Where <action> is 'run' (any other action enables '--dryrun') "
    echo " followed by a list of names that become '\$prefix-\$name'."
    echo ""
    echo " eg. '$TDH_PNAME test m01 m02 m03'"
    echo " Will dryrun 3 master nodes: $prefix-m01, $prefix-m02, and $prefix-m03"
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
        -T|--tags)
            tags="$2"
            shift
            ;;
        -x|--use-xfs)
            xfs=1
            ;;
        -y|--no-prompt)
            noprompt=1
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
            action="${1,,}"
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
    echo "Action provided is: '$action'. Use 'run' to execute"
    dryrun=1
    echo "  <DRYRUN> enabled"
fi

if [ -n "$zone" ]; then
    GSSH="$GSSH --zone $zone"
    GSCP="$GSCP --zone $zone"
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
    echo "  This should match the password configured in ansible inventory."
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
    cmd="${tdh_path}/gcp-compute.sh --prefix $prefix --type $mtype --bootsize $bootsize"

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
    if [ -n "$tags" ]; then
        cmd="$cmd --tags $tags"
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
echo -n " -> Waiting for last host '$host' to respond. . "

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

    echo ""
    echo " => Bootstrapping host '$host'"
    #
    # Device format and mount
    if [ $attach -gt 0 ]; then
        device="/dev/sdb"
        mountpoint="/data01"
        cmd="./${format}"

        if [ $xfs -eq 1 ]; then
            cmd="$cmd --use-xfs"
        fi
        cmd="$cmd -f $device $mountpoint"

        echo " -> Formatting and Mount of attached disk"
        echo "( $GSSH $host --command '$cmd' )"
        if [ $dryrun -eq 0 ]; then
            ( $GSCP ${tdh_path}/../tools/${format} ${host}: )
            ( $GSSH $host --command "chmod +x $format" )
            ( $GSSH $host --command "$cmd" )
        fi

        rt=$?
        if [ $rt -gt 0 ]; then
            echo "Error in $format for $host"
            break
        fi
    fi

    # prereq's
    # disable  iptables and cups
    echo " -> Prereqs"
    echo "( $GSSH $host --command 'sudo systemctl stop firewalld; sudo systemctl disable firewalld' )"
    if [ $dryrun -eq 0 ]; then
        ( $GSSH $host --command "sudo systemctl stop firewalld; sudo systemctl disable firewalld" )
    fi

    echo "( $GSSH $host --command sudo ./tdh-prereqs.sh )"
    if [ $dryrun -eq 0 ]; then
        ( $GSCP ${tdh_path}/../etc/bashrc ${host}:.bashrc )
        ( $GSCP ${tdh_path}/../tools/tdh-prereqs.sh ${host}: )
        ( $GSSH $host --command 'chmod +x tdh-prereqs.sh' )
        ( $GSSH $host --command './tdh-prereqs.sh' )
        ( $GSSH $host --command 'sudo yum install -y epel-release' )
        ( $GSSH $host --command 'sudo yum install -y ansible ansible-lint' )
    fi

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in tdh-prereqs for $host"
        break
    fi

    #
    # ssh
    echo " -> Configure ssh host keys"
    echo "( $GSSH $host --command \"ssh-keygen -t rsa -b 2048 -N '' -f ~/.ssh/id_rsa; \
      cat .ssh/id_rsa.pub >> .ssh/authorized_keys; chmod 600 .ssh/authorized_keys\" )"

    if [ $dryrun -eq 0 ]; then
        ( $GSSH $host --command "ssh-keygen -t rsa -b 2048 -N '' -f ~/.ssh/id_rsa; \
          cat .ssh/id_rsa.pub >> .ssh/authorized_keys; chmod 600 .ssh/authorized_keys" )
    fi

    if [ -e "$master_id_file" ]; then
        echo "( $GSCP ${master_id_file} ${host}:.ssh/ )"
        echo "( $GSSH $host --command \"cat .ssh/${master_id} >> .ssh/authorized_keys; chmod 700 .ssh; chmod 600 .ssh/authorized_keys\" )"

        if [ $dryrun -eq 0 ]; then
            ( $GSCP ${master_id_file} ${host}:.ssh/ )
            ( $GSSH $host --command "cat .ssh/${master_id} >> .ssh/authorized_keys; chmod 700 .ssh; chmod 600 .ssh/authorized_keys" )
        fi
    else
        echo "( $GSCP ${host}:.ssh/id_rsa.pub ${master_id_file} )"
        echo "( $GSSH $host --command \"cat .ssh/id_rsa.pub >> .ssh/authorized_keys; chmod 700 .ssh; chmod 600 .ssh/authorized_keys\" )"

        if [ $dryrun -eq 0 ]; then
            echo "-> Primary Master Host is '$host'"
            ( $GSCP ${host}:.ssh/id_rsa.pub ${master_id_file} )
            ( $GSSH $host --command "cat .ssh/id_rsa.pub >> .ssh/authorized_keys; chmod 700 .ssh; chmod 600 .ssh/authorized_keys" )
        fi
    fi


    #
    # mysqld
    if [ $myid -eq 1 ]; then
        role="master"
    else
        role="slave"
    fi

    cmd="${tdh_path}/${mysqlinstall}"

    if [ -n "$zone" ]; then
        cmd="$cmd --zone $zone"
    fi

    echo " -> Mysqld install"
    echo "( $cmd -G -s $myid -P $pwfile $host $role )"

    if [ $dryrun -eq 0 ]; then
        ( $cmd -G -s $myid -P $pwfile $host $role )
    fi
    ((++myid))

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in '${msyqlinstall}' for $host"
        break
    fi

    #
    # push self for ansible
    cmd="${tdh_path}/${TDH_PUSH} -G"
    if [ -n "$zone" ]; then
        cmd="$cmd --zone $zone"
    fi

    echo "( ${cmd} ${tdh_path}/.. tdh-gcp $host )"
    if [ $dryrun -eq 0 ]; then
        ( $cmd ${tdh_path}/.. tdh-gcp $host )
    fi

    echo "-> Initialization complete for $host"
    echo ""
done

if [ -e "$pwfile" ]; then
    ( rm $pwfile )
fi

echo "$TDH_PNAME finished"
exit $rt
