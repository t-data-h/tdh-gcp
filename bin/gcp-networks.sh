#!/bin/bash
#
#  gcp-networks.sh - Manage GCP VPC Networks
#
#  @author Timothy C. Arland <tcarland@gmail.com>
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../bin/tdh-gcp-env.sh ]; then
    . ${tdh_path}/../bin/tdh-gcp-env.sh
fi

# -----------------------------------

prefix="$TDH_GCP_PREFIX"
region="${GCP_REGION:-${GCP_DEFAULT_REGION}}"
network="$GCP_NETWORK"
subnet="$GCP_SUBNET"
addr=
yes=0
dryrun=0

# -----------------------------------

usage="
Create and Manage GCP VPC Networks and Subnets.

Synopsis:
  $TDH_PNAME [-a iprange] {options} [action]

Options:
  -a|--addr  <ipaddr/mb> :  Ip Address range of the subnet (required)
  -r|--region <name>     :  Region to create the subnet. Default is '$region'
  -n|--dryrun            :  Enable dryrun, no action is taken.
  -y|--yes               :  Do not prompt on create. This will auto-create
                            the network if it does not already exist.
 
Where <action> is one of the following: 
  create [network] [subnet] :  Create a new network and subnet.
  list-networks             :  List available networks.
  list-subnets              :  List available subnets by region.
  delete-subnet    [subnet] :  Delete a custom subnet.
  delete-network   [subnet] :  Delete a network.
  describe        [network] :  Get GCP network details.
  describe-subnet  [subnet] :  Describes the GCP subnet.
 
Delete actions require that no existing resources use the 
given network|subnet.
"

# -----------------------------------

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

    echo "( gcloud compute networks subnets create $subnet --network $net --region $reg --range $addy )"
    if [ $dryrun -eq 0 ]; then
        ( gcloud compute networks subnets create $subnet --network $net --region $reg --range $addy )
        rtn=$?
    fi

    return $rtn
}


delete_subnet()
{
    local net="$1"
    local reg="$2"
    local rtn=0

    echo "( gcloud compute networks subnets delete $net --region $reg )"
    if [ $dryrun -eq 0 ]; then
        ( gcloud compute networks subnets delete $net --region $reg )
        rtn=$?
    fi

    return $rtn
}


# -----------------------------------
# MAIN
#
rt=0

while [ $# -gt 0 ]; do
    case "$1" in
        -a|--addr)
            addr="$2"
            shift
            ;;
        'help'|-h|--help)
            echo "$usage"
            exit $rt
            ;;
        -n|--dryrun|--dry-run)
            dryrun=1
            ;;
        -r|--region)
            region="$2"
            shift
            ;;
        -y|--yes)
            yes=1
            ;;
        'version'|-V|--version)
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
    echo "$usage"
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

    # Ensure Subnet doesn't already exist
    subnet_is_valid $subnet
    if [ $? -eq 0 ]; then
        echo "Error! Subnet '$subnet' already exists"
        exit 1
    fi

    # validate Network
    network_is_valid $network
    rt=$?

    if [ $rt -ne 0 ]; then
        crnet=0

        echo "GCP Network '$network' not found..."

        if [ $yes -eq 0 ]; then
            if ask "Create new network '$network' in region '$region'?" Y; then
                crnet=1
            else
                echo "Aborting script as parent network must first exist"
                exit 1
            fi
        else
            echo "  Auto-creating network."
            crnet=1
        fi

        # Create the Network
        if [ $crnet -eq 1 ]; then
            create_network $network
            rt=$?
            if [ $rt -ne 0 ]; then
                echo "Error creating network, aborting.."
                exit $rt
            fi
        fi
    fi

    # Create the Subnet
    echo ""
    echo "-> Creating subnet '$subnet' [$addr] in region '$region'"
    create_subnet $network $subnet $region $addr
    rt=$?

    if [ $rt -ne 0 ]; then
        echo "Error in create_subnet"
        exit $rt
    fi

    # Create default fw rule
    rule_name="$subnet-allow-local"
    gfw="gcloud compute firewall-rules"

    ( $gfw list --filter="name=($rule_name)" 2>/dev/null | grep "$rule_name" )

    if [ $? -ne 0 ]; then
        cmd="$gfw create $rule_name --network $network --action allow"
        cmd="$cmd --direction ingress --source-ranges $addr --rules all"

        echo "Creating fw-rule '$rule_name': "
        echo "( $cmd )"

        if [ $dryrun -eq 0 ]; then
            ( $cmd )
            rt=$?
            if [ $rt -ne 0 ]; then
                echo "Error creating firewall-rules"
            fi
        fi
    else
        echo "-> Firewall-rule '$rule_name' already exists."
    fi
    ;;

list-networks)
    list_networks
    ;;
list-subnets)
    list_subnets $region
    ;;
describe|describe-network)
    if network_is_valid $network; then
        ( gcloud compute networks describe $network )
    fi
    ;;
describe-subnet)
    if subnet_is_valid $network; then
        ( gcloud compute networks subnets describe $network )
    fi
    ;;
*)
    echo "Action Not Recognized! '$action'"
    echo "$usage"
    rt=1
    ;;
esac

echo ""
echo "$TDH_PNAME Finished."
exit $rt
