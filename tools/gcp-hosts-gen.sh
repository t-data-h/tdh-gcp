#!/usr/bin/env bash
#
#  /etc/hosts style output for gcp external ip's
#  only correct for project 'global' wide dns not zonal dns
PNAME=${0##\/.*}

# -----------------------------------
( which gcloud > /dev/null 2>&1 )
if [ $? -ne 0 ]; then
    echo "Error 'gcloud' cli not found."
    exit 1
fi

# indexed array
declare -a gary

# -----------------------------------
zone="$1"
project=$( gcloud config configurations list | grep True | awk '{ print $4 }' )
dom="c.${project}.internal"
cmd="gcloud compute instances list"

if [ -n "$zone" ]; then
    cmd="$cmd --zones $zone"
fi

glist=$( $cmd | tail -n+2 | awk '{ print $1, $5 }' )

i=0
for ln in $glist; do
    gary[i++]="$ln"
done

for (( i=0; i<${#gary[@]}; i++ )); do
    name="${gary[i]}"
    ip="${gary[++i]}"
    fqdn="${name}.${dom}"

    if [[ $ip =~ TERMINATED ]]; then
        continue
    fi
    ( printf '%-15s    %-35s    %-15s\n' $ip $fqdn $name )
done

exit 0
