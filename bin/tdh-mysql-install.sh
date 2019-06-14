#!/bin/bash
#
PNAME=${0##*\/}
tdh_path=$(dirname "$(readlink -f "$0")")

gcphost="$1"
role="$2"
rt= 

if [ -z "$gcphost" ] || [ -z "$role" ]; then
    echo "Usage: $PNAME <host> <master|slave|client>"
fi


#acquire pw
pw="tdhrootsql"

# Mysql
( gcloud compute scp ${tdh_path}/etc/mysql-community.repo ${gcphost}: )

if [ "$role" == "master" ]; then
    ( gcloud compute scp ${tdh_path}/etc/my-tdh-1.cnf ${gcphost}:my.cnf )
elif [ "$role" == "slave" ]; then
    ( gcloud compute scp ${tdh_path}/etc/my-tdh-2.cnf ${gcphost}:my.cnf )
fi

( gcloud compute ssh $gcphost sudo cp mysql-community.repo /etc/yum.repos.d )

( gcloud compute ssh $gcphost sudo yum install -y mysql-community-libs  mysql-community-client mysql-connector-java )

if [ "$role" == "master" ] || [ "$role" == "slave" ]; then
    ( gcloud compute ssh $gcphost sudo yum install -y mysql-community-server )
    ( gcloud compute ssh sudo cp my.cnf /etc/my.cnf )
    ( gcloud compute ssh $gcphost sudo mysqld --initialize-insecure --user=mysql )
    ( gcloud compute ssh $gcphost sudo service mysqld start )

    printf "[mysql]\nuser=root\npassword=$pw\n" > .my.cnf

    ( gcloud compute ssh $gcphost mysql -u root --skip-password -e "ALTER USER 'root'@'localgcphost' IDENTIFIED BY '$pw'" )
fi

echo "$PNAME finished."

exit 0


