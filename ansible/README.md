TDH GCP Ansible Framework
=========================

Ansible playbooks for distributing and configuring a TDH environment in GCP. 
The environment is defined by the inventory files located in 
*inventory/env/* where *env* is a specific TDH deployment.

The install is initiated by the ***tdh-install.yml*** playbook, but requires 
assets to be distributed first via ***tdh-distribute.yml***. Wrapper scripts 
are provided to run the various stages:

- tdh-install.sh:  Complete run, distribute + the install playbook.
- tdh-config-update.sh:  Runs distribute and only the cluster config update steps.
- tdh-mgr-update.sh: Runs distribute and only the tdh-mgr update steps
- tdh-python-update.sh: Runs distribute and pushes the Ananconda distribution.


## Setting environment passwords

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
file given that the .ansible directory is untracked via *.gitignore*.
```
echo 'myvaultpw' > .ansible/.ansible_vault
chmod 400 !$
```


# Deploying TDH via Ansible:

Deploying TDH comes down to three steps. 
1) Distribute the Assets 
2) Deploy Assets and Configuration 
3) Run any post-install steps.

## Distributing Assets:

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


## Installation via Playbook

The primary script for running both the deploy and install playbooks is called
***tdh-gcp-install.sh***.  This will run the *tdh-install.yml* playbook, install
all prerequisites and install/update the TDH Enviornment depending on what 
'dropfiles' exist in the 'drop_path'. The playbook is properly idempotent with
the install capable of being run over an existing installation without affect. 
The caveat here being the cluster configurations themselves, pushed by the 
playbook. 
 
The various install scripts provided are to run portions of the install playbook 
via ansible tags:

|    Script/Command      |    Tag     |        Asset            |
| ---------------------- | ---------- | ----------------------- |
| *tdh-gcp-install.sh*   |  All Tags  | *TDH.tar.gz* (and below)|
| *tdh-mgr-update.sh*    | tdh-mgr    | *tdh-mgr.tar.gz*        |
| *tdh-config-update.sh* | tdh-conf   | *tdh-conf.tar.gz*       |
| *tdh-python-update.sh* | tdh-python | *tdh-anaconda3.tar.gz*  |

Note that running the install playbook with no files would result in running 
through just the prerequisites, which in of itself can be handy for GCP host 
bootstrapping.

### TDH Assets

There are a few separate projects that make up *TDH* and it's environment. The 
cluster ecosystem is distributed as a binary package that is deployed to 
***/opt/TDH*** (by default). TDH itself will have binary components for Hadoop, 
HDFS and Yarn, HBase, Hive, Kafka, and Spark primarily, though additional components 
such as Hue, Solr, Oozie and/or Zeppelin can also be easily incorporated. 

* **TDH-MGR** is the main project for the TDH distribution and while it doesn't 
contain any of the Apache project binaries, it provides the details for creating a 
TDH distribution. The *tdh-mgr* project provides support script for managing the 
cluster processes and installs as an overly to /opt/TDH. The TDH tarball asset is 
essentially a snapshot of TDH installation, and the *tdh-mgr* tarball is the overlay. 

* **TDH-CONFIG** is not so much a project as it is a repository for tracking cluster
configurations. Similar to *tdh-mgr* it will install by running an rsync command to 
overlay the new configs on top of an existing TDH installation. Within the *tdh-config* 
directory would be subdirectories named after the specific cluster deployment/env and 
the related ecosystem configurations.
```
  tdh-config
       |
        \__ gcp-west1/
       |  
        \__ gcp-central1/
               |
                \__ hadoop
                \__ hbase
                \__ hive
                \__ kafka
                \__ spark
                |__ ...
```
The [ *tdh-config/envname* ] path would make up the root of the tdh-conf package. As 
shown above, the configuration for the central1 cluster would be pushed as the 
*tdh-conf* package as follows:
```
$ cd ..; pwd
 /path/to/tdh-gcp
$ ./bin/gcp-push.sh --zone us-central1-b ../tdh-config/gcp-central1 tdh-conf $GCP_PUSH_HOST
```
**IMPORTANT**  The environment name path under *tdh-config* must match the value 
described by the `tdh_env` variable defined in the inventory ***vars*** yaml. The 
resulting ***tdh-conf.tar.gz*** archive created will extract to a pre-defined 
distribution path with that name, */tmp/TDH/tdh_env*.  With the example above, 
this would be ***/tmp/TDH/gcp-central1***. This name should match the *tdh_env* 
value in *ansible/inventory/gcp-central1/group_vars/all/vars*.

* **TDH-ANACONDA3** is an optional package for pushing a python3 environment to the 
cluster. As an example, we can push a locally maintained anaconda distribution by using 
the push script:
```
$ ./bin/gcp-push.sh /opt/python/anaconda3 tdh-anaconda3 $GCP_PUSH_HOST
```

## Post-Install:

Once a full TDH install has run, the final step is to run the post-install playbook, 
*tdh-postinstall.yml*. This is a one-time operation that performs some HDFS directory 
seeding needed for the cluster to be fully operational. (eg. hive warehouse directory 
and permissions, log directories, hdfs tmp and user paths, etc.)

