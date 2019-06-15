#!/bin/bash
#
PNAME=${0##*\/}
tdh_path=$(dirname "$(readlink -f "$0")")

host="$1"
role="$2"
pw=
rt= 


usage()
{
    echo ""
    echo "Usage: $PNAME [options]  <host>  <ROLE>"
    echo "  -h|--help          = Display help and exit"
    echo "  -p|--password <pw> = The root mysql password"
    echo "  -P|--pwfile <file> = File containing root mysql password"
    echo " Where ROLE is 'master', 'slave', or 'client'"
    echo ""
}


read_password() {
    local prompt="Password: "
    local pval=
    
    echo "Please provide the mysql root password."
    echo ""
    read -s -p "$prompt" pw
    echo ""
    read -s -p "Repeat $prompt" pval

    if [[ "$pw" != "$pval" ]]; then
        echo "Error! Passwords do not match. Abort"
        return 1
    fi

    return 0
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
            if [ -r "$2" ]; then
                pw=$(cat $2)
            fi
            shift
            ;;
        *)
            host="$1"
            role="$2"
            shift $#
            ;;
    esac
done


if [ -z "$host" ] || [ -z "$role" ]; then
    usage
    exit 1
fi

if [ -z "$pw" ]; then
    echo "Error, no password set."
    usage
    exit 1
fi


# Mysql
( gcloud compute scp ${tdh_path}/etc/mysql-community.repo ${host}: )
( gcloud compute scp ${tdh_path}/etc/tdh-mysql.cnf ${host}:my.cnf )


if [ "$role" == "slave" ]; then
    ( gcloud compute ssh $host --command 'mv my.cnf my-1.cnf' )
    ( gcloud compute ssh $host --command "sed -E 's/^(server-id[[:blank:]]*=[[:blank:]]*).*/\12/' my-1.cnf > my.cnf" )
    rt=$?
    if [ $rt -gt 0 ]; then
        echo "Error in sed of slave my.cnf"
    fi
fi


( gcloud compute ssh $host --command 'sudo cp mysql-community.repo /etc/yum.repos.d' )
( gcloud compute ssh $host --command 'sudo yum install -y mysql-community-libs mysql-community-client mysql-connector-java' )


if [ "$role" == "master" ] || [ "$role" == "slave" ]; then
    ( gcloud compute ssh $host --command 'sudo yum install -y mysql-community-server' )
    ( gcloud compute ssh $host --command 'sudo cp my.cnf /etc/my.cnf && chmod 644 /etc/my.cnf' )
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
