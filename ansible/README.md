TDH GCP Ansible Framework
=========================

Ansible playbooks for distributing and configuring a TDH environment in GCP. The
environment is defined by the inventory files located in *inventory/env/* where
*env* is a specific TDH deployment.

The install is initiated by the *tdh-install.yml* playbook.
```
ansible-playbook -i inventory/tdh-west1/hosts tdh-install.yml
```
Additionally, three packages are utilized to perform the install.
*TDH.tar.gz*: The primary tarball consisting of the full TDH Distribution.
*tdh-conf.tar.gz*: The configuration package to be overlayed on the distribution.
*anaconda3.tar.gz*: The python anaconda distribution for supporting python3.

These packages should be placed in */tmp/TDH* on the Ansible Server to be
picked up by the playbook.


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
