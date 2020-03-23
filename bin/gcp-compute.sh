#!/bin/bash
#
#  gcp-compute.sh -  Manage GCP Compute Instances
#
#  @author Timothy C. Arland <tcarland@gmail.com>
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/tdh-gcp-config.sh ]; then
    . ${tdh_path}/tdh-gcp-config.sh
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
# default overrides

if [ -n "$GCP_MACHINE_TYPE" ]; then
    mtype="$GCP_MACHINE_TYPE"
fi

if [ -n "$GCP_MACHINE_IMAGE" ]; then
    image="$GCP_MACHINE_IMAGE"
fi

if [ -n "$GCP_IMAGE_PROJECT" ]; then
    image="$GCP_IMAGE_PROJECT"
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

usage()
{
    echo ""
    echo " Manage GCP Compute Engine instances: "
    echo ""
    echo "Usage: $TDH_PNAME [options] <action> <instance-name>"
    echo "  -a|--async           : Use 'async' option with gcloud commands"
    echo "  -A|--attach          : Init and attach data disk(s) on 'create'"
    echo "  -b|--bootsize <xxGB> : Size of instance boot disk"
    echo "  -d|--disksize <xxGB> : Size of attached volume(s)"
    echo "  -D|--disknum   <n>   : Number of attached volumes, if more than 1"
    echo "  -F|--ip-forward      : Enables IP Forwarding for the instance"
    echo "  -h|--help            : Display usage and exit"
    echo "  -k|--keep            : Sets --keep-disks=data on delete action"
    echo "  -l|--list-types      : List available machine-types for a zone"
    echo "     --disk-types      : List available disk types for a zone"
    echo "     --dryrun          : Enable dryrun, no action is taken"
    echo "  -N|--network <name>  : GCP Network name when not using default"
    echo "  -n|--subnet  <name>  : Used with --network to define the subnet"
    echo "  -p|--prefix  <name>  : Prefix name to use for instances"
    echo "  -S|--ssd             : Use SSD as attached disk type"
    echo "  -t|--type            : Machine type to use for instances"
    echo "  -T|--tags  <tag1,..> : A set of tags to use for instances"
    echo "  -z|--zone  <name>    : Set GCP zone "
    echo "  -v|--vga             : Attach a display device at create"
    echo "  -X|--no-serial       : Don't enable logging to serial by default"
    echo "  -V|--version         : Show version info and exit"
    echo ""
    echo " Where <action> is one of the following: "
    echo "     create            :  Initialize new GCP instance"
    echo "     start             :  Start an existing GCP instance"
    echo "     stop              :  Stop a running instance"
    echo "     delete            :  Delete an instance"
    echo ""
    echo "  Default Machine Type is '$mtype'"
    echo "  Default Image is        '$image'"
    echo "  Default Boot Disk size  '$bootsize'"
    echo "  Default GCP Zone is     '$GCP_DEFAULT_ZONE'"
    echo "  Default tags are set to '$prefix'"
    echo ""
    echo " The following environment variables are honored for overrides:"
    echo "  GCP_MACHINE_TYPE, GCP_MACHINE_IMAGE, GCP_IMAGE_PROJECT, GCP_ZONE"
    echo "  GCP_NETWORK, GCP_SUBNET"
    echo ""
}


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
        -h|--help)
            usage
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
        -V|--version)
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
    usage
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

echo ""
echo "  GCP Zone = '$zone'"
echo "  Network  = '$network'"
echo "  Subnet   = '$subnet'"

zone_is_valid $zone
rt=$?
if [ $rt -ne 0 ]; then
    echo "Error, provided zone '$zone' not valid"
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
    if [ -n "$prefix" ]; then
        ( echo $name | grep "^${prefix}-" >/dev/null 2>&1 )
        if [ $? -ne 0 ]; then
            name="${prefix}-${name}"
        fi
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

        echo ""
        echo "( $cmd )"

        if [ $dryrun -eq 0 ]; then
            ( $cmd )
            rt=$?
        fi

        if [ $rt -ne 0 ]; then
            echo "Error in create_instance()"
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
        usage
        rt=1
        break
        ;;
    esac
done

echo "$TDH_PNAME Finished."
exit $rt
