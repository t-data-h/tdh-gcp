#!/bin/bash
#
#  Creates an archive of a given path and pushes to a remote host.
#
#  @author Timothy C. Arland <tcarland@gmail.com>
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../bin/tdh-gcp-env.sh ]; then
    . ${tdh_path}/../bin/tdh-gcp-env.sh
fi

# -----------------------------------

DISTPATH="${TDH_DIST_PATH:-/tmp/dist}"

zone=
arpath=
arname=
host="$TDH_PUSH_HOST"
user="$USER"
ident=
usegcp=0
nocopy=0

# -----------------------------------

usage="
Creates an archive (tarball) of a given path and pushes to a remote host.

Synopsis:
  $TDH_PNAME [options] [path] <archive_name> <host>

Options:
  -G|--use-gcp     : Use the GCloud API to scp the archive.
  -h|--help        : Show usage info and exit.
  -i  <identity>   : SSH identity (PEM) file.
  -u|--user        : Username for scp action if not '$USER'.
  -z|--zone <zone> : GCP Zone, if not 'default' (used with -G).
  -V|--version     : Show version info and exit.
 
  path             : is the directory to be archived (required).
  archive_name     : An alternate name for the tarball. The value 
                     of 'mypkg' will result in 'mypkg.tar.gz'
                     By default, the target directory name is used.
  host             : Name of target host, or set TDH_PUSH_HOST
 
 The script intends that the archive will contain only the last
 directory target. A path of a '/a/b/c' will create the archive 
 from 'b' with containing './c/' as the root directory.
 
 The 'TDH_PUSH_HOST' environment variable is honored as the default
 target host to use. Otherwise, all three parameters are required. 
 
 The script uses a 'tmp' path for both creating the archive locally
 and landing on the target host.  This is defined by the environment 
 variable 'TDH_DIST_PATH'. The default is '/tmp/dist'. 
 The target path will be auto-created on the remote host.
"

# -----------------------------------

# MAIN
#
rt=0
ssh="ssh"
scp="scp"


while [ $# -gt 0 ]; do
    case "$1" in
        'help'|-h|--help)
            echo "$usage"
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
        'version'|-V|--version)
            tdh_version
            exit $rt
            ;;
        -x|--no-copy)
            nocopy=1
            ;;
        *)
            apath="$1"
            aname="$2"
            host="${3:-$TDH_PUSH_HOST}"
            shift $#
            ;;
    esac
    shift
done

if [ -z "$host" ]; then
    echo "$TDH_PNAME ERROR, TDH_PUSH_HOST not defined or provided." >&2
    echo "$usage"
    exit 1
fi

if [ -z "$apath" ]; then
    echo "$TDH_PNAME ERROR, Invalid path given." >&2 
    echo "$usage"
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

if [ -z "$target" ]; then
    echo "$TDH_PNAME ERROR in determining target directory from '$apath'" >&2
    exit 2
fi

if [ -z "$aname" ]; then
    aname="$name"
fi

if ! [ -e "$DISTPATH" ]; then
    ( mkdir -p $DISTPATH )
fi

cd $target
if [ $? -ne 0  ]; then
    echo "$TDH_PNAME ERROR in cd to '$target'" >&2
    exit 1
fi

echo " ( tar -cf ${DISTPATH}/${aname}.tar --exclude-vcs ./${name} )"
( tar -cf ${DISTPATH}/${aname}.tar --exclude-vcs ./${name} )

rt=$?
if [ $rt -gt 0 ]; then
    echo "$TDH_PNAME ERROR creating archive" >&2
    exit 1
fi

( gzip ${DISTPATH}/${aname}.tar )

echo "$scp ${DISTPATH}/${aname}.tar.gz ${user}@${host}:${DISTPATH}"

if [ $nocopy -eq 0 ]; then
    ( $ssh "mkdir -p ${DISTPATH}" )
    ( $scp ${DISTPATH}/${aname}.tar.gz ${user}@${host}:${DISTPATH}/ )

    rt=$?
    if [ $rt -gt 0 ]; then
        echo $TDH_PNAME "ERROR in scp attempt." >&2
    fi

    ( rm ${DISTPATH}/${aname}.tar.gz )
fi

echo " -> $TDH_PNAME Finished."
exit $rt
