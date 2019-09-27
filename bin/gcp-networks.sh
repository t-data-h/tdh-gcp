#!/bin/bash
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../etc/tdh-gcp-config.sh ]; then
    . ${tdh_path}/../etc/tdh-gcp-config.sh
fi

# -----------------------------------

prefix="$TDH_GCP_PREFIX"
region="$GCP_REGION"
addr=
network=
subnet=
yes=0
dryrun=0

# -----------------------------------

if [ -z "$region" ]; then
    region=$GCP_DEFAULT_REGION
fi

# -----------------------------------


usage()
{
    echo ""
    echo " Manage GCP Subnets: "
    echo ""
    echo "Usage: $TDH_PNAME [-a iprange] {options} [action] "
    echo "  -a|--addr  <ipaddr/mb> :  Ip Address range of the subnet (required)"
    echo "  -r|--region <name>     :  Region to create the subnet"
    echo "                            Default region is currently '$region'"
    echo "  -y|--yes               :  Do not prompt on create. This will auto-create"
    echo "                            the network if it does not already exist"
    echo ""
    echo " Where <action> is one of the following: "
    echo "  create [network] [subnet] :  Create a new subnet (& optionally network)"
    echo "    list-networks           :  List available networks"
    echo "    list-subnets            :  List available subnets by region"
    echo "  delete-subnet    [subnet] :  Delete a custom subnet"
    echo "  delete-network   [subnet] :  Delete a network"
    echo ""
}


ask()
{
    local prompt="y/n"
    local default=
    local REPLY=

    while true; do
        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        fi

        read -p "$1 [$prompt] " REPLY

        if [ -z "$REPLY" ]; then
            REPLY=$default
        fi

        case "$REPLY" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac
    done
}


create_network()
{
    local net="$1"
    local rtn=0

    echo "( gcloud compute networks create $net --subnet-mode=custom )"
    if [ $dryrun -eq 0 ]; then
        ( gcloud compute networks create $net --subnet-mode=custom )
        rtn=$?
    fi

    return $rtn
}


delete_network()
{
    local net="$1"
    local rtn=0

    echoe "( gcloud compute networks delete $net )"
    if [ $dryrun -eq 0 ]; then
        ( gcloud compute networks delete $net )
        rtn=$?
    fi

    return $rtn
}


create_subnet()
{
    local net="$1"
    local subnet="$2"
    local reg="$3"
    local addy="$4"
    local rtn=0

    echo "( gcloud compute networks subnet create $subnet \
      --network $net --region $reg \
      --range $addy )"
    if [ $dryrun -eq 0 ]; then 
        ( gcloud compute networks subnet create $subnet --network $net --region $reg --range $addy )
        rtn=$?
    fi

    return $rtn
}


delete_subnet()
{
    local net="$1"
    local reg="$2"
    local rtn=0

    echoe "( gcloud compute networks subnets delete $net --region $reg )"
    if [ $dryrun -eq 0 ]; then
        ( gcloud compute networks subnets delete $net --region $reg )
        rtn=$?
    fi

    return $rtn
}



# MAIN
#
rt=0

while [ $# -gt 0 ]; do
    case "$1" in
        -a|--addr)
            addr="$2"
            shift
            ;;
        -h|--help)
            usage
            exit $rt
            ;;
        --dryrun)
            dryrun=1
            ;;
        -r|--region)
            region="$2"
            shift
            ;;
        -y|--yes)
            yes=1
            ;;
        -V|--version)
            tdh_version
            exit $rt
            ;;
        *)
            action="$1"
            network="$2"
            subnet="$3"
            shift $#
            ;;
    esac
    shift
done

tdh_version

if [ -z "$action" ]; then
    usage
    exit 1
fi



case "$action" in
create)
    if [ -z "$network" ] || [ -z "$subnet" ]; then
        echo "Error, network and subnet must both be defined on create"
        exit 1
    fi

    if [ -z "$addr" ]; then
        echo "Error, address range must be provided for the subnet"
        exit 1
    fi

    # validate region 
    region_is_valid $region
    rt=$?

    if [ $rt -ne 0 ]; then
        echo "Error region is invalid: '$region'"
        exit $rt
    fi
    echo "  GCP Region = '$region'"

    # validate Network
    network_is_valid $network
    rt=$?

    if [ $rt -ne 0 ]; then
        crnet=0
        
        echo " => Network not found!"

        if [ $yes -eq 0 ]; then
            if ask "Create new network '$network' in region '$region'?" Y; then
                crnet=1
            fi
        else
            crnet=1
        fi

        # Create the Network
        if [ $crnet -eq 1 ]; then
            create_network $network
            rt=$?
            if [ $rt-ne 0 ]; then
                echo "Error creating network, aborting.."
                exit $rt
            fi
        fi
    fi

    # Create the Subnet
    create_subnet $network $subnet $region $addy
    rt=$?

    if [ $rt -ne 0 ]; then
        echo "Error in create_subnet"
    fi
    ;;

list-networks)
    list_networks
    ;;
list-subnets)
    list_subnets $region
    ;;
*)
    ;;
esac

echo ""
echo "$TDH_PNAME Finished."
exit $rt