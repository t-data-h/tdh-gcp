TDH-GCP 
=========

A Framework for building GCP compute instances and deploying TDH.

The compute instances are managed by a set of scripts for building the master 
and worker node instances. Ansible is used for installing or updating/upgrading 
the TDH cluster.

### Instance initialization scripts:

- tdh-gcp-compute.sh:
  
  This is the base script for creating a new GCP Compute Instance. It Will 
create an instance and optionally attach data disks to the instance. It is 
used by the master and worker init script for creating the custom instances.

- tdh-masters-init.sh:
  
  Wraps *tdh-gcp-copmpute.sh* with defaults for initializing master hosts.
This will bootstrap master hosts with mysqld and ansible as we use ansible
from the master host(s) to manage and deploy the cluster. The first master 
is considered as the primary management node where Ansible is run from.

- tdh-workers-init.sh:  
  
  Builds TDH worker nodes in GCP similarly to the masters init, but generally 
 of a different machine type.


### Support scripts:

- tdh-gcp-format.sh: 
  
  Script for formatting and mounting a new data drive for a given instance.

- tdh-mysql-install.sh: 
  
  Bootstraps a Mysql 5.7 Server for an instance.

- tdh-prereqs.sh:
  
  Installs host prerequisites that may be needed prior to ansible bootstrapping.


## Ansible:

Deploying TDH comes down to three steps. 
1) Distribute Assets 
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
nodes of the cluster to a temporary drop path for use by the install.

### Install:

 The second step is to run the install playbook *tdh-install.yml*. This will run through all prerequisites and install/update the TDH Enviornment depending on 
 what 'dropfiles' exist in the 'droppath'.

### Post-Install

The last step is to be run after the successful completion of step 2 and the cluster is up and operational. It mostly performs some HDFS directory seeding 
needed for the cluster to be fully operational. (hive warehouse and permissions, log directories for aggregateion, etc.)

## GCP Machine-Types:

### Small
- Master/Util   :  n1-standard-2  :  2 vCPU and 7.5 Gb
   or              n1-standard-4  :  4 vCPU and 15 Gb  : DEFAULT
- Worker/Data   :  n1-highmem-4   :  4 vCPU and 26 Gb
   or              n1-highmem-8   :  8 vCPU and 52 Gb  : DEFAULT

### Medium
- Master/Util   :  n1-highmem-8   :  8 vCPU and 52 Gb
- Worker/Data   :  n1-highmem-16  :  16 vCPU and 104 Gb
