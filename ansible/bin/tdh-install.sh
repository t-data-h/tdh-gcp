#!/bin/bash
#  Install wrapper script to distribute packages and run the installation
#
PNAME=${0##*\/}
tdh_path=$(dirname "$(readlink -f "$0")")

TDH_ANSIBLE_HOME=$(dirname $tdh_path)
ACTION="$1"
rt=0

# distribute
echo "Running Ansible Playbooks : tdh-distribute, tdh_install"
echo "TDH_ANSIBLE_HOME = '$TDH_ANSIBLE_HOME'"

if [ -z "$ACTION" ]; then
    echo ""
    echo "Usage: $PNAME <action> "
    echo "  any action other than 'run' does nothing"
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
echo "( ansible-playbook -i inventory/tdh-west1/hosts tdh-install.yml )"
if [[ $ACTION == "run" ]]; then
    ( ansible-playbook -i inventory/tdh-west1/hosts tdh-install.yml )
    rt=$?
fi

exit $rt
