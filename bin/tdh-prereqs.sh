#!/bin/bash
#
#  Install host prerequisites (requires sudo access)
#
#  Most prereqs are handled during the ansible install playbook, but
#  this hook still allows for installing items needed prior to ansible
#  bootstrappping. We don't install ansible itself as we often need a
#  newer version than provided by some os repos.
#
PNAME=${0##*\/}
rt=0

cloudsdk="/etc/yum.repos.d/google-cloud.repo"
gcp=0

if [ -e "$cloudsdk" ]; then
    gcp=1
fi

# -----------------------------------

cmd="sudo yum install"

# Disable cloud sdk repo check
if [ $gcp -eq 1 ]; then
    cmd="$cmd --disablerepo=google-cloud-sdk"
fi

cmd="$cmd -y wget yum-utils rng-tools bind-utils net-tools"

( $cmd )

rt=$?

if [ $rt -eq 0 ]; then
    if [ $gcp -eq 1 ]; then
        echo "Disabling GCP Repo"
        ( sudo yum-config-manager --disable google-cloud-sdk )
    fi
fi

if [ $rt -gt 0 ]; then
    echo "Error in install."
fi

echo "$PNAME finished."
exit $rt
