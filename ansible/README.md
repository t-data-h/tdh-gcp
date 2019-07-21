TDH GCP Ansible Framework
=========================

Ansible playbooks for distributing and configuring a TDH environment in GCP. 
The environment is defined by the inventory files located in 
*inventory/env/* where *env* is a specific TDH deployment.

The install is initiated by the *tdh-install.yml* playbook, but requires 
assets to be distributed first via *tdh-distribute.yml*. Wrapper scripts 
are provided to run the various stages:

- tdh-install.sh:  Primary full-run, distribute + the install playbook.
- tdh-config-update.sh:  Runs distribute and only the cluster config update steps.
- tdh-mgr-update.sh: Runs distribute and only the tdh-mgr update steps
- tdh-python-update.sh: Runs distribute and pushes the Ananconda distribution.


### Setting environment passwords

Create the following yaml file as *inventory/ENV/group_vars/all/vault*:
```
---
mysql_root_password: 'rootpw'
mysql_repl_password' 'replpw'

mysql_hive_password: 'hivepw'
mysql_hue_password: 'huepw'
```

The file should be encrypted via the command:
```
ansible-vault encrypt ./inventory/ENV/group_vars/all/vault
```
and decrypted similarly using the 'decrypt' command. The password can be stored
in a password vault file of .ansible/.ansible_vault as defined in the ansible.cfg
file given that the .ansible directory is untracked via .gitignore.
```
echo 'myvaultpw' > .ansible/.ansible_vault
chmod 400 !$
```
