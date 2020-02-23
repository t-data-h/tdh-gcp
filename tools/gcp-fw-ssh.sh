#!/bin/bash
#
#  Wrapper script for 'gcloud compute firewall-rules'
#  specifically for easily manipulating ssh only client 
#  fw rules. 
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../bin/tdh-gcp-config.sh ]; then
    . ${tdh_path}/../bin/tdh-gcp-config.sh
fi

# -----------------------------------

gfw="gcloud compute firewall-rules"

name=
action=
network="default"
tags=
dryrun=0
noprompt=0

# -----------------------------------
# overrides

if [ -n "$GCP_NETWORK" ]; then
    network="$GCP_NETWORK"
fi
# -----------------------------------

usage()
{
    echo ""
    echo " Manipulate GCP fw rules for Inbound SSH Access: "
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
    echo "   delete <name>        : Delete rule by given name. "
    echo "                          Note that network is prefixed to {name}"
    echo "   list                 : List the current rules"
    echo "   enable <name>        : (Re)-Enable a firewall rule"
    echo "   disable <name>       : Disable a firewall rule"
    echo "   describe <name>      : Get full definition of a firewall rule"
    echo ""
}


# MAIN
#
ipre='([0-9]{1,3}[\.]){3}[0-9]{1,3}'
names=
rt=0


while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit $rt
            ;;
        -l|--list)
            action="list"
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
            name="$2"
            cidr="$3"
            shift $#
            ;;
    esac
    shift
done

if [ -z "$action" ]; then
    usage
    exit 1
fi

if [ -n "$name" ]; then
    name="${network}-allow-${name}"
elif [ "$action" != "list" ]; then
    echo "Error, missing <name> parameter"
    usage
    exit 1
fi 


case "$action" in
'create') 

    if [ -z "$cidr" ]; then
        echo "Error: create action requires name and address"
        usage
        exit 1
    fi

    cmd="$gfw create $name --allow tcp:22 --direction INGRESS --source-ranges $cidr --network $network"

    if [ -n "$tags" ]; then
        cmd="$cmd --target-tags $tags"
    fi

    echo "Creating fw-rule '$name'"
    echo "$cmd"

    if [ $dryrun -eq 0 ]; then
        ( $cmd )
        rt=$?
    fi
    ;;

'delete')

    cmd="$gfw delete $name"

    if [ $noprompt -eq 1 ]; then
        cmd="$cmd --quiet"
    fi

    echo "( $cmd )"
    if [ $dryrun -eq 0 ]; then
        ( $cmd )
        rt=$?
    fi
    ;;

'list')
    ( $gfw list --format="table(
          name,
          network,
          direction,
          sourceRanges.list():label=SRC_RANGES,
          targetTags.list():label=TARGET_TAGS,
          disabled,
          allowed[].map().firewall_rule().list():label=ALLOW
      )" )
      ;;

'enable')
    ( $gfw update $name --no-disabled )
    ;;

'disable')
    ( $gfw update $name --disabled )
    ;;

'describe')
    ( $gfw describe $name )
    ;;

*)
    echo "Action not recognized"
    ;;
esac

exit $rt
