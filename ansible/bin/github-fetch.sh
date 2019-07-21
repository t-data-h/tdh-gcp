#!/bin/bash
#
# Ansible to acquire git repo and deploy on all masters.

reponame="$1"
giturl="$2"

default_git="https://github.com/tcarland"
default_repo="tdh-gcp"i


if [ -z "$reponame" ]; then
    echo "Project repo name required. eg $0 $default_repo"
    exit 1
fi


if [ -z "$giturl" ]; then
    giturl="$default_git"
fi

( ansible mn -m git -a "repo=${giturl}/${reponame} dest=${HOME} version=HEAD" )

exit $?

