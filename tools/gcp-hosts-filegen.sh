#!/bin/bash
#
#  /etc/hosts style output for gcp external ip's

# indexed array
declare -a gary

zone="$1"
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
    ( echo "$ip     $name " | grep -v 'TERM' )
done

exit 0
