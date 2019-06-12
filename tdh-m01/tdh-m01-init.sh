#!/bin/bash
#
#  Initialize our master instance

tdh_path=$(dirname "$(readlink -f "$0")")
prefix="tdh"
name="m01"
host="${prefix}-${name}"
rt=

# Create Instance
( $tdh_path/bin/tdh-gcp-compute.sh --prefix ${prefix} --type n1-standard-4 \
--attach --disksize 200GB create ${name} )

rt=$?

if [ $rt -gt 0 ]; then
    echo "Error in GCP initialization"
    exit $rt
fi

# Device format and mount
device="/dev/sdb"
mountpoint="/data"

( gcloud compute scp ${tdh_path}/bin/tdh-gcp-format.sh ${host} )
( gcloud compute ssh ${host} -- chmod u+x tdh-gcp-format.sh )
( gcloud compute ssh ${host} -- ./tdh-gcp-format.sh $device $mountpoint )

# prereq's
sudo yum install -y java-1.8.0-openjdk wget
sudo yum erase mariadb-libs

# Altus
sudo wget "http://archive.cloudera.com/director6/6.2/redhat7/cloudera-director.repo"
sudo yum install -y cloudera-director-server cloudera-director-client
sudo service cloudera-director-server start
sudo systemctl disable firewalld
sudo systemctl stop firewalld

# Mysql
mkdir mysql
wget https://dev.mysql.com/get/mysql-community-common-5.7.24-1.el7.x86_64.rpm -P ./mysql
wget https://dev.mysql.com/get/mysql-community-libs-5.7.24-1.el7.x86_64.rpm -P ./mysql
wget https://dev.mysql.com/get/mysql-community-libs-compat-5.7.24-1.el7.x86_64.rpm -P ./mysql
wget https://dev.mysql.com/get/mysql-community-client-5.7.24-1.el7.x86_64.rpm -P ./mysql
wget https://dev.mysql.com/get/mysql-community-server-5.7.24-1.el7.x86_64.rpm -P ./mysql

# install is in the same order
python -c 'import base64, os; print base64.b64encode(os.urandom(24))'
Set the Altus Director configuration property lp.encryption.twoWayCipherConfig to
the Base64-encoded key string before starting Altus Director for the first time.
