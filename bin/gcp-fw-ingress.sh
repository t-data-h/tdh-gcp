#!/usr/bin/env bash
#
#  Wrapper script for 'gcloud compute firewall-rules'
#  specifically for easily manipulating ssh only client 
#  fw rules. 
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../bin/tdh-gcp-env.sh ]; then
    . ${tdh_path}/../bin/tdh-gcp-env.sh
fi

# -----------------------------------

gfw="gcloud compute firewall-rules"

name=
action=
cidr=
protoport=
network="${GCP_NETWORK:-default}"
tags=
dryrun=0
noprompt=0

# -----------------------------------

usage="
Tool to manipulate GCP firewall rules for compute node ingress.

Synopsis:
  $TDH_NAME [options] <action> <name> [cidr] [proto:port]

Options:
  -h|--help             : Show usage and exit
  -N|--network <name>   : Name of network to apply rule if not 'default'
     --dryrun           : Enables dryrun, no action is taken
  -T|--tags <tag1,..>   : Set target tags on rules being created
  -V|--version          : Show Version info and exit
    
Where <action> is one of the following:
  create  <name> <cidr>
         <proto:port>   : Creates a new ingress rule allowing access from
                          the provided IP Range. The rule name provided is
                          appended to a rule prefix of '\$network-allow'.
                          eg. 'oside' = '$network-allow-oside'
  delete    <name>      : Delete a rule by its 'short' name (w/o network). 
  list                  : List the current rules.
  enable    <name>      : Enable a firewall rule that has been disabled.
  disable   <name>      : Disable an existing firewall rule.
  describe  <name>      : Get a full description of a firewall rule.
"


# -----------------------------------
# MAIN
#
ipre='([0-9]{1,3}[\.]){3}[0-9]{1,3}'
names=
rt=0


while [ $# -gt 0 ]; do
    case "$1" in
        'help'|-h|--help)
            echo "$usage"
            exit $rt
            ;;
        -l|--list)
            action="list"
            ;;
        --dryrun|--dry-run)
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
        'version'|-V|--version)
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
    echo "$usage"
    exit 1
fi

if [ -n "$name" ]; then
    name="${network}-allow-${name}"
elif [ "$action" != "list" ]; then
    echo "Fatal, missing <name> parameter"
    echo "$usage"
    exit 1
fi 


case "$action" in
'create') 

    if [[ -z "$cidr" || -z "$protoport" ]]; then
        echo "Error: create action is missing parameters."
        echo "$usage"
        exit 1
    fi

    if [[ ! "$protoport" =~ ":" ]]; then 
        echo "Error: Rule must provide port as 'protocol:port' eg. 'tcp:22'"
        echo "$usage" 
        exit 1
    fi

    args=("--allow $protoport" "--direction INGRESS" "--source-ranges $cidr" "--network $network")

    if [ -n "$tags" ]; then
        args+=("--target-tags $tags")
    fi

    echo "Creating fw-rule '$name'"
    echo "$gfw create $name ${args[@]}"

    if [ $dryrun -eq 0 ]; then
        ( $gfw create $name ${args[@]} )
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
