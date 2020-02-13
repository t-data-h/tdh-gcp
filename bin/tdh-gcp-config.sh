#!/bin/bash
#
#  TDH-GCP Configuration sourced by bash scripts
#
#  @author Timothy C. Arland <tcarland@gmail.com>
#
export TDH_GCP_CONFIG=1

TDH_PNAME=${0##*\/}

TDH_GCP_VERSION="1.4.6"
TDH_GCP_PREFIX="tdh"

GCP_DEFAULT_MACHINETYPE="n1-standard-4"
GCP_DEFAULT_BOOTSIZE="64GB"
GCP_DEFAULT_DISKSIZE="256GB"

GCP_DEFAULT_IMAGE="centos-7"
GCP_DEFAULT_IMAGEPROJECT="centos-cloud"
GCP_ENABLE_VGA="--enable-display-device"

HAVEGCP=$( which gcloud 2>/dev/null )

if [ -n "$HAVEGCP" ]; then
    GCP_DEFAULT_REGION=$( gcloud config list 2>/dev/null | grep region | awk -F"= " '{ print $2 }' )
    GCP_DEFAULT_ZONE=$( gcloud config list 2>/dev/null | grep zone | awk -F"= " '{ print $2 }' )
    GCP_PROJECT_NAME=$( gcloud config configurations list | grep True | awk '{ print $4 }' )
fi

GSSH="gcloud compute ssh"
GSCP="gcloud compute scp"

TDH_FORMAT="tdh-format.sh"
TDH_PUSH="tdh-push.sh"
TDH_PREREQS="tdh-prereqs.sh"

# -----------------------------------

function tdh_version() {
    printf "$TDH_PNAME: (tdh-gcp) v$TDH_GCP_VERSION\n"
}


function wait_for_gcphost() {
    local host="$1"
    local zone="$2"
    local rt=1
    local cmd="$GSSH $host"
    local x=

    if [ -z "$host" ]; then
        echo "wait_for_gcphost(): target not provided."
        return $rt
    fi

    if [ -n "$zone" ]; then
        cmd="$cmd --zone $zone"
    fi

    ( sleep 3 )

    for x in {1..5}; do
        yf=$( $cmd --command 'uname -n' 2>/dev/null )
        if [[ $yf == $host ]]; then
            #echo " It's ALIIIIVE!!!"
            rt=0
            break
        fi
        echo -n ". "
        sleep 3
    done

    return $rt
}


function region_is_valid()
{
    local reg="$1"
    ( gcloud compute regions list | grep "$reg " > /dev/null )
    return $?
}


function zone_is_valid()
{
    local zn="$1"
    ( gcloud compute zones list | grep "$zn " > /dev/null )
    return $?
}


function network_is_valid()
{
    local net="$1"
    ( gcloud compute networks list | grep "$net " > /dev/null )
    return $?
}


function list_networks()
{
    ( gcloud compute networks list )
    return $?
}


function subnet_is_valid()
{
    local net="$1"
    local reg="$2"

    if [ -z "$reg" ]; then
        reg="$GCP_DEFAULT_REGION"
    fi

    ( gcloud compute networks subnets list | grep "$net " > /dev/null )

    return $?
}


function list_subnets()
{
    local reg="$1"

    if [ -z "$reg" ]; then
        reg="$GCP_DEFAULT_REGION"
    fi

    ( gcloud compute networks subnets list --filter="region:( $reg )" )

    return $?
}
