#!/bin/bash
#
#  Creates an archive of a given path and pushes to a remote host.
#
#  @author Timothy C. Arland <tcarland@gmail.com>
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/tdh-gcp-config.sh ]; then
    . ${tdh_path}/tdh-gcp-config.sh
fi

# -----------------------------------

DISTPATH="/tmp/dist"

if [ -n "$TDH_DIST_PATH" ]; then
    DISTPATH="$TDH_DIST_PATH"
fi

zone=
apath=
aname=
host=
user="$USER"
usegcp=0
nocopy=0

# -----------------------------------

usage()
{
    echo ""
    echo "$TDH_PNAME [options] [path] <archive_name> <gcphost>"
    echo "  -G|--use-gcp     : Use GCloud API to gcloud scp the archive."
    echo "  -h|--help        : Show usage info and exit."
    echo "  -u|--user        : Username for scp action if not '$USER'."
    echo "  -z|--zone <zone> : GCP Zone if not default."
    echo "  -V|--version     : Show version info and exit."
    echo ""
    echo "  path             : is the directory to be archived (required)."
    echo "  archive_name     : an altername name to call the tarball. The "
    echo "                     value of 'pkg' will result in 'pkg.tar.gz'"
    echo "                     By default, the final directory name is used."
    echo "  host             : Name of target. To override set TDH_PUSH_HOST"
    echo ""
    echo "   The script assumes that the archive will contain the final"
    echo " directory target, so a path of a '/a/b/target' will create the "
    echo " archive from 'b' with the tarfile containing './target/' as the "
    echo " root directory."
    echo ""
    echo "   The environment variable 'TDH_PUSH_HOST' is honored as the "
    echo " default 'gcphost' to use. If not set, all three parameters are"
    echo " required."
    echo ""
    echo "   The script uses a common tmp path for both creating the archive "
    echo " locally, and for the target host path.  This is defined by the "
    echo " variable 'TDH_DIST_PATH'. The default is '/tmp/dist' if not set."
    echo ""
}


# MAIN
#
rt=0
ssh="ssh"
scp="scp"


while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit $rt
            ;;
        -G|--use-gcp)
            usegcp=1
            ;;
        -u|--user)
            user="$2"
            shift
            ;;
        -z|--zone)
            zone="$2"
            shift
            ;;
        -V|--version)
            tdh_version
            exit $rt
            ;;
        -x|--no-copy)
            nocopy=1
            ;;
        *)
            apath="$1"
            aname="$2"
            host="$3"
            shift $#
            ;;
    esac
    shift
done

if [ -z "$host" ]; then
    host="$TDH_PUSH_HOST"
fi

if [ -z "$host" ]; then
    echo "Error! TDH_PUSH_HOST not defined or provided."
    usage
    exit 1
fi

if [ -z "$apath" ]; then
    echo "Invalid path given."
    usage
    exit 1
fi

if [ $usegcp -gt 0 ]; then
    ssh="$GSSH"
    scp="$GSCP"
    if [ -n "$zone" ]; then
        ssh="$ssh --zone $zone"
        scp="$scp --zone $zone"
    fi
    ssh="$ssh ${user}@${host} --command"
else
    ssh="$ssh ${user}@${host}"
fi

apath=$(readlink -f "$apath")
target=$(dirname "$apath")
name=${apath##*\/}

if [ -z "$aname" ]; then
    aname="$name"
fi

cd $target

echo " ( tar -cf ${DISTPATH}/${aname}.tar --exclude-vcs ./${name} )"
( tar -cf ${DISTPATH}/${aname}.tar --exclude-vcs ./${name} )

rt=$?
if [ $rt -gt 0 ]; then
    echo "Error creating archive"
    exit 1
fi

( gzip ${DISTPATH}/${aname}.tar )

echo "scp ${DISTPATH}/${aname}.tar.gz ${host}:${DISTPATH}"

if [ $nocopy -eq 0 ]; then
    ( $ssh "mkdir -p ${DISTPATH}" )
    ( $scp ${DISTPATH}/${aname}.tar.gz ${user}@${host}:${DISTPATH} )

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in gcp"
    fi

    ( rm ${DISTPATH}/${aname}.tar.gz )
fi

echo "$TDH_PNAME Finished."
exit $rt
