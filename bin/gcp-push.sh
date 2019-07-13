#!/bin/bash
#
#
DISTPATH="${HOME}/tmp/dist"


usage()
{
    echo ""
    echo "$0  [path] [archive_name] <gcphost>"
    echo ""
}

if [ -n "$GCP_DIST_PATH" ]; then
    DISTPATH="$GCP_DIST_PATH"
fi

APATH=$( realpath $1 )
ANAME="$2"
GCPHOST="$3"

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
( gcloud compute scp ${DISTPATH}/${ANAME}.tar.gz ${GCPHOST}:/tmp/dist/ )

rt=$?
if [ $rt -gt 0 ]; then
    echo "Error in gcp"
fi

( rm ${DISTPATH}/${ANAME}.tar.gz )

exit $rt
