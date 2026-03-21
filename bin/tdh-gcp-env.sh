#!/usr/bin/env bash
#
#  TDH-GCP Configuration sourced by bash scripts
#
#  @author Timothy C. Arland <tcarland@gmail.com>
#
export TDH_GCP_ENV=1

TDH_PNAME=${0##*\/}

TDH_GCP_VERSION="v26.03"
TDH_GCP_PREFIX="${TDH_GCP_PREFIX:-tdh}"

GCP_DEFAULT_MACHINETYPE="n4-standard-4"
GCP_DEFAULT_BOOTSIZE="64GB"
GCP_DEFAULT_DISKSIZE="256GB"
GCP_ENABLE_VGA="--enable-display-device"

GCP_CENTOS_IMAGE="rocky-linux-8"
GCP_CENTOS_IMAGE_PROJECT="rocky-linux-cloud"

GCP_UBUNTU_IMAGE="ubuntu-minimal-2404-lts-amd64"
GCP_UBUNTU_IMAGE_PROJECT="ubuntu-os-cloud"

GCP_DEFAULT_IMAGE="$GCP_UBUNTU_IMAGE"
GCP_DEFAULT_IMAGE_PROJECT="$GCP_UBUNTU_IMAGE_PROJECT"

GCP=$(which gcloud 2>/dev/null)
TDH_GCP_CONFIG="${TDH_GCP_CONFIG:-${HOME}/.config/tdh-gcp-config}"

GCPENV="
GCP_REGION=\$GCP_DEFAULT_REGION
GCP_ZONE=\$GCP_DEFAULT_ZONE
GCP_PROJECT_NAME=\$GCP_PROJECT_NAME
"

export GCP_DEFAULT_REGION=$(gcloud config configurations list --format json | \
    jq -r '.[] | select(.is_active == true) | .properties.compute.region')
export GCP_DEFAULT_ZONE=$(gcloud config configurations list --format json | \
    jq -r '.[] | select(.is_active == true) | .properties.compute.zone')
export GCP_PROJECT_NAME=$(gcloud config configurations list --format json | \
    jq -r '.[] | select(.is_active == true) | .properties.core.project')
#echo "$GCPENV" | envsubst > ${TDH_GCP_CONFIG}

GSSH="gcloud compute ssh"
GSCP="gcloud compute scp"

TDH_PREREQS="tdh-prereqs.sh"
TDH_FORMAT="tdh-format.sh"
TDH_PUSH="tdh-push.sh"

C_RED='\e[31m\e[1m'
C_GRN='\e[32m\e[1m'
C_YEL='\e[93m'
C_BLU='\e[34m\e[1m'
C_MAG='\e[95m'
C_CYN='\e[96m'
C_WHT='\e[97m\e[1m'
C_NC='\e[0m'

# -----------------------------------

function tdh_version() {
    printf "${C_WHT}${TDH_PNAME}:${C_NC} (tdh-gcp) ${C_WHT}${TDH_GCP_VERSION}${C_NC}\n"
}

function tdh_gcp_env() {
    echo "
    TDH_GCP_PREFIX=$TDH_GCP_PREFIX

    GCP_PROJECT_NAME=\"$GCP_PROJECT_NAME\"
    GCP_DEFAULT_REGION=\"$GCP_DEFAULT_REGION\"
    GCP_DEFAULT_ZONE=\"$GCP_DEFAULT_ZONE\"

    GCP_REGION=\"$GCP_REGION\"
    GCP_ZONE=\"$GCP_ZONE\"

    GCP_DEFAULT_MACHINETYPE=\"$GCP_DEFAULT_MACHINE_TYPE\"
    GCP_DEFAULT_BOOTSIZE=\"$GCP_DEFAULT_BOOTSIZE\"
    GCP_DEFAULT_DISKSIZE=\"$GCP_DEFAULT_DISKSIZE\"
    "
}

function tdh_generate_env() [
    echo "$GCPENV" | envsubst > "$TDH_GCP_CONFIG"
]


function wait_for_gcphost() {
    local host="$1"
    local zone="$2"
    local rt=1
    local cmd="$GSSH $host"
    local x=

    if [ -z "$host" ]; then
        echo "Error, wait_for_gcphost(): target not provided." >&2
        return $rt
    fi

    if [ -n "$zone" ]; then
        cmd="$cmd --zone $zone"
    fi

    ( sleep 3 )

    for x in {1..5}; do
        yf=$( $cmd --command 'uname -n' 2>/dev/null )
        if [[ $yf == $host ]]; then
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
    ( gcloud compute regions list | grep "$1" > /dev/null )
    return $?
}

function zone_is_valid()
{
    ( gcloud compute zones list | grep "$1" > /dev/null )
    return $?
}

function network_is_valid()
{
    ( gcloud compute networks list | grep "$1 " > /dev/null )
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
