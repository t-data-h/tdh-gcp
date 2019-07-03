TDH-GCP Scripts
===============

Scripts for building compute instances.

tdh-gcp-compute.sh:  
  Script for creating a new GCP Compute Instance. Will create an instance
and optionally attach a data disk to the instance.

tdh-gcp-format.sh:  
  Script for formatting and mounting a new data drive for a given instance.

tdh-mysql-install.sh:  
  Bootstraps a Mysql 5.7 Server for an instance.

tdh-prereqs.sh:
  Install host prerequisites

tdh-masters-init.sh:
    Wraps above scripts with defaults regarding initializing master hosts

tdh-workers-init.sh:
    Builds GCP worker nodes for TDH Environment.



## GCP Machine-Types:

### Small
- Master/Util   :  n1-standard-2  :  2 vCPU and 7.5 Gb
   or              n1-standard-4  :  4 vCPU and 15 Gb
- Worker/Data   :  n1-highmem-4   :  4 vCPU and 26 Gb
   or              n1-highmem-8   :  8 vCPU and 52 Gb

### Medium
- Master/Util   :  n1-highmem-8   :  8 vCPU and 52 Gb
- Worker/Data   :  n1-highmem-16  :  16 vCPU and 104 Gb
