#!/usr/bin/env bash
#
# fwruleupdate.sh
# GCP Firewall External IP rule update
#
rulename="$1"
rhost="$2"
bin="gcp-fw-ingress.sh"

if [[ -z "$rulename" || -z "$rhost" ]]; then
    echo "Usage: $0 <rulename> <remote-host>"
    exit 1
fi

if ! which ${bin} > /dev/null 2>&1; then
    bin="${HOME}/bin/${bin}"
    if [[ ! -x "$bin" ]]; then
        echo "Error: $bin not found or not executable."
        exit 1
    fi
fi

ip="$(curl ifconfig.io -4 2>/dev/null)/32"
cur=$(gcp-fw-ingress.sh describe $rulename 2>/dev/null | yq .sourceRanges.[0])

echo "ip: $ip"
echo "fw: $cur"

if [[ "$ip" == "$cur" ]]; then
    echo "$rule ip $ip unchanged"
    exit 0
fi

echo "$ip" > /tmp/external.ip
( scp /tmp/external.ip ${rhost}: )

gcp-fw-ingress.sh delete $rulename
sleep 5
gcp-fw-ingress.sh create $rulename $ip tcp:22

exit $?
