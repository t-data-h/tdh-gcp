#!/bin/bash
#
#  Simple wrapper script for adding a firewall rule for an external
#  host (for ssh)
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/tdh-gcp-config.sh ]; then
    . ${tdh_path}/tdh-gcp-config.sh
fi

# -----------------------------------

gfw="gcloud compute firewall-rules"

name=
action=
network=
dryrun=0
noprompt=0

# -----------------------------------
# default overrides

if [ -n "$GCP_NETWORK" ]; then
    network="$GCP_NETWORK"
fi
# -----------------------------------

usage()
{
    echo ""
    echo " Add GCP rules for SSH Access: "
    echo ""
    echo "Usage: $TDH_NAME [options] <action> <name> <cidr>"
    echo " -h|--help           : Show usage and exit"
    echo " -N|--network <name> : Name of network to apply rule if not default"
    echo "    --dryrun         : Enables dryrun, no action is taken"
    echo " -V|--version        : Show Version info and exit"
    echo ""
    echo " Where <action> is one of the following:"
    echo "   create <name> <cidr> : Creates a new rule allowing SSH access"
    echo "                          from the provided IP Range. The rule name"
    echo "                          is generated from the provided name and the"
    echo "                          network. eg. {network}-allowssh-{name}"
    echo "   delete <name>        : Delete rule by given name"
    echo "   list                 : List the current rules"
    echo ""
}

# MAIN
#
rt=0
names=
ipre='([0-9]{1,3}[\.]){3}[0-9]{1,3}'



while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit $rt
            ;;
        -l|--list)
            ( $gfw list )
            exit $rt
            ;;
        --dryrun)
            dryrun=1
            ;;
        -N|--network)
            network="$2"
            shift
            ;;
        -q|--quiet)
            noprompt=1
            ;;
        -T|--tags)
            tags="$2"
            shift
            ;;
        -V|--version)
            tdh_version
            exit $rt
            ;;
        *)
            action="${1,,}"
            shift
            name="$1"
            shift
            cidr="$1"
            shift $#
            ;;
    esac
    shift
done

if [ -z "$action" ]; then
    usage
    exit 1
fi

if [ -z "$network" ]; then
    network="default"
fi

if [ "$action" == "create" ]; then
    if [ -z "$name" ] || [ -z "$cidr" ]; then
        echo "Error: create action requires name and address"
        usage
        exit 1
    fi
    name="${network}-allow-${name}"
    cmd="$gfw create $name --allow tcp:22 --direction INGRESS --source-ranges $cidr"

    echo "Creating fw-rule '$name'"
    echo "$cmd"
    if [ $dryrun -eq 0 ]; then
        ( $cmd )
        rt=$?
    fi
elif [ "$action" == "delete" ]; then
    if [ -z "$name" ]; then
        echo "Error: target name required"
        usage
        exit 1
    fi
    name="${network}-allow-${name}"
    cmd="$gfw delete $name"

    if [ $noprompt -eq 1 ]; then
        cmd="$cmd --quiet"
    fi

    echo "( $cmd )"
    if [ $dryrun -eq 0 ]; then
        ( $cmd )
        rt=$?
    fi
elif [ "$action" == "list" ]; then
    ( $gfw list )
fi

exit $rt
