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

### Examples:

Create two master nodes, first with a test run:
```
./bin/tdh-masters-init.sh -t 'n1-standard-2' test m01 m02
./bin/tdh-masters-init.sh -t 'n1-standard-2' run m01 m02
```

Create three worker nodes, with 256G boot drive as SSD.
```
./bin/tdh-workers-init.sh -b 256GB -S run
```

## GCP Machine-Types:

### Small
- Master/Util   :  n1-standard-2  :  2 vCPU and 7.5 Gb
   or              n1-standard-4  :  4 vCPU and 15 Gb  : DEFAULT
- Worker/Data   :  n1-highmem-4   :  4 vCPU and 26 Gb
   or              n1-highmem-8   :  8 vCPU and 52 Gb  : DEFAULT

### Medium
- Master/Util   :  n1-highmem-8   :  8 vCPU and 52 Gb
- Worker/Data   :  n1-highmem-16  :  16 vCPU and 104 Gb
