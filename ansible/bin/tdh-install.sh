!/bin/bash

# distribute
echo "Run Playbook: tdh-distribute"

( ansible-playbook -i inventory/tdh-west1/hosts tdh-distribute.yml )

if [ $? -gt 0 ]; then
    exit $?
fi

# install
echo "Run Playbook: tdh-install"

( ansible-playbook -i inventory/tdh-west1/hosts tdh-install.yml )

exit $?
