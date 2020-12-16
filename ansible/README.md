TDH GCP Ansible Framework
=========================

Ansible playbooks for distributing and configuring a TDH environment.
The environment is defined by the inventory files located in
***inventory/env/*** where ***env*** is a specific TDH deployment.

The install is initiated by the `tdh-install.yml` playbook, but requires
assets to be distributed first via `tdh-distribute.yml`. Wrapper scripts
are provided to run the various stages:

- **tdh-install.sh**:  Complete run, distribute + the install playbook.
- **tdh-config-update.sh**:  Runs distribute and only the cluster config update steps.
- **tdh-mgr-update.sh**: Runs distribute and only the tdh-mgr update steps.
- **tdh-python-update.sh**: Runs distribute and pushes the Ananconda distribution.


## Setting environment inventory and passwords

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

The group vars for all hosts has additional environment specific variables,
that should be set accordingly. This includes hostnames as defined in the
inventory. Of important note, while the hosts file can be defined using short
names, MySQL needs consistent use of fully-qualified domain names,
ie. `hostname -f` to function properly. If these don't match, there will be
problems with the MySQL grants resulting in permission issues.

The following table describes the variables that should be defined in the
file *inventory/$env/group_vars/all/vars*.

| Variable  |   Description    |
| --------- | ---------------- |
| tdh_env   | Environment name used by the cluster configs from *tdh-config* |
| tdh_user  | Name of user to run and own the TDH distribution |
| tdh_group | Name of the group for TDH |
| ----------------------  | -------------------------------------- |
| mysql_master_hostname | Fully-Qualified Domain Name of mysql master |
| mysql_slave_hostname | Fully-Qualified Domain Name of mysql slave |
| mysql_hostname | Name used by all clients, same as master |
| mysql_port | The mysqld port to use, usually just 3306 |
| mysql_repl_user | Name of the replication user |
| mysql_hive_user | Name of the hive user |
| mysql_hive_db   | Name of the db for the Hive Metastore |
| mysql_hive_schemafile | Only adjust this for different versions of hive |
| tdh_mysql_master_hosts | Should already be set to a list of the master and slaves |
| tdh_mysql_client_hosts | All nodes in the cluster that we wish to install mysql client libs |


The following example demonstrates the typical vars file in YAML format:
```
---
tdh_env: 'my_env_name'

# set to user running tdh
tdh_user: 'myuser'
tdh_group: 'myuser'

mysql_master_hostname: 'tdh-m01.gcp-projectname.internal'
mysql_slave_hostname: 'tdh-m02.gcp-projectname.internal'
mysql_hostname: '{{ mysql_master_hostname }}'
mysql_port: 3306

mysql_repl_user: 'tdhrepl'
mysql_hive_user: 'hive'
mysql_hive_db: 'metastore'
mysql_hive_schemafile: '/opt/TDH/hive/scripts/metastore/upgrade/mysql/hive-schema-1.2.0.mysql.sql'

tdh_mysql_master_hosts:
  - '{{ mysql_master_hostname }}'
  - '{{ mysql_slave_hostname }}'

tdh_mysql_client_hosts:
  - 'tdh-m01.gcp-projectname.internal'
  - 'tdh-m02.gcp-projectname.internal'
  - 'tdh-d01.gcp-projectname.internal'
  - 'tdh-d02.gcp-projectname.internal'
  - 'tdh-d03.gcp-projectname.internal'
  - 'tdh-d04.gcp-projectname.internal'
```

<br>

---

## Deploying TDH via Ansible:

Deploying TDH comes down to three steps.
1. Distribute the Assets to nodes
2. Deploy Assets and Configuration
3. Run any post-install steps.

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
* **tdh-cluster-conf.tar.gz**  
  The configuration overlay package that is the cluster configuration.
* **tdh-anaconda3.tar.gz**  
  The Anaconda Python distribution for utilizing Python3 on the cluster.

If any of these packages exist in the input landing path, they are distributed to
all nodes of the cluster for use by the install phase.

Note that the distribute yaml gets run automatically by the install script
`./bin/tdh-install.sh`

<br>

---

## TDH Assets

There are a few separate projects that make up *TDH* and it's environment. The
cluster ecosystem is distributed as a binary package that is deployed to
***/opt/TDH*** (by default). TDH itself will have binary components for Hadoop,
HDFS and Yarn, HBase, Hive, Kafka, and Spark primarily, though additional components
such as Hue, Solr, Oozie and/or Zeppelin can also be easily incorporated.

* **TDH-MGR** is the main project for the TDH distribution and while it doesn't
contain any of the Apache project binaries, it provides the details for creating a
TDH distribution. The *tdh-mgr* project provides support scripts for managing the
cluster and installs as an overly to /opt/TDH. The TDH tarball asset *TDH.tar.gz* is
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
  ```
  The [ *tdh-config/envname* ] path would make up the root of the tdh-cluster-conf
  package. As shown above, the configuration for the central1 cluster would be
  pushed as the *tdh-cluster-conf* package with the following command:
  ```
  export TDH_PUSH_HOST="tdh-m01"
  ./bin/tdh-push.sh --use-gcp --zone us-central1-b \
    ../tdh-config/gcp-central1 tdh-cluster-conf
  ```

  **NOTE** that the path name under ***tdh-config*** must match the value
  described by the `tdh_env` variable defined in the inventory ***vars*** yaml.
  The resulting ***tdh-cluster-conf.tar.gz*** archive created will extract to
  the predefined distribution path with that name, */tmp/TDH/tdh_env*.  With
  the example above, this would be ***/tmp/TDH/gcp-central1***. This name
  must match the *tdh_env* value.

* **TDH-ANACONDA3** is an optional package for pushing a python3 environment to
  the cluster. As an example, we can push a locally maintained anaconda distribution
  by using the push script:
   ```
   ./bin/tdh-push.sh -G /opt/python/anaconda3 tdh-anaconda3 $TDH_PUSH_HOST
   ```

<br>

---

## Deploying Assets and Configuration

The primary script for running both the deploy and install playbooks is called
`tdh-install.sh`.  This will run the distribute and install playbooks, installing
all prerequisites and install/update the TDH Environment depending on what
*dropfiles* exist in the `tdh_drop_path`. The playbook is idempotent with the
install capable of being run over an existing installation without affect.
The caveat here being the cluster configurations themselves, pushed by the
playbook.

The various install scripts provided are to run portions of the install playbook
via Ansible tags:

|    Script/Command      |    Tag     |        Asset             |
| ---------------------- | ---------- | ------------------------ |
| *tdh-install.sh*       |  All Tags  | *TDH.tar.gz* (and all other assets) |
| *tdh-mgr-update.sh*    | tdh-mgr    | *tdh-mgr.tar.gz*         |
| *tdh-config-update.sh* | tdh-conf   |*tdh-cluster-conf.tar.gz* |
| *tdh-python-update.sh* | tdh-python | *tdh-anaconda3.tar.gz*   |

Note that running the install playbook with no files would result in running
through just the prerequisites, which in of itself can be handy for host
bootstrapping.


## Starting TDH

Once a full TDH install has run, the final step is to run the post-install playbook.
This is a one-time operation that performs some HDFS directory seeding needed for
the cluster to be fully operational. (eg. hive warehouse directory and permissions,
log directories, hdfs tmp and user paths, etc.).  To perform these steps, however,
the cluster should first be started via tdh-mgr. If the Ansible steps all worked
and the cluster configuration deployed, start HDFS via `hadoop-init.sh start`
command and then run the post-install step.


## Post-Install:

Run the post-install playbook once HDFS is operational.
```
$ source ~/.bashrc
$ ansible-playbook -i inventory/$GCP_ENV/hosts tdh-postinstall.yml
```

Start the remaining ecosystem: `tdh-init.sh start`
