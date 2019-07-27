TDH GCP Ansible Framework
=========================

Ansible playbooks for distributing and configuring a TDH environment in GCP. 
The environment is defined by the inventory files located in 
*inventory/env/* where *env* is a specific TDH deployment.

The install is initiated by the *tdh-install.yml* playbook, but requires 
assets to be distributed first via *tdh-distribute.yml*. Wrapper scripts 
are provided to run the various stages:

- tdh-install.sh:  Full-run, distribute + the install playbook.
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


## Deploying TDH via Ansible:

Deploying TDH comes down to three steps. 
1) Distribute the Assets 
2) Deploy Assets and Configuration 
3) Run any post-install steps.

### Distribute:

  The first step is to distribute the various assets via the playbook *tdh-distribute.yml*. This play looks in a distribution input path for a set of 
assets; this path defaults to *~/tmp/dist*.

There are 4 packages that are used by the deploy playbook:

- **TDH.tar.gz**  
  The main binary distribution of the complete TDH Ecosystem.
- **tdh-hadoop.tar.gz**  
  The TDH Manager package consisting of the framework of scripts used to support 
  cluster operations.
- **tdh-conf.tar.gz**  
  The configuration package that is used to overlay and update 
  the cluster configuration.
- **tdh-anaconda3.tar.gz**  
  The Anaconda Python distribution for utilizing Python3 on the cluster.

If any of these packages exist in the landing path, they are distributed to all
nodes of the cluster to a temporary drop path for use by the install phase.

### Install:

 The second step is to run the install playbook *tdh-install.yml*. This will run through all prerequisites and install/update the TDH Enviornment depending on what 'dropfiles' exist in 
 the 'droppath'. The installation is capable of being run over an existing installation without affecting the install. The wrapper scripts are provided to run just portions of the install playbook related to just updating cluster configs, the tdh-mgr framework, or the 
 python anaconda distribution.

### Post-Install

The final step is to be run after the successful completion of step 2 and the cluster 
is up and operational. It mostly performs some HDFS directory seeding 
needed for the cluster to be fully operational. (hive warehouse and permissions, log 
directories for aggregation, etc.)
