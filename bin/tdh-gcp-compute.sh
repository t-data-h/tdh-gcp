#!/bin/bash
#
PNAME=${0##*\/}
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../etc/tdh-gcp-config.sh ]; then
    . ${tdh_path}/../etc/tdh-gcp-config.sh
fi

# -----------------------------------

prefix="$TDH_GCP_PREFIX"

zone=
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
attach=0
ssd=0
dryrun=0

# -----------------------------------
# default overrides

if [ -n "$GCP_ZONE" ]; then
    zone="$GCP_ZONE"
fi

if [ -n "$GCP_MACHINE_TYPE" ]; then
    mtype="$GCP_MACHINE_TYPE"
fi

if [ -n "$GCP_MACHINE_IMAGE" ]; then
    image="$GCP_MACHINE_IMAGE"
fi

# -----------------------------------

usage()
{
    echo ""
    echo " Manage GCP Compute Engine instances: "
    echo ""
    echo "Usage: $PNAME [options] <action> <instance-name>"
    echo "  -A|--attach           : Init and attach a data disk on 'create'"
    echo "  -b|--bootsize <xxGB>  : Size of instance boot disk"
    echo "  -d|--disksize <xxGB>  : Size of attached disk"
    echo "  -h|--help             : Display usage and exit"
    echo "  -l|--list             : List available machine-types for a zone"
    echo "  -N|--network <name>   : GCP Network name when not using default"
    echo "  -n|--subnet <name>    : Used with --network to define the subnet"
    echo "  -p|--prefix <name>    : Prefix name to use for instances"
    echo "  -S|--ssd              : Use SSD as attached disk type"
    echo "  -t|--type             : Machine type to use for instance(s)"
    echo "  -z|--zone <name>      : Set GCP zone (use -l to list)"
    echo "  -V|--version          : Show version info and exit"
    echo ""
    echo " Where <action> is one of the following "
    echo "     create             :  Initialize new GCP instance"
    echo "     start              :  Start an existing GCP instance"
    echo "     stop               :  Stop a running instance"
    echo "     delete             :  Delete an instance"
    echo ""
    echo "  Default Machine Type is '$mtype'"
    echo "  Default Image is        '$image'"
    echo "  Default Boot Disk size  '$bootsize'"
    echo ""
}


version()
{
    echo "$PNAME: v$TDH_GCP_VERSION"
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
    local cmd="gcloud compute instances describe"

    if [ -n "$zone" ]; then
        cmd="$cmd --zone $zone"
    fi

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
    local cmd="gcloud compute instances stop"

    if [ -n "$zone" ]; then
        cmd="$cmd --zone $zone"
    fi

    echo ""
    echo "( $cmd )"
    cmd="$cmd ${name}"

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

    cmd="gcloud compute disks create"

    if [ $ssd -eq 1 ]; then
        cmd="$cmd --type=pd-ssd"
    fi

    if [ -n "$zone" ]; then
        cmd="$cmd --zone ${zone}"
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
        -p|--prefix)
            prefix="$2"
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
        -S|--ssd)
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
            version
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


if [ -z "$names" ]; then
    version
    usage
    exit 1
fi

if [ -n "$network" ] && [ -z "$subnet" ]; then
    echo "Error, subnet not defined; it is required with --network"
    exit 1
fi

echo ""
version
echo ""

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
        cmd="$cmd --machine-type=${mtype} --boot-disk-size=${bootsize}"

        if [ $ssd -eq 1 ]; then
            cmd="$cmd --boot-disk-type=pd-ssd"
        fi
        if [ -n "$network" ]; then
            cmd="$cmd --network ${network} --subnet ${subnet}"
        fi
        if [ -n "$zone" ]; then
            cmd="$cmd --zone ${zone}"
        fi

        cmd="$cmd --tags ${prefix} ${name}"

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
        cmd="gcloud compute instances start" 
        if [ -n "$zone" ]; then
            cmd="$cmd --zone $zone"
        fi
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
        cmd="gcloud compute instances delete"
        if [ -n "$zone" ]; then
            cmd="$cmd --zone $zone"
        fi
        cmd="$cmd $name"

        echo "( $cmd )"
        if [ $dryrun -eq 0 ]; then
            ( $cmd )
        fi
        ;;

    describe)
        cmd="gcloud compute instances describe"
        if [ -n "$zone" ]; then
            cmd="$cmd --zone $zone"
        fi
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

echo ""
echo "$PNAME Finished."

exit $rt
