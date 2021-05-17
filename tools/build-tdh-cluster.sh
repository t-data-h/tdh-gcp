#!/bin/bash
#
# build spec for a small sized test cluster
#
tdh_path=$(dirname "$(readlink -f "$0")")

if [ -f ${tdh_path}/../bin/tdh-gcp-env.sh ]; then
    . ${tdh_path}/../bin/tdh-gcp-env.sh
fi

network="tdh-net"
subnet="tdh-net-west1-5"
prefix="10.10.5.0/24"

mtype="n1-standard-2"
dtype="n1-standard-4"

# --------------

if [ ! -x ./bin/gcp-networks.sh ]; then
    echo "gcp-networks.sh not found. Run this from tdh-gcp root"
    exit 1
fi

if ./bin/gcp-networks.sh list-subnets | grep "^$subnet" >/dev/null; then
    echo "GCP Network '$subnet' already exists.."
    network=$(./bin/gcp-networks.sh list-subnets | grep "^$subnet" | awk '{ print $3 }')
    prefix=$(./bin/gcp-networks.sh list-subnets | grep "^$subnet" | awk '{ print $4 }')
else
    echo "( ./bin/gcp-networks.sh --addr $prefix --yes create $network $subnet )"
fi

# 3 masters
echo " -> Masters:"

echo "
./bin/tdh-instance-init.sh \
  --network $network \
  --subnet $subnet \
  --tags tdh \
  --type $mtype \
  run m01 m02 m03
"

# 4 workers
echo " -> Workers:"

echo "
./bin/tdh-instance-init.sh \
  --network $network \
  --subnet $subnet \
  --tags tdh \
  --type $dtype \
  --attach \
  --disknum 4 \
  --disksize 256GB \
  --use-xfs \
  run d01 d02 d03 d04
"

exit 0
