#!/bin/bash
#
#
PNAME=${0##*\/}
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/tdh-gcp-config.sh ]; then
    . ${tdh_path}/tdh-gcp-config.sh
fi

# -----------------------------------

DISTPATH="${HOME}/tmp/dist"
if [ -n "$GCP_DIST_PATH" ]; then
    DISTPATH="$GCP_DIST_PATH"
fi

# -----------------------------------

usage()
{
    echo ""
    echo "$PNAME [path] <archive_name> <gcphost>"
    echo ""
    echo "  path         : is the directory to be archived."
    echo "  archive_name : an altername name to call the tarball. The value"
    echo "                 of 'somepkg' will result in 'somepkg.tar.gz'"
    echo "                 By default, the the final directory name is used."
    echo "  gcphost      : Name of gcp host. To override GCP_PUSH_HOST"
    echo ""
    echo "   The script assumes that the archive will contain the final"
    echo " directory, so a path of a '/a/b/c' will create the archive from 'b'"
    echo " with the tarfile containing './c/' as the root directory"
    echo ""
    echo "  The environment variable 'GCP_PUSH_HOST' is honored as the "
    echo " the default 'gcphost' to use. If not set, all three parameters"
    echo " are required."
    echo ""
}

version()
{
    echo "$PNAME: v$TDH_GCP_VERSION"
}


# MAIN
#
apath=
aname=
gcphost=
rt=0

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
            apath=
            aname="$2"
            gcphost="$3"
            shift $#
            ;;
    esac
    shift
done

if [ -z "$apath" ]; then
    usage
    exit 1
fi

if [ -z "$gcphost" ]; then
    gcphost="$GCP_PUSH_HOST"
fi

if [ -z "$gcphost" ]; then
    echo "Error! GCP_PUSH_HOST not defined or provided."
    usage
    exit 1
fi

if [ -z "$apath" ]; then
    echo "Invalid Path."
    usage
    exit 1
fi

target=$(dirname "$(readlink -f "$apath")")
name=${apath##*\/}

if [ -z "$aname" ]; then
    aname="$name"
fi

cd $target

( tar -cvf ${DISTPATH}/${aname}.tar ./${name} )
( gzip ${DISTPATH}/${aname}.tar )
( gcloud compute ssh ${gcphost} --command "mkdir -p /tmp/dist" )
( gcloud compute scp ${DISTPATH}/${aname}.tar.gz ${gcphost}:/tmp/dist/ )

rt=$?
if [ $rt -gt 0 ]; then
    echo "Error in gcp"
fi

( rm ${DISTPATH}/${aname}.tar.gz )

echo "$PNAME Finished."

exit $rt
