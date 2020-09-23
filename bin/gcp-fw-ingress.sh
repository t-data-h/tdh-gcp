#!/usr/bin/env bash
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
cidr=
protoport=
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
    echo " Manipulate GCP fw rules for ingress access."
    echo ""
    echo "Usage: $TDH_NAME [options] <action> <name> [cidr] [proto:port]"
    echo " -h|--help              : Show usage and exit"
    echo " -N|--network <name>    : Name of network to apply rule if not default"
    echo "    --dryrun            : Enables dryrun, no action is taken"
    echo " -T|--tags <tag1,..>    : Set target tags on rules being created"
    echo " -V|--version           : Show Version info and exit"
    echo ""
    echo "Where <action> is one of the following:"
    echo "  create  <name>        : Creates a new ingress rule allowing access"
    echo "    <cidr> <proto:port>   from the provided IP Range. The rule name is"
    echo "                          generated from the name and network."
    echo "  delete   <name>       : Delete a rule by given name or tag (w/o network). "
    echo "  list                  : List the current rules"
    echo "  enable   <name>       : Enable a firewall rule that has been disabled."
    echo "  disable  <name>       : Disable an existing firewall rule."
    echo "  describe <name>       : Get a full description of a firewall rule."
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
            protoport="$4"
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
    echo "Fatal, missing <name> parameter"
    usage
    exit 1
fi 


case "$action" in
'create') 

    if [[ -z "$cidr" || -z "$protoport" ]; then
        echo "Error: create action is missing parameters."
        usage
        exit 1
    fi

    if [[ ! "$protoport" =~ ":" ]]; then 
        echo "Error: Rule must provide port as 'protocol:port' eg. 'tcp:22'"
        usage 
        exit 1
    fi

    cmd="$gfw create $name --allow $protoport --direction INGRESS --source-ranges $cidr --network $network"

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
