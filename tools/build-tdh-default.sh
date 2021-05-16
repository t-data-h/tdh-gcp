#!/bin/bash
#

# minimally sized test cluster

# 3 masters
./bin/tdh-instance-init.sh \
--network tdh-net \
--subnet tdh-net-west1-5 \
--tags tdh \
--type n1-standard-2 \
run m01 m02 m03

# 3 workers
./bin/tdh-instance-init.sh \
--network tdh-net \
--subnet tdh-net-west1-5 \
--tags tdh \
--type n1-standard-4 \
--attach \
--disknum 2 \
--disksize 256GB \
--use-xfs \
run d01 d02 d03 

