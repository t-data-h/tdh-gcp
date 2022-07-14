#!/bin/bash
#
#  gcp-compute.sh -  Manage GCP Compute Instances
#
#  @author Timothy C. Arland <tcarland@gmail.com>
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../bin/tdh-gcp-env.sh ]; then
    . ${tdh_path}/../bin/tdh-gcp-env.sh
fi

# -----------------------------------

prefix="$TDH_GCP_PREFIX"
zone="${GCP_ZONE:-${GCP_DEFAULT_ZONE}}"
mtype="${GCP_MACHINE_TYPE:-${GCP_DEFAULT_MACHINETYPE}}"
bootsize="$GCP_DEFAULT_BOOTSIZE"
volsize="$GCP_DEFAULT_DISKSIZE"
image="${GCP_MACHINE_IMAGE:-${GCP_DEFAULT_IMAGE}}"
image_project="${GCP_IMAGE_PROJECT:-${GCP_DEFAULT_IMAGE_PROJECT}}"
network="$GCP_NETWORK"
subnet="$GCP_SUBNET"

name=
action=
tags=
volname=
volnum=1
attach=0
ssd=0
vga=0
ipf=0
async=0
dryrun=0
keep=0
serial=1

# -----------------------------------
# Gcloud CLI required.
if [ -z "$GCP" ]; then
    echo "$TDH_PNAME ERROR, Google Cloud CLI 'gcloud' not found." >&2
    exit 2
fi

# -----------------------------------

usage="
Create and manage GCP Compute Engine instances.

Synopsis:
  $TDH_PNAME [options] <action> <instance> ...

Options:
  -a|--async              : Use 'async' option with gcloud commands.
  -A|--attach             : Init and attach data disk(s) on 'create'.
  -b|--bootsize <xxGB>    : Size of instance boot disk.
  -d|--disksize <xxGB>    : Size of attached volume(s).
  -D|--disknum   <n>      : Number of attached volumes, if more than 1.
  -F|--ip-forward         : Enables IP Forwarding for the instance
  -h|--help               : Display usage and exit.
  -k|--keep(-disks)       : Sets --keep-disks=data on delete action.
  -l|--list               : List available machine-types for a zone.
  -L|--list-machine-types : List available machine-types for a zone.
     --list-disk-types    : List available disk types for a zone.
     --dryrun             : Enable dryrun, no action is taken.
  -N|--network <name>     : GCP Network name when not using default.
  -n|--subnet  <name>     : Used with --network to define the subnet.
  -p|--prefix  <name>     : Prefix to use for instance names.
  -S|--ssd                : Use SSD as attached disk type
  -t|--type               : Machine type to use for instances.
  -T|--tags  <tag1,..>    : A set of tags to use for instances.
  -z|--zone  <name>       : Set the GCP zone, default is '$zone'. 
  -v|--vga                : Attach a display device at create.
  -X|--no-serial          : Don't enable logging to serial by default.
  -V|--version            : Show version info and exit.
 
Where <action> is one of the following: 
  create      :  Initialize new GCP instance(s)
  start       :  Start existing GCP instance(s)
  stop        :  Stop running instance(s).
  delete      :  Delete instance(s)
  describe    :  Dump instance details
 
  Default Machine Type is '$mtype'
  Default Image is        '$image'
  Default Boot Disk size  '$bootsize'
  Default GCP Zone is     '$GCP_DEFAULT_ZONE'
  Default tags are set to '$prefix'
  
The following environment variables are honored for overrides:
  GCP_MACHINE_TYPE, GCP_MACHINE_IMAGE, GCP_IMAGE_PROJECT, GCP_ZONE
  GCP_NETWORK, GCP_SUBNET
"

# -----------------------------------

list_machine_types()
{
    ( gcloud compute machine-types list | grep "${zone}\|NAME" )
}


list_disk_types()
{
    ( gcloud compute disk-types list | grep "${zone}\|NAME" )
}


vm_is_running()
{
    local name="$1"
    local rt=1
    local cmd="gcloud compute instances describe --zone $zone"

    status=$( $cmd $name | grep status: | awk -F: '{ print $2 }' )
    printf "\n -> status: $name = $status \n"

    if [ "$status" == "RUNNING" ]; then
        rt=0
    fi

    return $rt
}

start_instance()
{
    local name="$1"
    local zone="$2"

    local cmd="gcloud compute instances start $name --zone $zone"

    if [ $async -eq 1 ]; then
        cmd="$cmd --async"
    fi

    printf "\n -> start_instance() \n"
    echo "( $cmd )"

    if [ $dryrun -eq 0 ]; then
        ( $cmd )
    fi

    return $?
}

stop_instance()
{
    local name="$1"
    local zone="$2"
    local args=("--zone" $zone)

    if [ $async -eq 1 ]; then
        args+=("--async")
    fi

    printf "\n -> stop_instance() \n"
    echo "( gcloud compute instances stop $name ${args[@]} )"

    if [ $dryrun -eq 0 ]; then
        ( gcloud compute instances stop $name ${args[@]} )
    fi

    return $?
}


attach_disk()
{
    local volname="$1"
    local gcpname="$2"
    local rt=0

    printf "\n -> attach_disk() \n"
    echo "( gcloud compute instances attach-disk --disk ${volname} ${gcpname} --zone $zone )"

    if [ $dryrun -eq 0 ]; then
        ( gcloud compute instances attach-disk --disk ${volname} ${gcpname} --zone $zone )
        rt=$?
    fi

    return $rt
}


create_disk()
{
    local volname="$1"
    local volsize="$2"
    local ssd=$3
    local rt=0
    local args=("--zone" $zone "--size=$volsize")

    if [[ -z "$volname" || -z "$volsize" ]]; then
        return 1
    fi
    if [ $ssd -eq 1 ]; then
        args+=("--type=pd-ssd")
    fi

    printf "\n -> create_disk() \n"
    echo "( gcloud compute disks create ${args[@]} $volname )"

    if [ $dryrun -eq 0 ]; then
        ( gcloud compute disks create ${args[@]} $volname )
        rt=$?
    fi

    return $rt
}


# MAIN
#
rt=0
names=
ipre='([0-9]{1,3}[\.]){3}[0-9]{1,3}'
chars=( {b..z} )
maxvols=${#chars[@]}

while [ $# -gt 0 ]; do
    case "$1" in
        -a|--async)
            async=1
            ;;
        -A|--attach)
            attach=1
            ;;
        -b|--bootsize)
            bootsize="$2"
            shift
            ;;
        'help'|-h|--help)
            echo "$usage"
            exit $rt
            ;;
        -d|--disksize)
            volsize="$2"
            shift
            ;;
        -D|--disknum)
            volnum=$2
            shift
            ;;
        -F|--ip-forward)
            ipf=1
            ;;
        -k|--keep*)
            keep=1
            ;;
        -l|--list)
            ( gcloud compute instances list )
            exit $rt
            ;;
        -L|--list-types|--list-machine-types)
            list_machine_types
            exit $rt
            ;;
        --list-disk-types)
            list_disk_types
            exit $rt
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
        -p|--prefix)
            prefix="$2"
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
        -v|--vga)
            vga=1
            ;;
        -z|--zone)
            zone="$2"
            shift
            ;;
        -X|--no-serial)
            serial=0
            ;;
        'version'|-V|--version)
            tdh_version
            exit $rt
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

tdh_version

if [ -z "$names" ]; then
    echo "$usage"
    exit 1
fi

if [ -z "$tags" ]; then
    tags="$prefix"
fi

if [ -z "$network" ]; then
    if [ -n "$subnet" ]; then
        echo "$TDH_PNAME ERROR, --subnet defined without --network" >&2
        exit 1
    fi
    network="default"
    subnet="default"
fi

if [ -n "$network" ] && [ -z "$subnet" ]; then
    echo "$TDH_PNAME ERROR, --subnet not defined and is required with --network" >&2
    exit 1
fi

if [ -z "$zone" ]; then
    zone="$GCP_DEFAULT_ZONE"
fi


printf "\n${C_CYN}  GCP Zone ${C_NC}= ${C_WHT}'$zone'${C_NC}\n"
printf "${C_CYN}  Network  ${C_NC}= ${C_WHT}'$network'${C_NC}\n"
printf "${C_CYN}  Subnet   ${C_NC}= ${C_WHT}'$subnet'${C_NC}\n\n"


zone_is_valid "$zone"
rt=$?
if [ $rt -ne 0 ]; then
    echo "$TDH_PNAME ERROR, provided zone '$zone' is not valid" >&2
    exit $rt
fi


subnet_is_valid "$subnet"
if [ $? -ne 0 ]; then
    echo "$TDH_PNAME ERROR, subnet '$subnet' not found. Has it been created?" >&2
    exit 1
fi


if [ $attach -eq 1 ] && [ $volnum -gt 1 ]; then
    if [ $volnum -gt $maxvols ]; then
        echo "$TDH_PNAME ERROR, a maximum of '$maxvols' volumes is supported." >&2
        exit 1
    fi
fi


for name in $names; do
    ( echo $name | grep "^${prefix}-" >/dev/null 2>&1 )
    if [ $? -ne 0 ]; then
        name="${prefix}-${name}"
    fi

    case "$action" in
    create)
        args=("--image-family=$image" "--image-project=$image_project")
        args+=("--zone" $zone "--machine-type=$mtype" "--boot-disk-size=$bootsize")
        args+=("--verbosity" "error" "--tags" $tags)

        if [ $ssd -eq 1 ]; then
            args+=("--boot-disk-type=pd-ssd")
        fi

        if [ -n "$network" ]; then
            args+=("--network" $network "--subnet" $subnet)
        fi

        if [ $vga -eq 1 ]; then
            args+=($GCP_ENABLE_VGA)
        fi

        if [ $ipf -eq 1 ]; then
            args+=("--can-ip-forward")
        fi

        echo "( gcloud compute instances create ${args[@]} $name ) "

        if [ $dryrun -eq 0 ]; then
            ( gcloud compute instances create ${args[@]} $name )
            rt=$?
        fi

        if [ $rt -ne 0 ]; then
            echo "$TDH_PNAME ERROR in create." >&2
            exit $rt
        fi

        # Attach disks
        if [ $attach -gt 0 ]; then
            i=0
            for (( i=1; i<=$volnum; i++)); do
                voln=$(printf "%02d" $i)
                volname="${name}-disk${voln}"

                ( gcloud compute disks list --filter="name=($volname)" 2>/dev/null | grep $volname > /dev/null )

                if [ $? -gt 0 ]; then
                    create_disk "$volname" "$volsize" $ssd 
                    rt=$?

                    if [ $rt -ne 0 ]; then
                        echo "$TDH_PNAME ERROR in create_disk() for '$volname', aborting..." >&2
                        exit $rt
                    fi
                fi

                attach_disk "$volname" "$name"
                rt=$?

                if [ $rt -ne 0 ]; then
                    echo "$TDH_PNAME ERROR in attach_disk() for '$volname', rt=$rt, aborting..." >&2
                    exit $rt
                fi
            done
        fi

        if [ $serial -gt 0 ]; then
            echo ""
            echo "( gcloud compute instances add-metadata $name --zone $zone --metadata serial-port-enable=true )"
            if [ $dryrun -eq 0 ]; then
                ( gcloud compute instances add-metadata $name --zone $zone --metadata serial-port-enable=true )
            fi
        fi
        ;;

    start)
        start_instance "$name" "$zone"
        ;;

    stop)
        stop_instance "$name" "$zone"
        ;;

    delete|destroy)
        args=("--zone" $zone "--quiet")
        if [ $keep -eq 1 ]; then
            args+=("--keep-disks=data")
        else
            args+=("--delete-disks=all")
        fi

        echo "( gcloud compute instances delete $name ${args[@]} )"

        if [ $dryrun -eq 0 ]; then
            ( gcloud compute instances delete $name ${args[@]} )
        fi
        ;;

    describe)
        ( gcloud compute instances describe --zone $zone $name )
        ;;
    status)
        vm_is_running $name
        rt=$?
        ;;
    *)
        echo "$TDH_PNAME ERROR, <action> not recognized: '$action'" >&2
        echo "$usage"
        rt=1
        break
        ;;
    esac
done

printf " -> ${C_WHT}${TDH_PNAME} Finished. ${C_NC} \n"
exit $rt
