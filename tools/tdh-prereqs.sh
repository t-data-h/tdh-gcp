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

# -----------------------------------

yum_prereqs="wget yum-utils coreutils rng-tools bind-utils net-tools iputils ethtool epel-release"
apt_prereqs="wget coreutils dnsutils rng-tools iputils-arping ethtool"
cloudsdk="/etc/yum.repos.d/google-cloud.repo"
gcp=0
rt=0

if [ -n "$TDH_PREREQS" ]; then
    prereqs="$TDH_PREREQS"
fi

if [ -e "$cloudsdk" ]; then
    gcp=1
fi

. /etc/os-release

if [[ "$ID" =~ "ubuntu" ]]; then
    if [ -z "$prereqs" ]; then 
        prereqs="$apt_prereqs"
    fi
    ( sudo apt install $prereqs )
    exit $?
fi

if [ -z "$prereqs" ]; then
    prereqs="$yum_prereqs"
fi

# -----------------------------------

cmd="sudo yum install -y"

# Disable cloud sdk repo check
if [ $gcp -eq 1 ]; then
    cmd="$cmd --disablerepo=google-cloud-sdk"
fi

cmd="$cmd $prereqs"

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
