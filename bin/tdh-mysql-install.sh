#!/bin/bash
#
#  Bootstrap mysqld for a GCP Instance
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/tdh-gcp-config.sh ]; then
    . ${tdh_path}/tdh-gcp-config.sh
fi

# -----------------------------------

host=
role="master"
zone=
pw=
rt=
id=1

# -----------------------------------

usage()
{
    echo ""
    echo "Usage: $PNAME [options]  [host] [ROLE]"
    echo "  -h|--help             : Display help and exit"
    echo "  -p|--password <pw>    : The root mysql password"
    echo "  -P|--pwfile <file>    : File containing root mysql password"
    echo "  -s|--server-id <n>    : Server ID to use for mysql instance"
    echo "  -z|--zone <zoneid>    : GCP Zone of target host"
    echo "  -V|--version          : Show version info and exit"
    echo " Where ROLE is 'master', 'slave', or 'client'"
    echo ""
}

# Main
#

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
        -z|--zone)
            zone="$2"
            shift
            ;;
        -V|--version)
            tdh_version
            exit 0
            ;;
        *)
            host="$1"
            role="$2"
            shift $#
            ;;
    esac
    shift
done


if [ -z "$host" ]; then
    tdh_version
    usage
    exit 1
fi

if [ -z "$pw" ] && [ "$role" != "client" ]; then
    echo "Error, password was not provided."
    usage
    exit 1
fi

if [ -n "$zone" ]; then
    GSSH="$GSSH --zone $zone"
    GSCP="$GSCP --zone $zone"
fi

# copy repo, repo key, and server config
( $GSCP ${tdh_path}/../etc/mysql-community.repo ${host}: )
( $GSCP ${tdh_path}/../etc/RPM-GPG-KEY-mysql ${host}: )

# Install Client
( $GSSH $host --command 'sudo cp mysql-community.repo /etc/yum.repos.d' )
( $GSSH $host --command 'sudo cp RPM-GPG-KEY-mysql /etc/pki/rpm-gpg/')
( $GSSH $host --command 'sudo yum install -y mysql-community-libs mysql-community-client' )

# Install specific 5.1.46 JDBC Driver
( $GSSH $host --command 'wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.46.tar.gz' )
( $GSSH $host --command 'tar zxf mysql-connector-java-5.1.46.tar.gz; \
sudo mkdir -p /usr/share/java; \
sudo cp mysql-connector-java-5.1.46/mysql-connector-java-5.1.46-bin.jar /usr/share/java/; \
sudo chmod 644 /usr/share/java/mysql-connector-java-5.1.46-bin.jar; \
sudo ln -s /usr/share/java/mysql-connector-java-5.1.46-bin.jar /usr/share/java/mysql-connector-java.jar; \
rm -rf mysql-connector-java-5.1.46 mysql-connector-java-5.1.46.tar.gz')


if [ "$role" == "client" ]; then 
    echo "$PNAME client finished."
    exit 0
fi


( $GSCP ${tdh_path}/../etc/tdh-mysql.cnf ${host}:my.cnf )

if [ "$role" == "slave" ]; then
    if [ $id -eq 1 ]; then
        id=2
    fi
    ( $GSSH $host --command 'mv my.cnf my-1.cnf' )
    ( $GSSH $host --command "sed -E 's/^(server-id[[:blank:]]*=[[:blank:]]*).*/\1$id/' my-1.cnf > my.cnf" )
    ( $GSSH $host --command "rm my-1.cnf" )
    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in sed for slave my.cnf"
    fi
fi


# Install Server
if [ "$role" == "master" ] || [ "$role" == "slave" ]; then
    ( $GSSH $host --command 'sudo yum install -y mysql-community-server' )
    ( $GSSH $host --command 'sudo cp my.cnf /etc/my.cnf && sudo chmod 644 /etc/my.cnf' )
    ( $GSSH $host --command 'sudo mysqld --initialize-insecure --user=mysql' )
    ( $GSSH $host --command 'sudo systemctl start mysqld' )
    ( $GSSH $host --command 'sudo systemctl enable mysqld' )

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error starting mysql daemon"
        exit $rt
    fi

    ( $GSSH $host --command "printf \"[mysql]\nuser=root\npassword=$pw\n\" > .my.cnf"  )
    ( $GSSH $host --command "mysql -u root --skip-password -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '$pw'\"" )

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in mysql ALTER USER"
    fi
fi

echo "$TDH_PNAME finished."
exit $rt
