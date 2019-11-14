#!/bin/bash
#
#  Creates an archive of a given path and pushes to remote GCP host.
#
#  @author Timothy C. Arland <tcarland@gmail.com>
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/tdh-gcp-config.sh ]; then
    . ${tdh_path}/tdh-gcp-config.sh
fi

# -----------------------------------

DISTPATH="${HOME}/tmp/dist"

if [ -n "$GCP_DIST_PATH" ]; then
    DISTPATH="$GCP_DIST_PATH"
fi

zone=
apath=
aname=
host=
nocopy=0

# -----------------------------------

usage()
{
    echo ""
    echo "$TDH_PNAME [options] [path] <archive_name> <gcphost>"
    echo ""
    echo "  path         : is the directory to be archived (required)."
    echo "  archive_name : an altername name to call the tarball. The value"
    echo "                 of 'somepkg' will result in 'somepkg.tar.gz'"
    echo "                 By default, the the final directory name is used."
    echo "  host         : Name of target host. To override GCP_PUSH_HOST"
    echo ""
    echo "   The script assumes that the archive will contain the final"
    echo " directory target, so a path of a '/a/b/target' will create the "
    echo " archive from 'b' with the tarfile containing './target/' as the "
    echo " root directory."
    echo ""
    echo "   The environment variable 'GCP_PUSH_HOST' is honored as the "
    echo " default 'gcphost' to use. If not set, all three parameters are"
    echo " required."
    echo ""
    echo "   The script uses a common tmp path for both creating the archive "
    echo " locally, and for the target host path.  This is defined by the "
    echo " variable 'GCP_DIST_PATH'. The default is '~/tmp/dist' if not set."
    echo ""
}


# MAIN
#
rt=0


while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit $rt
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
    host="$GCP_PUSH_HOST"
fi

if [ -z "$host" ]; then
    echo "Error! GCP_PUSH_HOST not defined or provided."
    usage
    exit 1
fi

if [ -z "$apath" ]; then
    echo "Invalid path given."
    usage
    exit 1
fi

if [ -n "$zone" ]; then
    GSSH="$GSSH --zone $zone"
    GSCP="$GSCP --zone $zone"
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

echo "scp ${DISTPATH}/${aname}.tar.gz ${gcphost}:${DISTPATH}"
if [ $nocopy -eq 0 ]; then
    ( $GSSH ${gcphost} --command "mkdir -p ${DISTPATH}" )
    ( $GSCP ${DISTPATH}/${aname}.tar.gz ${gcphost}:${DISTPATH} )

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in gcp"
    fi

    ( rm ${DISTPATH}/${aname}.tar.gz )
fi

echo "$TDH_PNAME Finished."
exit $rt
