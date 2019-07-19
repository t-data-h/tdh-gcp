#!/bin/bash
#  Install wrapper script to sync configs only
#
PNAME=${0##*\/}
tdh_path=$(dirname "$(readlink -f "$0")")

TDH_ANSIBLE_HOME=$(dirname $tdh_path)
ACTION="$1"
rt=0

# distribute
echo "Running Ansible Playbooks : tdh-distribute, tdh_install --tags tdh-python"
echo "TDH_ANSIBLE_HOME = '$TDH_ANSIBLE_HOME'"

if [ -z "$ACTION" ]; then
    echo ""
    echo "Usage: $PNAME <action> "
    echo "  any action other than 'run' is a 'dryrun'"
    echo ""
    exit 0
fi

cd $TDH_ANSIBLE_HOME

echo "( ansible-playbook -i inventory/tdh-west1/hosts tdh-distribute.yml )"
if [[ $ACTION == "run" ]]; then
    ( ansible-playbook -i inventory/tdh-west1/hosts tdh-distribute.yml )
    rt=$?
fi

if [ $rt -gt 0 ]; then
    echo "$PNAME: Error in Distribute, Aborting."
    exit $rt
fi

# install
echo "( ansible-playbook -i inventory/tdh-west1/hosts --tags tdh-python tdh-install.yml )"
if [[ $ACTION == "run" ]]; then
    ( ansible-playbook -i inventory/tdh-west1/hosts --tags tdh-config tdh-install.yml )
    rt=$?
fi

exit $rt
