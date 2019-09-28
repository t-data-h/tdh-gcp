#!/bin/bash
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
disksize="$GCP_DEFAULT_DISKSIZE"
image="$GCP_DEFAULT_IMAGE"
image_project="$GCP_DEFAULT_IMAGEPROJECT"

name=
action=
diskname=
network=
subnet=
tags=
attach=0
ssd=0
vga=0
dryrun=0
keep=0

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

# -----------------------------------

usage()
{
    echo ""
    echo " Manage GCP Compute Engine instances: "
    echo ""
    echo "Usage: $TDH_PNAME [options] <action> <instance-name>"
    echo "  -A|--attach          : Init and attach a data disk on 'create'"
    echo "  -b|--bootsize <xxGB> : Size of instance boot disk"
    echo "  -d|--disksize <xxGB> : Size of attached disk"
    echo "  -h|--help            : Display usage and exit"
    echo "  -k|--keep            : Sets --keep-disks=data on delete action"
    echo "  -l|--list            : List available machine-types for a zone"
    echo "     --dryrun          :  Enable dryrun, no action is taken"
    echo "  -N|--network <name>  : GCP Network name when not using default"
    echo "  -n|--subnet <name>   : Used with --network to define the subnet"
    echo "  -p|--prefix <name>   : Prefix name to use for instances"
    echo "  -S|--ssd             : Use SSD as attached disk type"
    echo "  -t|--type            : Machine type to use for instances"
    echo "  -T|--tags <tag1,..>  : A set of tags to use for instances"
    echo "  -z|--zone <name>     : Set GCP zone "
    echo "  -v|--vga             : Attach a display device at create"
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
    echo "  Default tags are set to '$prefix' or --prefix"
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

    echo $status
    if [ "$status" == "RUNNING" ]; then
        rt=0
    fi

    return $rt
}


stop_instance()
{
    local name="$1"
    local cmd="gcloud compute instances stop --zone $zone"

    cmd="$cmd $name"
    echo ""
    echo "( $cmd )"

    ( $cmd )

    return $?
}


attach_disk()
{
    local diskname="$1"
    local name="$2"
    local dryrun=$3
    local rt=0

    echo ""
    echo "( gcloud compute instances attach-disk --disk ${diskname} ${name} )"

    if [ $dryrun -eq 0 ]; then
        ( gcloud compute instances attach-disk --disk ${diskname} ${name} )
        rt=$?
    fi

    return $rt
}


create_disk()
{
    local diskname="$1"
    local disksize="$2"
    local ssd=$3
    local dryrun=$4
    local rt=0

    cmd="gcloud compute disks create --zone $zone"

    if [ $ssd -eq 1 ]; then
        cmd="$cmd --type=pd-ssd"
    fi

    cmd="$cmd --size=${disksize} ${diskname}"

    echo ""
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

while [ $# -gt 0 ]; do
    case "$1" in
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
        -l|--list)
            list_machine_types
            exit $rt
            ;;
        -d|--disksize)
            disksize="$2"
            shift
            ;;
        -D|--diskname)
            diskname="$2"
            shift
            ;;
        -k|--keep)
            keep=1
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
        -z|--zone)
            zone="$2"
            shift
            ;;
        -v|--vga)
            vga=1
            ;;
        -V|--version)
            tdh_version
            exit $rt
            ;;
        *)
            action="$1"
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

if [ -n "$network" ] && [ -z "$subnet" ]; then
    echo "Error, subnet not defined; it is required with --network"
    exit 1
fi

if [ -z "$zone" ]; then
    zone="$GCP_DEFAULT_ZONE"
fi
echo "  GCP Zone = '$zone'"

zone_is_valid $zone
rt=$?
if [ $rt -ne 0 ]; then
    echo "Error, provided zone '$zone' not valid"
    exit $rt
fi

if [ -n "$subnet" ]; then
    subnet_is_valid $subnet
    if [ $? -ne 0 ]; then
        echo "Error, subnet '$subnet' not found. Has it been creaated?"
        exit $?
    fi
fi

for name in $names; do
    if [ -n "$prefix" ]; then
        ( echo $name | grep "^${prefix}-" >/dev/null 2>&1 )
        if [ $? -ne 0 ]; then
            name="${prefix}-${name}"
        fi
    fi

    if [ -z "$diskname" ]; then
        diskname="${name}-disk1"
    fi

    case "$action" in
    create)
        cmd="gcloud compute instances create --image-family=${image} --image-project=${image_project}"
        cmd="$cmd --zone ${zone} --machine-type=${mtype} --boot-disk-size=${bootsize}"

        if [ $ssd -eq 1 ]; then
            cmd="$cmd --boot-disk-type=pd-ssd"
        fi
        if [ -n "$network" ]; then
            cmd="$cmd --network ${network} --subnet ${subnet}"
        fi
        if [ $vga -eq 1 ]; then
            cmd="$cmd $GCP_ENABLE_VGA"
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

        if [ $attach -gt 0 ]; then
            create_disk "$diskname" "$disksize" $ssd $dryrun
            rt=$?

            if [ $rt -ne 0 ]; then
                echo "Error in create_disk()"
                exit $rt
            fi

            attach_disk "$diskname" "$name" $dryrun
            rt=$?

            if [ $rt -ne 0 ]; then
                echo "Error in attach_disk() rt=$rt"
                exit $rt
            fi
        fi
        ;;

    start)
        cmd="gcloud compute instances start --zone $zone"

        echo "( $cmd $name )"
        if [ $dryrun -eq 0 ]; then
            ( $cmd $name )
        fi
        ;;

    stop)
        if [ $dryrun -eq 0 ]; then
            stop_instance $name
        fi
        ;;

    delete)
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
