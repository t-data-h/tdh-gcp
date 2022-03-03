#!/usr/bin/env bash
#
#  Creates an archive of a given path and pushes to a remote host.
#
#  @author Timothy C. Arland <tcarland@gmail.com>
#
PNAME=${0##*\/}

# -----------------------------------

DISTPATH="${TDH_DIST_PATH:-/tmp/dist}"
GSSH="gcloud compute ssh"
GSCP="gcloud compute scp"

zone=
arpath=
arname=
host="$TDH_PUSH_HOST"
user="$USER"
ident=
usegcp=0
nocopy=0
zip="gzip"

# -----------------------------------

usage="
A tool intended to automate pushing a project or directory 
of assets to a remote host. It creates a gzipped archive or 
tarball of a given path and pushes the archive to a remote 
host. The script also ensures the target path is maintained 
as the root directory of the archive rather than extracting 
assets to './'.

Synopsis:
  $PNAME [options] [path] <archive_name> <host>

Options:
  -G|--use-gcp     : Use the GCloud API to scp the archive.
  -h|--help        : Show usage info and exit.
  -i  <identity>   : SSH identity (PEM) file.
  -j|--bzip2       : Use bzip2 instead of default gzip.
  -u|--user        : Username for scp action if not '$USER'.
  -z|--zone <zone> : GCP Zone, if not 'default' (used with -G).
 
  path             : The directory to be archived (required).
  archive_name     : An alternate name for the tarball. The value 
                     of 'mypkg' will result in 'mypkg.tar.gz'
                     By default, the target directory name is used.
  host             : Name of target host, or set TDH_PUSH_HOST
 
 The script ensures that the archive will contain only the last
 directory target. A path given as '/a/b/c' will create the archive 
 from 'b' resulting in './c' being the root of the archive.
 
 The 'TDH_PUSH_HOST' environment variable is honored as the default
 target host to use. Otherwise, all three parameters are required. 
 
 The script uses a 'tmp' path for both creating the archive locally
 and landing on the target host. This is defined by the environment 
 variable 'TDH_DIST_PATH'. The default is '/tmp/dist/'. This target 
 path will be auto-created on the remote host.
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
        -j|--bzip2)
            zip="bzip2"
            ;;
        -u|--user)
            user="$2"
            shift
            ;;
        -z|--zone)
            zone="$2"
            shift
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
    echo "$PNAME ERROR, TDH_PUSH_HOST not defined or provided." >&2
    echo "$usage"
    exit 1
fi

if [ -z "$apath" ]; then
    echo "$PNAME ERROR, Invalid path given." >&2 
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
    echo "$PNAME ERROR in determining target directory from '$apath'" >&2
    exit 2
fi

if [ -z "$aname" ]; then
    aname="$name"
fi

if [[ ! -e $DISTPATH ]]; then
    ( mkdir -p $DISTPATH )
    if [ $? -ne 0 ]; then
        echo "$PNAME ERROR: Unable to create '${DISTPATH}'" >&2
        exit 1
    fi
fi

cd $target
if [ $? -ne 0  ]; then
    echo "$PNAME ERROR in cd to '$target'" >&2
    exit 1
fi

echo " ( tar -cf ${DISTPATH}/${aname}.tar --exclude-vcs ./${name} )"
( tar -cf ${DISTPATH}/${aname}.tar --exclude-vcs ./${name} 2>/dev/null )

rt=$?
if [ $rt -gt 0 ]; then
    echo "$PNAME ERROR creating archive" >&2
    if [ -e ${DISTPATH}/${aname}.tar ]; then
        unlink ${DISTPATH}/${aname}.tar
    fi
    exit 1
fi

( $zip ${DISTPATH}/${aname}.tar )

echo "$scp ${DISTPATH}/${aname}.tar.* ${user}@${host}:${DISTPATH}"

if [ $nocopy -eq 0 ]; then
    ( $ssh "mkdir -p ${DISTPATH}" )
    ( $scp ${DISTPATH}/${aname}.tar.* ${user}@${host}:${DISTPATH}/ )

    rt=$?
    if [ $rt -gt 0 ]; then
        echo $PNAME "ERROR in scp attempt." >&2
    fi

    ( rm ${DISTPATH}/${aname}.tar.* )
fi

echo " -> $PNAME Finished."
exit $rt
