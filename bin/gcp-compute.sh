#!/bin/bash
#
#  gcp-compute.sh -  Manage GCP Compute Instances
#
#  @author Timothy C. Arland <tcarland@gmail.com>
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../bin/tdh-gcp-config.sh ]; then
    . ${tdh_path}/../bin/tdh-gcp-config.sh
fi

# -----------------------------------

prefix="$TDH_GCP_PREFIX"
zone="$GCP_ZONE"

mtype="$GCP_DEFAULT_MACHINETYPE"
bootsize="$GCP_DEFAULT_BOOTSIZE"
volsize="$GCP_DEFAULT_DISKSIZE"
image="$GCP_DEFAULT_IMAGE"
image_project="$GCP_DEFAULT_IMAGEPROJECT"

name=
action=
network=
subnet=
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
    echo "Error, Google Cloud CLI 'gcloud' not found."
    exit 2
fi

# -----------------------------------
# default overrides

if [ -n "$GCP_MACHINE_TYPE" ]; then
    mtype="$GCP_MACHINE_TYPE"
fi

if [ -n "$GCP_MACHINE_IMAGE" ]; then
    image="$GCP_MACHINE_IMAGE"
fi

if [ -n "$GCP_IMAGE_PROJECT" ]; then
    image_project="$GCP_IMAGE_PROJECT"
fi

if [ -n "$GCP_NETWORK" ]; then
    network="$GCP_NETWORK"
fi

if [ -n "$GCP_SUBNET" ]; then
    subnet="$GCP_SUBNET"
fi

if [ -z "$zone" ]; then
    zone="$GCP_DEFAULT_ZONE"
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
  -i|--imagefamily <name> : Image family as 'ubuntu' (default) or 'centos'.
  -k|--keep               : Sets --keep-disks=data on delete action.
  -l|--list-types         : List available machine-types for a zone.
     --disk-types         : List available disk types for a zone.
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


is_running()
{
    local name="$1"
    local rt=1
    local cmd="gcloud compute instances describe --zone $zone"

    status=$( $cmd $name | grep status: | awk -F: '{ print $2 }' )

    echo ""
    echo "-> status: $name = $status"

    if [ "$status" == "RUNNING" ]; then
        rt=0
    fi

    return $rt
}

start_instance()
{
    local name="$1"
    local zone="$2"
    local async=$3
    local dryrun=$4

    local cmd="gcloud compute instances start $name --zone $zone"

    if [ $async -eq 1 ]; then
        cmd="$cmd --async"
    fi

    echo ""
    echo "-> start_instance() "
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
    local async=$3
    local dryrun=$4

    local cmd="gcloud compute instances stop $name --zone $zone"

    if [ $async -eq 1 ]; then
        cmd="$cmd --async"
    fi

    echo ""
    echo "-> stop_instance() "
    echo "( $cmd )"

    if [ $dryrun -eq 0 ]; then
        ( $cmd )
    fi

    return $?
}


attach_disk()
{
    local volname="$1"
    local gcpname="$2"
    local dryrun=$3
    local rt=0

    echo ""
    echo "-> attach_disk() "
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
    local dryrun=$4
    local rt=0

    cmd="gcloud compute disks create --zone $zone"

    if [ $ssd -eq 1 ]; then
        cmd="$cmd --type=pd-ssd"
    fi

    cmd="$cmd --size=${volsize} ${volname}"

    echo ""
    echo "-> create_disk() "
    echo "( $cmd )"

    if [ $dryrun -eq 0 ]; then
        ( $cmd )
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
        -i|--image*)
            if [[ $2 =~ centos ]]; then
                image=$GCP_CENTOS_IMAGE
                image_project="$GCP_CENTOS_IMAGEPROJECT"
            fi
            shift
            ;;
        -k|--keep)
            keep=1
            ;;
        -l|--list-types)
            list_machine_types
            exit $rt
            ;;
        --disk-types)
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
        echo "Error, subnet defined without network"
        exit 1
    fi
    network="default"
    subnet="default"
fi

if [ -n "$network" ] && [ -z "$subnet" ]; then
    echo "Error, subnet not defined; it is required with --network"
    exit 1
fi

if [ -z "$zone" ]; then
    zone="$GCP_DEFAULT_ZONE"
fi

printf "\n${C_CYN}  GCP Zone ${C_NC}= ${C_WHT}'$zone'${C_NC}\n"
printf "${C_CYN}  Network  ${C_NC}= ${C_WHT}'$network'${C_NC}\n"
printf "${C_CYN}  Subnet   ${C_NC}= ${C_WHT}'$subnet'${C_NC}\n\n"

zone_is_valid $zone
rt=$?
if [ $rt -ne 0 ]; then
    echo "Error, provided zone '$zone' is not valid"
    exit $rt
fi

subnet_is_valid $subnet
if [ $? -ne 0 ]; then
    echo "Error, subnet '$subnet' not found. Has it been creaated?"
    exit 1
fi

if [ $attach -eq 1 ] && [ $volnum -gt 1 ]; then
    if [ $volnum -gt $maxvols ]; then
        echo "Script supports a maximum of $maxvols attached volumes"
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
        cmd="gcloud compute instances create --image-family=${image} --image-project=${image_project}"
        cmd="$cmd --zone ${zone} --machine-type=${mtype} --boot-disk-size=${bootsize} --verbosity error"

        if [ $ssd -eq 1 ]; then
            cmd="$cmd --boot-disk-type=pd-ssd"
        fi

        if [ -n "$network" ]; then
            cmd="$cmd --network ${network} --subnet ${subnet}"
        fi

        if [ $vga -eq 1 ]; then
            cmd="$cmd $GCP_ENABLE_VGA"
        fi

        if [ $ipf -eq 1 ]; then
            cmd="$cmd --can-ip-forward"
        fi

        cmd="$cmd --tags ${tags} ${name}"

        printf "\n( $cmd ) \n"

        if [ $dryrun -eq 0 ]; then
            ( $cmd )
            rt=$?
        fi

        if [ $rt -ne 0 ]; then
            echo "$TDH_PNAME Error in create_instance"
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
                    create_disk "$volname" "$volsize" $ssd $dryrun
                    rt=$?

                    if [ $rt -ne 0 ]; then
                        echo "Error in create_disk() for '$volname', aborting..."
                        exit $rt
                    fi
                fi

                attach_disk "$volname" "$name" $dryrun
                rt=$?

                if [ $rt -ne 0 ]; then
                    echo "Error in attach_disk() for '$volname', rt=$rt, aborting..."
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
        start_instance $name $zone $async $dryrun
        ;;

    stop)
        stop_instance $name $zone $async $dryrun
        ;;

    delete|destroy)
        cmd="gcloud compute instances delete $name --zone $zone --quiet"

        if [ $keep -eq 1 ]; then
            cmd="$cmd --keep-disks=data"
        else
            cmd="$cmd --delete-disks=all"
        fi

        echo "( $cmd )"
        if [ $dryrun -eq 0 ]; then
            ( $cmd )
        fi
        ;;

    describe)
        cmd="gcloud compute instances describe --zone $zone"
        ( $cmd $name )
        ;;
    status)
        is_running $name
        rt=$?
        ;;
    *)
        echo "Action Not Recognized! '$action'"
        echo "$usage"
        rt=1
        break
        ;;
    esac
done

printf "${C_WHT}${TDH_PNAME} Finished. ${C_NC} \n"
exit $rt
