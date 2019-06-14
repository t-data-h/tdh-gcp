#!/bin/bash

gcphost="$1"
isMaster="$2"

#acquire pw
pw="tdhrootsql"

# Mysql
( gcloud compute scp ${tdh_path}/etc/mysql-community.repo ${gcphost}: )

if [ -n "$isMaster" ]; then
    ( gcloud compute scp ${tdh_path}/etc/my-tdh-1.cnf ${gcphost}:my.cnf )
else
    ( gcloud compute scp ${tdh_path}/etc/my-tdh-2.cnf ${gcphost}:my.cnf )
fi

( gcloud compute ssh $gcphost sudo cp mysql-community.repo /etc/yum.repos.d )
( gcloud compute ssh $gcphost sudo yum install -y mysql-community-server \
  mysql-community-libs  mysql-community-client mysql-connector-java )
( gcloud compute ssh sudo cp my.cnf /etc/my.cnf )
( gcloud compute ssh $gcphost sudo mysqld --initialize-insecure --user=mysql )
( gcloud compute ssh $gcphost sudo service mysqld start )

printf "[mysql]\nuser=root\npassword=$pw\n" > .my.cnf

( gcloud compute ssh $gcphost mysql -u root --skip-password \
-e "ALTER USER 'root'@'localgcphost' IDENTIFIED BY '$pw'" )


