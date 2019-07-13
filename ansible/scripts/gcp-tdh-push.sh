#!/bin/bash
#
#
rt=0

GCPHOST="tdh-m01"
GITREPO="${HOME}/src/github"
DISTPATH="${HOME}/tmp/dist"

TDH_HADOOP_DIR="${GITREPO}/tdh-hadoop"
TDH_CONF_DIR="${TDH_HADOOP_DIR}/conf"
TDH_GCP_DIR="./tdh-gcp/"


cd $TDH_CONF_DIR

( tar -cvf ${DISTPATH}/tdh-conf.tar ./tdh-conf/ )
( gzip ${DISTPATH}/tdh-conf.tar )
( gcloud compute scp ${DISTPATH}/tdh-conf.tar.gz ${GCPHOST}:/tmp/TDH/ )

rt=$?
if [ $rt -gt 0 ]; then
    echo "Error in gcp"
    exit $rt
fi

( rm ${DISTPATH}/tdh-conf.tar.gz )

#
# TDH-GCP
#

cd $GITREPO

( tar -cvf ${DISTPATH}/tdh-gcp.tar $TDH_GCP_DIR )
( gzip  ${DISTPATH}/tdh-gcp.tar )
( gcloud compute scp ${DISTPATH}/tdh-gcp.tar.gz ${GCPHOST}: )

rt=$?

if [ $rt -eq 0 ]; then
    ( rm ${DISTPATH}/tdh-gcp.tar.gz )
fi

exit $rt
