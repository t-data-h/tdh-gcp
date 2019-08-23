#!/bin/bash
#
#  Creates an archive of a given path and pushes to remote GCP host.
#
PNAME=${0##*\/}
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../etc/tdh-gcp-config.sh ]; then
    . ${tdh_path}/../etc/tdh-gcp-config.sh
fi

# -----------------------------------

DISTPATH="${HOME}/tmp/dist"

if [ -n "$GCP_DIST_PATH" ]; then
    DISTPATH="$GCP_DIST_PATH"
fi

apath=
aname=
gcphost=
rt=0

# -----------------------------------

usage()
{
    echo ""
    echo "$PNAME [path] <archive_name> <gcphost>"
    echo ""
    echo "  path         : is the directory to be archived (required)."
    echo "  archive_name : an altername name to call the tarball. The value"
    echo "                 of 'somepkg' will result in 'somepkg.tar.gz'"
    echo "                 By default, the the final directory name is used."
    echo "  gcphost      : Name of gcp host. To override GCP_PUSH_HOST"
    echo ""
    echo "   The script assumes that the archive will contain the final"
    echo " directory, so a path of a '/a/b/target' will create the archive from "
    echo " 'b' with the tarfile containing './target/' as the root directory"
    echo ""
    echo "  The environment variable 'GCP_PUSH_HOST' is honored as the "
    echo " the default 'gcphost' to use. If not set, all three parameters"
    echo " are required."
    echo "  The script uses a common tmp path for both creating the archive "
    echo " locally, and for the target host path.  This uses the value of "
    echo " 'GCP_DIST_PATH' if set,or the default'~/tmp/dist' if not set."
    echo " Essentially, the path should exist locally as well as remotely."
    echo ""
}

version()
{
    echo "$PNAME: v$TDH_GCP_VERSION"
}


# MAIN
#

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit $rt
            ;;
        -V|--version)
            version
            exit $rt
            ;;
        *)
            apath="$1"
            aname="$2"
            gcphost="$3"
            shift $#
            ;;
    esac
    shift
done

if [ -z "$gcphost" ]; then
    gcphost="$GCP_PUSH_HOST"
fi

if [ -z "$gcphost" ]; then
    echo "Error! GCP_PUSH_HOST not defined or provided."
    usage
    exit 1
fi

if [ -z "$apath" ]; then
    echo "Invalid path given."
    usage
    exit 1
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
( gcloud compute ssh ${gcphost} --command "mkdir -p ${DISTPATH}" )

echo "scp ${DISTPATH}/${aname}.tar.gz ${gcphost}:${DISTPATH}"
( gcloud compute scp ${DISTPATH}/${aname}.tar.gz ${gcphost}:${DISTPATH} )

rt=$?
if [ $rt -gt 0 ]; then
    echo "Error in gcp"
fi

( rm ${DISTPATH}/${aname}.tar.gz )

echo "$PNAME Finished."

exit $rt
