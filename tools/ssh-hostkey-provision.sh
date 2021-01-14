#!/usr/bin/env bash
#
#  Essentially remote ssh-copy-id for a group of hosts where one
#  host needs ssh keys for all hosts. The use of ssh-copy-id
#  was not utilized to avoid having to push a private identity 
#  file out to an insecure host.
#
#  @author Timothy C. Arland <tcarland@gmail.com>
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../bin/tdh-gcp-config.sh ]; then
    . ${tdh_path}/../bin/tdh-gcp-config.sh
fi

# -----------------------------------

user="$USER"
pubhosts=
pvthosts=
pubfile=
pvtfile=
ident=
cert=
master=
master_ip=
master_id=
idfile=

# -----------------------------------

usage()
{
    echo ""
    echo "$TDH_PNAME [options] <hosts_file> [master_host]"
    echo " -H|--pvthosts <file> : Add a custom 'hosts' file to all hosts."
    echo " -h|--help            : Show usage info and exit."
    echo " -u|--user   <user>   : Name of remote user, if not '$user'."
    echo " -i  <identity>       : SSH Identity file for connecting to hosts."
    echo " -M  <master_id>      : SSH public key of an existing master."
    echo "   <hosts_file>       : File containing the list of hosts and IPs"
    echo "   [master_host]      : Defines the master host of cluster."
    echo ""
    echo "  Note the hosts file is intended to be in the same format as "
    echo "  a system '/etc/hosts' file".
    echo ""
    echo "  If a 'master_host' is provided without an id file (-M), "
    echo "  ssh-keygen is run on the target host to obtain a key-pair; "
    echo "  else, if a public key is provided, it is used as the master "
    echo "  certificate and keygen is not run on the target host."
    echo ""
}

# -----------------------------------

rt=0

while [ $# -gt 0 ]; do
    case "$1" in
        'help'|-h|--help)
            usage
            exit 0
            ;;
        -H|--pvthosts)
            pvthosts="$2"
            shift
            ;;
        -i|--identity)
            ident="$2"
            shift
            ;;
        -M|--masterid)
            master_id="$2"
            shift
            ;;
        -u|--user)
            user="$2"
            shift
            ;;
        'version'|-V|--version)
            tdh_version
            exit 0
            ;;
        *)
        pubhosts="$1"
        master="$2"
        shift $#
    esac
    shift
done


if [ -z "$pubhosts" ]; then
    usage
    exit 1
fi

if [[ -z "$master" && -z "$master_id" ]]; then
    echo "$PNAME Error: No Master is defined"
    exit 1
fi

if [ -n "$master_id" ] && [ ! -r "$master_id" ]; then
    echo "$TDH_PNAME Error reading master_id '$master_id'"
    exit 1
fi

if [ -n "$ident" ]; then
    ( ssh-add $ident )
fi

if [ -n "$pvthosts" ]; then
    pvtfile=$(basename $pvthosts)
fi

# -------------------

if [ -z "$master_id" ]; then
    master_ip=$( cat $pubhosts 2>/dev/null | grep $master | awk '{ print $1 }' )
    master_id="master-$master-id_ed25519.pub"

    if [ -z "$master_ip" ]; then
        echo " -> Error determining master IP, hosts file correct?"
        exit 1
    fi

    echo " -> Configuring master host '$master' as primary"

    # Remove any existing known_hosts entry for the master
    ( ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "$master" > /dev/null 2>&1 )

    # Copy private hosts file
    if [ -n "$pvthosts" ]; then
        echo " -> Copy private hosts to master"
        ( scp -oStrictHostKeyChecking=no $pvthosts ${user}@${master}: )
        ( ssh -oStrictHostKeyChecking=no ${user}@${master} "sudo sh -c 'cat $pvtfile >> /etc/hosts'; rm $pvtfile" )
    fi

    # keygen for master host
    ( ssh -oStrictHostKeyChecking=no ${user}@${master} "ssh-keygen -t ed25519 -a 100 -N '' -f ~/.ssh/id_ed25519"  )
    # acquire our master id
    ( scp -oStrictHostKeyChecking=no ${user}@${master}:.ssh/id_ed25519.pub ./${master_id} )
    ( ssh -oStrictHostKeyChecking=no ${user}@${master} "ssh-keyscan -H $master >> .ssh/known_hosts" )
fi

IFS=$'\n'
idfile=$(basename $master_id)

for host in $( cat $pubhosts | sort ); do
    ip=$( echo $host | awk '{ print $1 }' )
    name=$( echo $host | awk '{ print $2 }' )

    # Explicitly remove any local existing entries for these hosts"
    ( ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "$name" > /dev/null 2>&1 )

    echo ""
    echo " -> Copy ssh id:  $name"
    ( scp -oStrictHostKeyChecking=no $master_id ${user}@${name}: )
    ( ssh -oStrictHostKeyChecking=no ${user}@${name} "cat $idfile >> .ssh/authorized_keys && chmod 600 .ssh/authorized_keys; rm $idfile" )

    echo " -> Set hostname $name"
    ( ssh -oStrictHostKeyChecking=no ${user}@${name} "sudo hostname $name; sudo sh -c 'echo $name > /etc/hostname'" )

    if [ -n "$pvthosts" ]; then
        echo " -> Add private hosts file"
        ( scp -oStrictHostKeyChecking=no $pvthosts ${user}@${name}: )
        ( ssh -oStrictHostKeyChecking=no ${user}@${name} "sudo sh -c 'cat $pvtfile >> /etc/hosts'; rm $pvtfile" )
    fi

    # add known_hosts entry
    echo " -> Add to known_hosts"
    ( ssh -oStrictHostKeyChecking=no ${user}@${master} "ssh-keyscan -H $name >> .ssh/known_hosts" 2>/dev/null )
done

echo "$PNAME Finished."

exit 0
