#!/bin/bash
#
#  Simple wrapper script for adding a firewall rule for an external
#  host (for ssh)
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../bin/tdh-gcp-config.sh ]; then
    . ${tdh_path}/../bin/tdh-gcp-config.sh
fi

# -----------------------------------

gfw="gcloud compute firewall-rules"

name=
action=
network=
tags=
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
    echo " Add GCP fw rules for Inbound SSH Access: "
    echo ""
    echo "Usage: $TDH_NAME [options] <action> <name> <cidr>"
    echo " -h|--help           : Show usage and exit"
    echo " -N|--network <name> : Name of network to apply rule if not default"
    echo "    --dryrun         : Enables dryrun, no action is taken"
    echo " -T|--tags <tag1,..> : Set target tags on rules being created"
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


#CREATE
if [ "$action" == "create" ]; then

    if [ -z "$name" ] || [ -z "$cidr" ]; then
        echo "Error: create action requires name and address"
        usage
        exit 1
    fi
    name="${network}-allow-${name}"
    cmd="$gfw create $name --allow tcp:22 --direction INGRESS --source-ranges $cidr"

    if [ -n "$tags" ]; then
        cmd="$cmd --target-tags $tags"
    fi

    echo "Creating fw-rule '$name'"
    echo "$cmd"
    if [ $dryrun -eq 0 ]; then
        ( $cmd )
        rt=$?
    fi
#DELETE
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
#LIST
elif [ "$action" == "list" ]; then

    ( $gfw list --format="table(
          name,
          network,
          direction,
          sourceRanges.list():label=SRC_RANGES,
          targetTags.list():label=TARGET_TAGS,
          disabled,
          allowed[].map().firewall_rule().list():label=ALLOW
      )" )

fi

exit $rt
