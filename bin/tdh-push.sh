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
ident=
usegcp=0
nocopy=0

# -----------------------------------

usage()
{
    echo ""
    echo "$TDH_PNAME [options] [path] <archive_name> <host>"
    echo "  -G|--use-gcp     : Use the GCloud API to scp the archive."
    echo "  -h|--help        : Show usage info and exit."
    echo "  -i  <identity>   : SSH identity (PEM) file."
    echo "  -u|--user        : Username for scp action if not '$USER'."
    echo "  -z|--zone <zone> : GCP Zone if not default (used with -G)."
    echo "  -V|--version     : Show version info and exit."
    echo ""
    echo "  path             : is the directory to be archived (required)."
    echo "  archive_name     : an alternate name for the tarball. The value "
    echo "                     of 'mypkg' will result in 'mypkg.tar.gz'"
    echo "                     By default, the target directory name is used."
    echo "  host             : Name of target host. Override with TDH_PUSH_HOST"
    echo ""
    echo " The script intends that the archive will contain only the last"
    echo "directory target. A path of a '/a/b/c' will create the archive "
    echo "from 'b' with containing './c/' as the root directory."
    echo ""
    echo " The environment variable 'TDH_PUSH_HOST' is honored as the "
    echo "default target to use. Otherwise, all three parameters are required. "
    echo ""
    echo " The script uses a 'tmp' path for both creating the archive locally"
    echo "and landing on the target host.  This is defined by the environment "
    echo "variable 'TDH_DIST_PATH'. The default is '/tmp/dist'. "
    echo "The target path will be auto-created on the remote host."
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
        -i|--identity)
            ident="$2"
            shift
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
    if [ -n "$ident" ]; then
        ( ssh-add $ident )
    fi
    ssh="$ssh ${user}@${host}"
fi

apath=$(realpath "$apath")
target=$(dirname "$apath")
name=${apath##*\/}

if [ -z "$aname" ]; then
    aname="$name"
fi

if ! [ -e "$DISTPATH" ]; then
    ( mkdir -p $DISTPATH )
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

echo "$scp ${DISTPATH}/${aname}.tar.gz ${user}@${host}:${DISTPATH}"

if [ $nocopy -eq 0 ]; then
    ( $ssh "mkdir -p ${DISTPATH}" )
    ( $scp ${DISTPATH}/${aname}.tar.gz ${user}@${host}:${DISTPATH}/ )

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in scp attempt."
    fi

    ( rm ${DISTPATH}/${aname}.tar.gz )
fi

echo "$TDH_PNAME Finished."
exit $rt
