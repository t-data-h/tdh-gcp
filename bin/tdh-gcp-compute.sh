#!/bin/bash
#
PNAME=${0##*\/}
VERSION="0.2.5"

zone="us-west1-b"
mtype="n1-standard-4"
disksize="256GB"
bootsize="64GB"
prefix="tdh"

name=
action=
diskname=
attach=0
ssd=0
dryrun=0

# -----------------------------------

# default zone
if [ -z "$GCP_ZONE" ]; then
    export GCP_ZONE="$zone"
else
    zone="$GCP_ZONE"
fi

# default machinetype
if [ -z "$GCP_MACHINE_TYPE" ]; then
    export GCP_MACHINE_TYPE="$mtype"
else
    mtype="$GCP_MACHINE_TYPE"
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
    echo "  -l|--list             : List available machine-types for the zone"
    echo "  -p|--prefix <name>    : Prefix name to use for instances"
    echo "  -n|--dryrun           : Enable dryrun, no actions are run"
    echo "  -S|--ssd              : Use SSD as attached disk type"
    echo "  -t|--type             : Machine type to use for instance(s)"
    echo "  -z|--zone <name>      : Set GCP zone (use -l to list)"
    echo ""
    echo " Where <action> is one of the following "
    echo "     init               :  Initialize new GCP instance"
    echo "     start              :  Start an existing GCP instance"
    echo "     stop               :  Stop a running instance"
    echo "     delete             :  Delete an instance"
    echo ""
    echo "  Default GCP Zone is $zone"
    echo "  Default Machine Type is $mtype"
    echo ""
}


version()
{
    echo "$PNAME: v$VERSION"
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

    status=$( gcloud compute instances describe ${name} | grep status: | awk -F: '{ print $2 }' )

    if [ "$status" == "RUNNING" ]; then
        rt=0
    fi

    return $rt
}


stop_instance()
{
    local name="$1"

    ( gcloud compute instances stop ${name} )

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

    cmd="$cmd --size=${disksize} --zone ${GCP_ZONE} ${diskname}"

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
            exit 0
            ;;
        -l|--list)
            list_machine_types
            exit 0
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
        -n|--dryrun)
            dryrun=1
            ;;
        -s|--use-ssd)
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
            exit 0
            ;;
        *)
            action="$1"
            name="$2"
            shift $#
            ;;
    esac
    shift
done


if [ -z "$name" ]; then
    usage
    exit 1
fi

if [ -z "$zone" ] || [ -z "$mtype" ]; then
    echo "Error in config, zone or machine type"
    exit 1
fi

if [ -n "$prefix" ]; then
    name="${prefix}-${name}"
fi

if [ -z "$diskname" ]; then
    diskname="${name}-disk1"
fi


case "$action" in
create)
    cmd="gcloud compute instances create --image-family=centos-7 --image-project=centos-cloud"
    cmd="$cmd --machine-type=${mtype} --boot-disk-size=${bootsize}"

    if [ $ssd -eq 1 ]; then
        cmd="$cmd --boot-disk-type=pd-ssd"
    fi
    cmd="$cmd --zone ${zone} --tags ${prefix} ${name}"

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

stop)
    echo "( gcloud compute instances stop ${name} )"
    if [ -z "$dryrun" ]; then
        ( gcloud compute instances stop ${name} )
    fi
    ;;

delete)
    echo "( gcloud compute instances delete ${name} )"
    ;;

status)
    ( gcloud compute instances describe ${name} )
    ;;
esac

echo ""
echo "$PNAME Finished."

exit $rt
