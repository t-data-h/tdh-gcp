#!/bin/bash
#
#  Bootstrap mysqld for a host by installing mysql-server
#  and setting the configuration and root password.
#
#  @author Timothy C. Arland <tcarland@gmail.com>
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../bin/tdh-gcp-config.sh ]; then
    . ${tdh_path}/../bin/tdh-gcp-config.sh
fi

# -----------------------------------

hosts=
role=
zone=
ident=
pw=
pwfile=
rt=
id=1
usegcp=0
user="$USER"

# -----------------------------------

usage="
Bootstraps MySQL for a host as either server or client.

Synopsis: 
  $TDH_PNAME [options] [ROLE] [host] {host2 host3 ..}

Options:
   -h|--help             : Display help and exit
   -G|--use-gcp          : Run commands using the GCP API.
   -i|--identity <file>  : SSH Identity file.
   -p|--password <pw>    : The root mysql password.
   -P|--pwfile <file>    : File containing root mysql password.
   -s|--server-id <n>    : Server ID to use for mysql instance.
   -u|--user <name>      : SSH Username to use for target host.
   -z|--zone <zoneid>    : GCP Zone of target host, if needed.
   -V|--version          : Show version info and exit.
 
  Where ROLE is 'master', 'slave', or 'client'
  Hosts as a list is only supported for the client role.
"

# -----------------------------------

read_password()
{
    local prompt="Password: "
    local pass=
    local pval=

    read -s -p "$prompt" pass
    echo ""
    read -s -p "Repeat $prompt" pval
    echo ""

    if [[ "$pass" != "$pval" ]]; then
        return 1
    fi

    pwfile=$(mktemp /tmp/tdh-mysqlpw.XXXXXXXX)
    echo $pass > $pwfile

    return 0
}

# Main
#
while [ $# -gt 0 ]; do
    case "$1" in
        'help'|-h|--help)
            echo "$usage"
            exit 0
            ;;
        -G|--use-gcp)
            usegcp=1
            ;;
        -i|--identity)
            ident="$2"
            shift
            ;;
        -p|--password)
            pw="$2"
            shift
            ;;
        -P|--pwfile)
            pwfile="$2"
            if [ -r $pwfile ]; then
                pw=$(cat $2 2>/dev/null)
            fi
            shift
            ;;
        -s|--server-id)
            id=$2
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
            exit 0
            ;;
        *)
            role="$1"
            shift
            hosts="$@"
            shift $#
            ;;
    esac
    shift
done


if [ -z "$hosts" ] || [ -z "$role" ]; then
    tdh_version
    echo "$usage"
    exit 1
fi

if [ -z "$pw" ] && [ "$role" != "client" ]; then
    echo "$PNAME Password not provided. Please provide the mysql root password."
    read_password
    if [ $? -ne 0 ]; then 
        echo "$PNAME Error obtaining mysql password"
        exit 1
    fi
    pw=$(cat $pwfile 2>/dev/null)
fi

ssh="ssh"
scp="scp"

if [ $usegcp -gt 0 ]; then
    ssh="$GSSH"
    scp="$GSCP"
    if [ -n "$zone" ]; then
        ssh="$ssh --zone $zone"
        scp="$scp --zone $zone"
    fi
else
    if [ -n "$ident" ]; then
        ( ssh-add $ident )
    fi
fi

IFS=$' '

for host in $hosts; do
    echo " -> Installing client for '$host'"

    if [ $usegcp -gt 0 ]; then
        hostssh="$ssh $user@$host --command"
    else
        hostssh="$ssh $user@$host"
    fi

    # copy repo, repo key, and server config
    ( $scp ${tdh_path}/../etc/mysql-community.repo ${user}@${host}: )
    ( $scp ${tdh_path}/../etc/RPM-GPG-KEY-mysql ${user}@${host}: )

    if [ $? -gt 0 ]; then
        echo "$TDH_PNAME Error in initial 'scp'. Bad host? Aborting.."
        exit 1
    fi

    # Install Client
    ( $hostssh 'sudo cp mysql-community.repo /etc/yum.repos.d' )
    ( $hostssh 'sudo cp RPM-GPG-KEY-mysql /etc/pki/rpm-gpg/')
    ( $hostssh 'sudo yum install -y mysql-community-libs mysql-community-client' )

    # Install specific 5.1.46 JDBC Driver
    ( $hostssh 'wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.46.tar.gz' )
    ( $hostssh 'tar zxf mysql-connector-java-5.1.46.tar.gz; \
      sudo mkdir -p /usr/share/java; \
      sudo cp mysql-connector-java-5.1.46/mysql-connector-java-5.1.46-bin.jar /usr/share/java/; \
      sudo chmod 644 /usr/share/java/mysql-connector-java-5.1.46-bin.jar; \
      sudo ln -s /usr/share/java/mysql-connector-java-5.1.46-bin.jar /usr/share/java/mysql-connector-java.jar; \
      rm -rf mysql-connector-java-5.1.46 mysql-connector-java-5.1.46.tar.gz' )
    ( $hostssh 'rm mysql-community.repo RPM-GPG-KEY-mysql' )
done

if [ "$role" == "client" ]; then
    echo "$TDH_PNAME client install finished."
    exit 0
fi

host="$hosts"
if [ $usegcp -gt 0 ]; then
    ssh="$ssh $user@$host --command"
else
    ssh="$ssh $user@$host"
fi

( $scp ${tdh_path}/../etc/tdh-mysql.cnf ${user}@${host}:my.cnf )

if [ "$role" == "slave" ]; then
    if [ $id -eq 1 ]; then
        id=2
    fi
    ( $ssh 'mv my.cnf my-1.cnf' )
    ( $ssh "sed -E 's/^(server-id[[:blank:]]*=[[:blank:]]*).*/\1$id/' my-1.cnf > my.cnf" )
    ( $ssh "rm my-1.cnf" )
    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in sed for slave my.cnf"
    fi
fi


# Install Server
if [ "$role" == "master" ] || [ "$role" == "slave" ]; then
    echo " -> Installing MySQL Server role"

    ( $ssh 'sudo yum install -y mysql-community-server' )
    ( $ssh 'sudo cp my.cnf /etc/my.cnf && sudo chmod 644 /etc/my.cnf' )
    ( $ssh 'sudo mysqld --initialize-insecure --user=mysql' )
    ( $ssh 'sudo systemctl start mysqld' )
    ( $ssh 'sudo systemctl enable mysqld' )
    ( $ssh 'rm my.cnf' )

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error starting mysql daemon"
        exit $rt
    fi

    echo " -> Configuring MySQL root password"
    ( $ssh "printf \"[mysql]\nuser=root\npassword=$pw\n\" > .my.cnf"  )
    ( $ssh "chmod 600 .my.cnf" )
    ( $ssh "sudo cp .my.cnf /root/" )
    ( $ssh "mysql -u root --skip-password -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '$pw'\"" )

    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in Mysql ALTER USER, setting root password."
    fi
fi

echo "$TDH_PNAME Finished."
exit $rt
