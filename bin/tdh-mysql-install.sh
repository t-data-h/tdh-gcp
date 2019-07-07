#!/bin/bash
#
#  Bootstrap mysqld for a GCP Instance
#
PNAME=${0##*\/}
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/tdh-gcp-config.sh ]; then
    . ${tdh_path}/tdh-gcp-config.sh
fi

# -----------------------------------

host=
role=
pw=
rt=
id=1

# -----------------------------------

usage()
{
    echo ""
    echo "Usage: $PNAME [options]  <host> <ROLE>"
    echo "  -h|--help             : Display help and exit"
    echo "  -p|--password <pw>    : The root mysql password"
    echo "  -P|--pwfile <file>    : File containing root mysql password"
    echo "  -s|--server-id <n>    : Server ID to use for mysql instance"
    echo "  -V|--version          : Show version info and exit"
    echo "  -V|--version          : Show version info"
    echo " Where ROLE is 'master', 'slave', or 'client'"
    echo ""
}

version()
{
    echo "$PNAME: v$VERSION"
}


while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -p|--password)
            pw="$2"
            shift
            ;;
        -P|--pwfile)
            pwfile="$2"
            if [ -r $pwfile ]; then
                pw=$(cat $2)
            fi
            shift
            ;;
        -s|--server-id)
            id=$2
            shift
            ;;
        -V|--version)
            version
            exit 0
        *)
            host="$1"
            role="$2"
            shift $#
            ;;
    esac
    shift
done


if [ -z "$host" ] || [ -z "$role" ]; then
    version
    usage
    exit 1
fi

if [ -z "$pw" ]; then
    echo "Error, password was not provided."
    usage
    exit 1
fi

# copy repo, repo key, and server config
( gcloud compute scp ${tdh_path}/../etc/mysql-community.repo ${host}: )
( gcloud compute scp ${tdh_path}/../etc/RPM-GPG-KEY-mysql ${host}: )
( gcloud compute scp ${tdh_path}/../etc/tdh-mysql.cnf ${host}:my.cnf )


if [ "$role" == "slave" ]; then
    if [ $id -eq 1 ]; then
        id=2
    fi
    ( gcloud compute ssh $host --command 'mv my.cnf my-1.cnf' )
    ( gcloud compute ssh $host --command "sed -E 's/^(server-id[[:blank:]]*=[[:blank:]]*).*/\1$id/' my-1.cnf > my.cnf" )
    ( gcloud compute ssh $host --command "rm my-1.cnf" )
    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in sed for slave my.cnf"
    fi
fi


# Install Client
( gcloud compute ssh $host --command 'sudo cp mysql-community.repo /etc/yum.repos.d' )
( gcloud compute ssh $host --command 'sudo cp RPM-GPG-KEY-mysql /etc/pki/rpm-gpg/')
( gcloud compute ssh $host --command 'sudo yum install -y mysql-community-libs mysql-community-client mysql-connector-java' )


# Install Server
if [ "$role" == "master" ] || [ "$role" == "slave" ]; then
    ( gcloud compute ssh $host --command 'sudo yum install -y mysql-community-server' )
    ( gcloud compute ssh $host --command 'sudo cp my.cnf /etc/my.cnf && sudo chmod 644 /etc/my.cnf' )
    ( gcloud compute ssh $host --command 'sudo mysqld --initialize-insecure --user=mysql' )
    ( gcloud compute ssh $host --command 'sudo service mysqld start' )

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error starting mysql daemon"
        exit $rt
    fi

    ( gcloud compute ssh $host --command "printf \"[mysql]\nuser=root\npassword=$pw\n\" > .my.cnf"  )
    ( gcloud compute ssh $host --command "mysql -u root --skip-password -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '$pw'\"" )

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in mysql ALTER USER"
    fi
fi

echo "$PNAME finished."

exit $rt
