#!/bin/bash
#
#  Initialize Master GCP instances.
#
#  @author Timothy C. Arland <tcarland@gmail.com>
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../bin/tdh-gcp-config.sh ]; then
    . ${tdh_path}/../bin/tdh-gcp-config.sh
fi

# -----------------------------------

prefix="$TDH_GCP_PREFIX"

names=
zone=
mtype="$GCP_DEFAULT_MACHINETYPE"
bootsize="$GCP_DEFAULT_BOOTSIZE"
disksize="$GCP_DEFAULT_DISKSIZE"
format="$TDH_FORMAT"
imagef=
network=
subnet=

gcpcompute="${tdh_path}/gcp-compute.sh"
master_id="master-id_rsa.pub"
master_id_file="${tdh_path}/../ansible/.ansible/${master_id}"

attach=0
disknum=1
dryrun=0
ssd=0
xfs=0
tags=
action=

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

usage="
A script for creating TDH instances on GCP.

Synopsis:
  $TDH_PNAME [options] <action> host1 host2 ...

Options:
  -A|--attach           : Create attached volumes.
  -b|--bootsize <xxGB>  : Size of boot disk in GB, Default is $bootsize.
  -d|--disksize <xxGB>  : Size of attached volume(s), Default is $disksize.
  -D|--disknum   <n>    : Number of attached DataNode volumes.
  -h|--help             : Display usage and exit.
     --dryrun           : Enable dryrun, no action is taken.
  -i|--image   <name>   : Set image family as ubuntu (default) or centos.
  -N|--network <name>   : GCP Network name. Default is $network.
  -n|--subnet  <name>   : GCP Network subnet name. Default is $subnet.
  -p|--prefix  <name>   : Prefix name to use for instances.
                          Default prefix is '$prefix'.
  -S|--ssd              : Use SSD as attached disk type.
  -t|--type             : Machine type to use for instances.
                          Default is '$mtype'.
  -T|--tags <tag1,..>   : List of tags to use for instances.
  -x|--use-xfs          : Use the XFS filesystem for attached disks.
  -V|--version          : Show usage info and exit.
  -z|--zone <name>      : Set GCP zone to use if not gcloud default.
  
Where <action> is 'run'. Any other action enables '--dryrun' 
followed by a list of names that become '\$prefix-\$name'.
  
eg. '$TDH_PNAME test m01 m02 m03'
Will dryrun 3 master nodes: $prefix-m01, $prefix-m02, and $prefix-m03
"

# -----------------------------------

# MAIN
#
rt=0
chars=( {b..z} )

while [ $# -gt 0 ]; do
    case "$1" in
        'help'|-h|--help)
            echo "$usage"
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
        -D|--disknum)
            disknum=$2
            shift
            ;;
        -i|--image)
            imagef="$2"
            shift
            ;;
        -p|--prefix)
            prefix="$2"
            shift
            ;;
        --dryrun|--dry-run)
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
        -T|--tags)
            tags="$2"
            shift
            ;;
        -x|--use-xfs)
            xfs=1
            ;;
        -z|--zone)
            zone="$2"
            shift
            ;;
        'version'|-V|--version)
            tdh_version
            exit 0
            ;;
        *)
            action="${1,,}"
            shift
            names="$@"
            shift $#
            ;;
    esac
    shift
done

if [[ -z "$action" || -z "$names" ]]; then
    tdh_version
    echo "$usage"
    exit 1
fi

if [ -n "$network" ] && [ -z "$subnet" ]; then
    echo "Error, Subnet must be provided with --network"
    exit 1
fi

if [[ ! -e ${tdh_path}/../tools/${format} ]]; then
    echo "Error, cannot locate '$format', is this being run from tdh-gcp root?"
    exit 2
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


echo "-> Creating instances '$mtype' for { $names }"
echo ""

for name in $names; do
    host="${prefix}-${name}"
    cmd="${gcpcompute} --prefix $prefix --type $mtype --bootsize $bootsize"

    if [ -n "$imagef" ]; then
        cmd="$cmd --image $imagef"
    fi
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
        cmd="${cmd} --attach --disksize $disksize --disknum $disknum"
    fi
    if [ $ssd -gt 0 ]; then
        cmd="${cmd} --ssd"
    fi
    if [ -n "$tags" ]; then
        cmd="$cmd --tags $tags"
    fi

    cmd="${cmd} create ${name}"
    echo "( $cmd )"

    ( $cmd )

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "$PNAME Error in GCP initialization of $host"
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
        echo " -> Formatting additional volume(s)"
        if [ $dryrun -eq 0 ]; then
            ( $GSCP ${tdh_path}/../tools/${format} ${host}: )
            ( $GSSH $host --command "chmod +x $format" )
        fi

        for (( i=0; i<$disknum; )); do
            device="/dev/sd${chars[i++]}"
            volnum=$(printf "%02d" $i)
            mountpt="/data${volnum}"

            cmd="./${format}"

            if [ $xfs -eq 1 ]; then
                cmd="$cmd --use-xfs"
            fi
            cmd="$cmd -f $device $mountpt"

            echo "( $GSSH $host --command '$cmd' )"

            if [ $dryrun -eq 0 ]; then
                ( $GSSH $host --command "$cmd" )
            fi

            rt=$?
            if [ $rt -gt 0 ]; then
                echo "Error in $format for $host"
                break
            fi
        done
    fi

    # prereqs
    # disable  iptables and cups
    echo " -> Install Prereqs"
    echo "( $GSSH $host --command 'sudo systemctl stop firewalld; sudo systemctl disable firewalld; \
        sudo service cups stop; sudo chkconfig cups off' )"

    if [ $dryrun -eq 0 ]; then
        ( $GSSH $host --command "sudo systemctl stop firewalld; sudo systemctl disable firewalld; \
        sudo service cups stop; sudo chkconfig cups off" )
    fi

    echo "( $GSSH $host --command  sudo ./tdh-prereqs.sh )"

    if [ $dryrun -eq 0 ]; then
        ( $GSCP ${tdh_path}/../etc/bashrc ${host}:.bashrc )
        ( $GSCP ${tdh_path}/../tools/tdh-prereqs.sh ${host}: )
        ( $GSSH $host --command 'chmod +x tdh-prereqs.sh' )
        ( $GSSH $host --command './tdh-prereqs.sh' )
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
            echo "-> Primary host is '$host'"
            ( $GSCP ${host}:.ssh/id_rsa.pub ${master_id_file} )
            ( $GSSH $host --command "cat .ssh/id_rsa.pub >> .ssh/authorized_keys; chmod 700 .ssh; chmod 600 .ssh/authorized_keys" )
        fi
    fi

    echo "-> Initialization complete for $host"
    echo ""
done

echo "$TDH_PNAME finished"
exit $rt
