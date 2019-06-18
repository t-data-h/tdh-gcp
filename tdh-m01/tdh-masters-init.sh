#!/bin/bash
#
#  Initialize master GCP instances.
#
PNAME=${0##*\/}
tdh_path=$(dirname "$(readlink -f "$0")")
 
# -----------------------------------
 
prefix="tdh"
names="m01 m02 m03"
mtype="n1-standard-4"
zone="us-west1-b"
disksize="200GB"
pwfile=
dryrun=1
noprompt=0
action=
rt=

# -----------------------------------

usage() {
    echo ""
    echo "Usage: $PNAME [options] <run>  host1 host2 ..."
    echo "  -d|--disksize <xxGB>  : Size of attached disk"
    echo "  -h|--help             : Display usage and exit"
    echo "  -p|--prefix <name>    : Prefix name to use for instances"
    echo "  -P|--pwfile <file>    : File containing mysql root password"
    echo "  -S|--ssd              : Use SSD as attached disk type"
    echo "  -t|--type             : Machine type to use for instance(s)"
    echo "  -y|--noprompt         : Will not prompt for password"
    echo "                          --pwfile must be provided for mysql"
    echo "  -z|--zone <name>      : Set GCP zone"
    echo ""
    echo " Where <action> is 'run'. Any other action enables a dryrun," 
    echo " followed by a list of names that become '\$prefix-\$name'"
    echo " eg. '$PNAME test m01 m02 m03' will dryrun 3 master nodes with"
    echo " the names: $prefix-m01, $prefix-m02, and $prefix-m03"
    echo ""
    echo "  Default GCP Zone is:     $zone"
    echo "  Default Machine Type is: $mtype"
    echo "  Default host prefix is:  $prefix"
    echo ""
}

read_password()
{
    local prompt="Password: "
    local pass=
    local pval=

    read -s -p "$prompt" pass
    echo ""
    read -s -p "Repeat $prompt" pval
    echo ""

    if [[ "$pass" != "$pval" ]]; then
        echo "ERROR! Passwords do not match!"
        return 1
    fi

    pwfile=$(mktemp /tmp/tdh-mysqlpw.XXXXXXXX)
    echo $pass > $pwfile

    return 0
}


while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -d|--disksize)
            disksize="$2"
            shift
            ;;
        -p|--prefix)
            prefix="$2"
            shift
            ;;
        -P|--pwfile)
            pwfile="$2"
            shift
            ;;
        -n|--dryrun)
            dryrun=1
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
        -y|--no-prompt)
            noprompt=1
            ;;
        *)
            action="$1"
            shift
            namelist="$@"
            shift $#
            ;;
    esac
    shift
done

if [ -z "$action" ]; then
    usage
    exit 1
fi

if [ "$action" == "run" ]; then
    dryrun=0
else 
    echo "  <DRYRUN> enabled"
fi

if [ -n "$namelist" ]; then
    names="$namelist"
else
    echo "Using default 3 masters"
fi

if [ -z "$pwfile" ]; then
    if [ $noprompt -gt 0 ]; then
        echo "Error! Password File not specified with --noprompt"
        exit 1
    fi
    read_password
fi

echo "Creating masters for '$names'"
echo ""

for name in $names; do
    host="${prefix}-${name}"
   
    echo "( $tdh_path/bin/tdh-gcp-compute.sh --prefix ${prefix} --type $mtype --attach --disksize $disksize create ${name} )"
    if [ $dryrun -eq 0 ]; then
        ( $tdh_path/bin/tdh-gcp-compute.sh --prefix ${prefix} --type $mtype --attach --disksize $disksize create ${name} )
    fi

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in GCP initialization of $host" 
        break
    fi

    #
    # Device format and mount
    device="/dev/sdb"
    mountpoint="/data"

    echo "( gcloud compute ssh ${host} --command './tdh-gcp-format.sh $device $mountpoint' )"
    if [ $dryrun -eq 0 ]; then
        ( gcloud compute scp ${tdh_path}/bin/tdh-gcp-format.sh ${host}: )
        ( gcloud compute ssh ${host} --command 'chmod +x tdh-gcp-format.sh' )
        ( gcloud compute ssh ${host} --command "./tdh-gcp-format.sh $device $mountpoint" )
    fi

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in tdh-gcp-format for $host"
        break
    fi

    # disable  iptables and cups
    echo "( gcloud compute ssh $host --command 'sudo systemctl stop firewalld; sudo systemctl disable firewalld; sudo service cups stop; sudo chkconfig cups off' )"
    if [ $dryrun -eq 0 ]; then
        ( gcloud compute ssh $host --command "sudo systemctl stop firewalld; sudo systemctl disable firewalld; sudo service cups stop; sudo chkconfig cups off" )
    fi

    #
    # prereq's
    echo "( gcloud compute ssh ${host} --command ./tdh-prereqs.sh )"
    if [ $dryrun -eq 0 ]; then
        ( gcloud compute scp ${tdh_path}/bin/tdh-prereqs.sh ${host}: )
        ( gcloud compute ssh ${host} --command 'chmod +x tdh-prereqs.sh' )
        ( gcloud compute ssh ${host} --command ./tdh-prereqs.sh )
    fi

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in tdh-prereqs for $host"
        break
    fi

    #
    # mysqld
    echo "( gcloud compute ssh ${host} --command './tdh-mysql-install.sh -P {$pwfile}' )"
    if [ $dryrun -eq 0 ]; then
        ( gcloud compute scp ${tdh_path}/bin/tdh-mysql-install.sh ${host}: )
        ( gcloud compute ssh ${host} --command 'chmod +x ./tdh-mysql-install.sh' )
        ( gcloud compute ssh ${host} --command "./tdh-mysql-install.sh -P ${pwfile}" )
    fi

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in tdh-mysql-install for $host"
        break
    fi

    echo "Initialization complete for $host"
    echo ""
done

if [ -e "$pwfile" ]; then
    unlink $pwfile
fi

echo "$PNAME finished"
exit $rt