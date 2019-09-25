#!/bin/bash
export TDH_GCP_INCLUDE=1

TDH_PNAME=${0##*\/}
TDH_GCP_VERSION="0.9.7"
TDH_GCP_PREFIX="tdh"

GCP_DEFAULT_MACHINETYPE="n1-standard-4"
GCP_DEFAULT_BOOTSIZE="64GB"
GCP_DEFAULT_DISKSIZE="256GB"
GCP_DEFAULT_IMAGE="centos-7"
GCP_DEFAULT_IMAGEPROJECT="centos-cloud"

GSSH="gcloud compute ssh"
GSCP="gcloud compute scp"


function tdh_version() {
    printf "$TDH_PNAME: v$TDH_GCP_VERSION\n"
}


function wait_for_gcphost() {
    local host="$1"
    local rt=1
    local x=

    if [ -z "$host" ]; then
        echo "wait_for_gcphost(): target not provided."
        return $rt
    fi

    ( sleep 3 )
    
    for x in {1..3}; do 
        yf=$( $GSSH $host --command 'uname -n' )
        if [[ $yf == $host ]]; then
            echo " It's ALIIIIVE!!!"
            rt=0
            break
        fi 
        echo -n ". "
        sleep 3
    done

    return $rt
}