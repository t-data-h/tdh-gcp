#!/bin/bash
#
#  Initialize Master GCP instances.
#
#  @author Timothy C. Arland <tcarland@gmail.com>
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../bin/tdh-gcp-env.sh ]; then
    . ${tdh_path}/../bin/tdh-gcp-env.sh
fi

# -----------------------------------

prefix="$TDH_GCP_PREFIX"

names=
zone="$GCP_DEFAULT_ZONE"
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
  -D|--disknum   <n>    : Number of additional attached volumes.
  -h|--help             : Display usage and exit.
     --dryrun           : Enable dryrun, no action is taken.
  -i|--image   <name>   : Set image family as 'ubuntu' (default) or 'centos'.
  -N|--network <name>   : GCP Network name.
  -n|--subnet  <name>   : GCP Network subnet name. 
  -p|--prefix  <name>   : Prefix name to use for instances.
                          Default prefix is '$prefix'.
  -S|--ssd              : Use SSD as attached disk type.
  -t|--type             : Machine type to use for instances.
                          Default is '$mtype'.
  -T|--tags <tag1,..>   : Set of tags to use for instances.
  -x|--use-xfs          : Use the XFS filesystem for attached disks.
  -V|--version          : Show usage info and exit.
  -z|--zone <name>      : Set GCP zone to use, default is '$zone'.
  
Where <action> is 'run' or 'reset'. Any other action enables '--dryrun' 
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

if [[ -z "$action" ]]; then
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

if [[ "$action" == "run" && $dryrun -eq 0 ]]; then
    dryrun=0
    if [ -z "$names" ]; then
        echo "Error, no hosts list provided."
        echo "$usage"
        exit 1
    fi
elif [ "$action" == "reset" ]; then
    for name in $names; do
        ( echo $name | grep "^${prefix}-" >/dev/null 2>&1 )
        if [ $? -ne 0 ]; then
            name="${prefix}-${name}"
        fi

        nf=$( ssh-keygen -f ${HOME}/.ssh/known_hosts -R "$name" >/dev/null  )
        if [ $? -eq 0 ]; then
            if [ -z "$nf" ]; then
                echo "Host $name removed from ${HOME}/.ssh/known_hosts"
            else
                echo "$nf"
            fi
        fi
    done
    if [ -f $master_id_file ]; then
        echo "Removing master id file '$master_id_file'"
        ( unlink $master_id_file )
    fi
    exit $?
else
    printf "$C_CYN -> Action provided is: ${C_NC}'%s'. ${C_CYN}Use${C_NC} 'run' ${C_CYN}to execute. $C_NC \n" $action
    dryrun=1
    printf " $C_YEL <DRYRUN> enabled $C_NC \n"
fi

if [ -n "$zone" ]; then
    GSSH="$GSSH --zone $zone"
    GSCP="$GSCP --zone $zone"
fi

printf "$C_CYN -> Creating instance(s) ${C_NC}${C_WHT}'%s'${C_NC}${C_CYN}\
 for ${C_NC}{${C_WHT} ${names} ${C_NC}} \n\n" $mtype

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

printf "\n${C_CYN} -> Waiting for last host ${C_NC}${C_WHT}'%s'${C_NC}${C_CYN} to respond ${C_NC}. . " $host

if [ $dryrun -eq 0 ]; then
    wait_for_gcphost "$host"
    rt=$?
else
    printf "$C_YEL  <DRYRUN skipped> $C_NC \n"
fi
echo ""

if [ $rt -ne 0 ]; then
    echo "Error in wait_for_gcphost(), no response from host or timed out"
    echo "Will attempt to continue in 3...2.."
    sleep 3
fi

for name in $names; do
    host="${prefix}-${name}"

    printf "\n${C_CYN} -> Bootstrapping host ${C_WHT}'%s' ${C_NC} \n" $host
    #
    # Device format and mount
    if [ $attach -gt 0 ]; then
        printf "${C_CYN} -> Formatting additional volume(s) ${C_NC}"
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
    printf "$C_CYN -> Install Prereqs $C_NC \n"

    if [[ $imagef =~ centos ]]; then
        echo "( $GSSH $host --command 'sudo systemctl stop firewalld; sudo systemctl disable firewalld' )"

        if [ $dryrun -eq 0 ]; then
            ( $GSSH $host --command "sudo systemctl stop firewalld; sudo systemctl disable firewalld" )
        fi
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
    printf "$C_CYN -> Configure ssh host keys $C_NC \n"

    echo "( $GSSH ${host} --command \"ssh-keygen -t rsa -b 2048 -N '' -f ~/.ssh/id_rsa; \
      cat .ssh/id_rsa.pub >> .ssh/authorized_keys; chmod 600 .ssh/authorized_keys\" )"

    if [ $dryrun -eq 0 ]; then
        ( $GSSH ${host} --command "ssh-keygen -t rsa -b 2048 -N '' -f ~/.ssh/id_rsa; \
          cat .ssh/id_rsa.pub >> .ssh/authorized_keys; chmod 600 .ssh/authorized_keys" )
    fi

    if [ -e "$master_id_file" ]; then
        echo "( $GSCP ${master_id_file} ${host}:.ssh/ )"
        echo "( $GSSH ${host} --command \"cat .ssh/${master_id} >> .ssh/authorized_keys; chmod 700 .ssh; chmod 600 .ssh/authorized_keys\" )"

        if [ $dryrun -eq 0 ]; then
            ( $GSCP ${master_id_file} ${host}:.ssh/ )
            ( $GSSH ${host} --command "cat .ssh/${master_id} >> .ssh/authorized_keys; chmod 700 .ssh; chmod 600 .ssh/authorized_keys" )
        fi
    else
        echo "( $GSCP ${host}:.ssh/id_rsa.pub ${master_id_file} )"
        echo "( $GSSH ${host} --command \"cat .ssh/id_rsa.pub >> .ssh/authorized_keys; chmod 700 .ssh; chmod 600 .ssh/authorized_keys\" )"

        if [ $dryrun -eq 0 ]; then
            echo "-> Primary host is '$host'"
            ( $GSCP ${host}:.ssh/id_rsa.pub ${master_id_file} )
            ( $GSSH $host --command "cat .ssh/id_rsa.pub >> .ssh/authorized_keys; chmod 700 .ssh; chmod 600 .ssh/authorized_keys" )
        fi
    fi

    printf "${C_CYN} -> Initialization complete for ${C_WHT}%s${C_NC} \n" $host
done

echo "$TDH_PNAME finished."
exit $rt
