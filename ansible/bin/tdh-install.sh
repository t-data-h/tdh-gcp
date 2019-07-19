#!/bin/bash
#
#  Install wrapper script to distribute packages and run the installation
#
PNAME=${0##*\/}
tdh_path=$(dirname "$(readlink -f "$0")")

TDH_ANSIBLE_HOME=$(dirname $tdh_path)
ACTION="$1"
dryrun=1
rt=0

# -------

if [ -e $TDH_ANSIBLE_HOME/../bin/tdh-gcp-config.sh ]; then
    . $TDH_ANSIBLE_HOME/../bin/tdh-gcp-config.sh
fi


if [ -z "$ACTION" ]; then
    echo ""
    echo "Usage: $PNAME <action> "
    echo "  any action other than 'run' is a 'dryrun'"
    echo ""
    exit 0
fi

# -------

case "$ACTION" in
    -V|--version)
        echo "$PNAME  (tdh-gcp)  v$TDH_GCP_VERSION"
        exit 1
        ;;
    run)
        dryrun=0
        ;;
    *)
        ;;
esac

cd $TDH_ANSIBLE_HOME

echo "Running Ansible Playbooks : tdh-distribute, tdh_install"
echo "TDH_ANSIBLE_HOME = '$TDH_ANSIBLE_HOME'"
echo "" 

# ------- Distribute

echo "( ansible-playbook -i inventory/tdh-west1/hosts tdh-distribute.yml )"
if [[ $dryrun -eq 0 ]]; then
    ( ansible-playbook -i inventory/tdh-west1/hosts tdh-distribute.yml )
    rt=$?
fi

if [ $rt -gt 0 ]; then
    echo "$PNAME: Error in Distribute, Aborting."
    exit $rt
fi

# ------- Install

echo "( ansible-playbook -i inventory/tdh-west1/hosts tdh-install.yml )"
if [[ $dryrun -eq 0 ]]; then
    ( ansible-playbook -i inventory/tdh-west1/hosts tdh-install.yml )
    rt=$?
fi

exit $rt
