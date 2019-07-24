#!/bin/bash
#
#  Install wrapper script to distribute packages and run the installation
#
PNAME=${0##*\/}
tdh_path=$(dirname "$(readlink -f "$0")")

TDH_ANSIBLE_HOME=$(dirname $tdh_path)
action=
dryrun=1
rt=0

# -------

if [ -e $TDH_ANSIBLE_HOME/../etc/tdh-gcp-config.sh ]; then
    . $TDH_ANSIBLE_HOME/../etc/tdh-gcp-config.sh
fi

# -------

while [ $# -gt 0 ]; do
    case "$1" in
        -T|--tags)
            tags="$2"
            shift
            ;;
        -V|--version)
            echo "$PNAME  (tdh-gcp)  v$TDH_GCP_VERSION"
            exit 1
            ;;
        *)
            action="$1"
            shift
            ;;
    esac
    shift
done


if [ -z "$action" ]; then
    echo ""
    echo "Usage: $PNAME <action> "
    echo "  any action other than 'run' is a 'dryrun'"
    echo ""
fi


if [[ $action == "run" ]]; then
    dryrun=0
fi


cd $TDH_ANSIBLE_HOME

echo ""
echo "TDH_ANSIBLE_HOME = '$TDH_ANSIBLE_HOME'"
echo "Running Ansible Playbooks : tdh-distribute, tdh_install"
if [ -n "$tags" ]; then
    echo "  Tags: '$tags'"
fi
echo "" 

# ------- Distribute

echo "( ansible-playbook -i inventory/tdh-west1/hosts tdh-distribute.yml )"
if [ $dryrun -eq 0 ]; then
    ( ansible-playbook -i inventory/tdh-west1/hosts tdh-distribute.yml )
    rt=$?
fi

if [ $rt -gt 0 ]; then
    echo "$PNAME: Error in Distribute, Aborting."
    exit $rt
fi

# ------- Install

cmd="ansible-playbook -i inventory/tdh-west1/hosts"

if [ -n "$tags" ]; then
    cmd="$cmd --tags $tags"
fi
cmd="$cmd tdh-install.yml"

echo "( $cmd )"
if [ $dryrun -eq 0 ]; then
    ( $cmd )
    rt=$?
fi

exit $rt
