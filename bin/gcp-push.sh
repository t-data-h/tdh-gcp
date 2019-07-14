#!/bin/bash
#
#
PNAME=${0##*\/}
DISTPATH="${HOME}/tmp/dist"

APATH=$( realpath $1 )
ANAME="$2"
GCPHOST="$3"


usage()
{
    echo ""
    echo "$PNAME [path] <archive_name> <gcphost>"
    echo ""
    echo "  Where 'path' is the directory to be archived."
    echo ""
    echo "   The script assumes that the archive will contain the final"
    echo " directory, so a path of a '/a/b/c' will create the archive from 'b'"
    echo " with the tarfile containing './c/' as the root directory"
    echo ""
    echo "   Archive name is an altername name to call the tarball. The"
    echo " value 'somepkg' will result in an archive of somepkg.tar.gz"
    echo " By default, the archive will be named after the final directory."
    echo ""
    echo "  The environment variable 'GCH_PUSH_HOST' is honored as the "
    echo " the default 'gcphost' to use. If not set, all three parameters"
    echo " are required."
    echo ""
}


if [ -n "$GCP_DIST_PATH" ]; then
    DISTPATH="$GCP_DIST_PATH"
fi

if [ -z "$GCPHOST" ]; then
    GCPHOST="$GCP_PUSH_HOST"
fi

if [ -z "$GCPHOST" ]; then
    echo "Error! GCP_PUSH_HOST not defined or provided."
    usage
    exit 1
fi

if [ -z "$APATH" ]; then
    echo "Invalid Path."
    usage
    exit 1
fi

target=$(dirname "$(readlink -f "$APATH")")
name=${APATH##*\/}

if [ -z "$ANAME" ]; then
    ANAME="$name"
fi

cd $target

( tar -cvf ${DISTPATH}/${ANAME}.tar ./${name} )
( gzip ${DISTPATH}/${ANAME}.tar )
( gcloud compute ssh ${GCPHOST} --command "mkdir -p /tmp/dist" )
( gcloud compute scp ${DISTPATH}/${ANAME}.tar.gz ${GCPHOST}:/tmp/dist/ )

rt=$?
if [ $rt -gt 0 ]; then
    echo "Error in gcp"
fi

( rm ${DISTPATH}/${ANAME}.tar.gz )

echo "$PNAME Finished."
exit $rt
