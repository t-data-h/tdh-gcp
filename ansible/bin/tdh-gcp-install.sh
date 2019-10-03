#!/bin/bash
#
#  Install wrapper script to distribute packages and run the installation
#
tdh_path=$(dirname "$(readlink -f "$0")")

TDH_ANSIBLE_HOME=$(dirname $tdh_path)

action=
env=
dryrun=1

# -------

if [ -e $TDH_ANSIBLE_HOME/../bin/tdh-gcp-config.sh ]; then
    . $TDH_ANSIBLE_HOME/../bin/tdh-gcp-config.sh
fi

# -------

usage() 
{
    echo ""
    echo "Usage: $TDH_PNAME <action> <env>"
    echo "  <action> any action other than 'run' is a 'dryrun'"
    echo "  <env>    is the inventory name for the gcp environment."
    echo ""
    echo " The environment variable TDH_GCP_ENV is honored if the"
    echo "environment parameter is not provided."
    echo ""
}

# MAIN
#
rt=0

while [ $# -gt 0 ]; do
    case "$1" in
        -T|--tags)
            tags="$2"
            shift
            ;;
        -V|--version)
            tdh_version
            exit 1
            ;;
        *)
            action="$1"
            env="$2"
            shift $#
            ;;
    esac
    shift
done

if [ -z "$env" ] && [ -n "$TDH_GCP_ENV" ]; then
    env="$TDH_GCP_ENV"
fi

if [ -z "$action" ] || [ -z "$env" ]; then
    usage
    exit 1
fi

if [[ $action == "run" ]]; then
    dryrun=0
fi

cd $TDH_ANSIBLE_HOME

echo ""
echo "TDH_ANSIBLE_HOME = '$TDH_ANSIBLE_HOME'"
echo "TDH_GCP_ENV      = '$env'"
echo "Running Ansible Playbooks : tdh-distribute, tdh_install"
if [ -n "$tags" ]; then
    echo "  Tags: '$tags'"
fi
echo "" 

# ------- Distribute

echo "( ansible-playbook -i inventory/$env/hosts tdh-distribute.yml )"
if [ $dryrun -eq 0 ]; then
    ( ansible-playbook -i inventory/$env/hosts tdh-distribute.yml )
    rt=$?
fi

if [ $rt -gt 0 ]; then
    echo "$PNAME: Error in Distribute, Aborting."
    exit $rt
fi

# ------- Install

cmd="ansible-playbook -i inventory/$env/hosts"

if [ -n "$tags" ]; then
    cmd="$cmd --tags $tags"
fi
cmd="$cmd tdh-install.yml"

echo "( $cmd )"
if [ $dryrun -eq 0 ]; then
    ( $cmd )
    rt=$?
fi

echo ""
echo "If this is a new install don't forget to run the"
echo "playbook 'tdh-postinstall.yml'"
echo "$TDH_PNAME finished. "

exit $rt
