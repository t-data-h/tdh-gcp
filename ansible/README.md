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

### Distributing Assets:

  The first step is to distribute the various assets. From the ansible server,
  this happens via the playbook *tdh-distribute.yml*. This play looks for specific 
  assets from an input path to distribute to hosts. This input path defaults 
  to *~/tmp/dist* and will push assets to /tmp/TDH. These values are configured as 
  part of the common role *vars* or more specifically *roles/common/vars/main.yml*.

There are 4 packages that are expected by the deploy playbook:

* **TDH.tar.gz**  
  The main binary distribution of the complete TDH Ecosystem.
* **tdh-mgr.tar.gz**  
  The TDH Manager package consisting of the framework of scripts used to support 
  cluster operations.
* **tdh-conf.tar.gz**  
  The configuration overlay package that is the cluster configuration.
* **tdh-anaconda3.tar.gz**  
  The Anaconda Python distribution for utilizing Python3 on the cluster.

If any of these packages exist in the input landing path, they are distributed to 
all nodes of the cluster for use by the install phase.

### Install:

The wrapper script for running both the deploy and install playbooks is called
*./bin/tdh-gcp-install.sh*.  This will run *tdh-install.yml* playbook and install
 all prerequisites and install/update the TDH Enviornment depending on what 
 'dropfiles' exist in the 'droppath'. The installation is capable of being run over 
 an existing installation without affecting the install. Additional scripts are 
 provided to run portions of the install playbook related to updating cluster 
 configs, the tdh-mgr framework, or the python anaconda distribution. Running the 
 playbook with no files would result in running through just the prerequisites, 
 which can be handy as a general node bootstrapping.

### Post-Install

Once a full TDH install has run, the final step is to run the post-install 
playbook, *tdh-postinstall.yml*. This is a one-time operation that performs 
some HDFS directory seeding needed for the cluster to be fully operational. 
(eg. hive warehouse and permissions, log directories for aggregation, etc.)
