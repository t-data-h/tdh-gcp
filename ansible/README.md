TDH GCP Ansible Framework
=========================



### Setting environment passwords

Create the following yaml file as *./inventory/ENV/group_vars/all/vault*:
```
---
mysql_root_password: 'rootpw'
mysql_repl_password' 'replpw'

hive_password: 'hivepw'
hue_password: 'huepw'
```

The file should be encrypted via the command:
```
ansible-vault encrypt ./inventory/ENV/group_vars/all/vault
```
and decrypted similarly using the 'decrypt' command. The password can be stored
in a password vault file of .ansible/.ansible_vault as defined in the ansible.cfg
file given that the .ansible directory is untracked via .gitignore.
```
echo 'myvaultpw' > ./ansible/.ansible/.ansible_vault
chmod 400 !$
```
