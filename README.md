TDH-GCP 
=========

A Framework for building GCP compute instances and deploying TDH.

The compute instances are managed by a set of scripts for building the master 
and worker node instances. Ansible is used for installing or updating/upgrading 
the TDH cluster.

### Instance initialization scripts:

* tdh-gcp-compute.sh:
  
  This is the base script for creating a new GCP Compute Instance. It Will 
create an instance and optionally attach data disks to the instance. It is 
used by the master and worker init script for creating the custom instances.

* tdh-masters-init.sh:
  
  Wraps *tdh-gcp-copmpute.sh* with defaults for initializing master hosts.
This will bootstrap master hosts with mysqld and ansible as we use ansible
from the master host(s) to manage and deploy the cluster. The first master 
is considered as the primary management node where Ansible is run from.

* tdh-workers-init.sh:  
  
  Builds TDH worker nodes in GCP similarly to the masters init, but generally 
 of a different machine type.


### Support scripts:

* tdh-gcp-format.sh: 
  
  Script for formatting and mounting a new data drive for a given instance.

* tdh-mysql-install.sh: 
  
  Bootstraps a Mysql 5.7 Server instance.

* tdh-prereqs.sh:
  
  Installs host prerequisites that may be needed prior to ansible.

* gcp-push.sh

   For pushing a directory of assets to a GCP host. The script will automatically 
   archive a directory, ensuring the directory to be archived remains as the root
   directory and links are honored. It creates a tarball to be transferred to a 
   GCP host. The environment variable GCP_PUSH_HOST is used as the default target 
   host when not provided directly. In the context of TDH, this script is used to 
   push updates, such as this repository, TDH Manager (tdh-mgr), and cluster 
   configs from 'tdh-config'. The script also uses a common distribution path for 
   moving the binaries. By default, this is set to *~/tmp/dist*, but can be provided 
   by setting GCP_DIST_PATH in the environment.
   ```
   $ export GCP_PUSH_HOST="tdh-m01"
   $ ./bin/gcp-push.sh .
     => result: gcloud compute scp tdh-gcp.tar.gz tdh-m01:tmp/dist/
   $ ./bin/gcp-push.sh ../tdh-mgr
     => result: gcloud compute scp tdh-mgr.tar.gz tdh-m01:tmp/dist/
   $ ./bin/gcp-push.sh ../tdh-config/gcpwest1 tdh-conf
     => result: gcloud compute scp tdh-conf.tar.gz tdh-m01:tmp/dist/
   $ ./bin/gcp-push.sh /opt/python/anaconda3 tdh-anaconda3
     => result: gcloud compute scp tdh-anaconda3.tar.gz tdh-m01:tmp/dist/
   ```


### Examples:

Create three master nodes, first with a test run:
```
./bin/tdh-masters-init.sh -t 'n1-standard-4' test m01 m02 m03
./bin/tdh-masters-init.sh -t 'n1-standard-4' run m01 m02 m03
```

Create four worker nodes, with 256G boot drive as SSD.
```
./bin/tdh-workers-init.sh -b 256GB -S run d01 d02 d03 d04
```

### Resource considerations:

All of this varies, of course, on data sizes and workloads and 
is intended as a starting point.

Minimum memory values for a production-like cluster:
*  NN/SN = 4 Gb ea.
*  DN/NM (worker) = 1 Gb ea 
*  Hive Meta|S2  = 12 Gb ea
*  Hbase Master = 4 Gb
*  Zookeeper  = 1 Gb
*  HBase RegionServers = 8 to 20 Gb

Possible dev layout:
```
------------------------------------
M01:
* NameNode (primary)  | 2 Gb      1
* ResourceManager     | 2 Gb      1
* HBase Master        | 2 Gb      1
* Zookeeper           | 1 Gb      1
------------------------------------
                        8-12      4
M02:
* NameNode (secondary)  2 Gb      1
* Hive Metastore        4 Gb      1
* Hive Server2          4 Gb      1
* Zookeeper             1 Gb      1
-------------------------------------
                        8-12      4
M03:
* Spark2 HistoryServer  1 Gb      1
* Zookeeper             1 Gb      1
* Hue                   2 Gb      1
* Zeppelin              2 Gb      1
----------------------------------
                        6-8       4
```

## GCP Machine-Types:

|    Role       |  Machine Type   |  vCPU and Memory   |
| ------------- | --------------- | ------------------ |
| Master/Util   |  n1-standard-4  |  4 vCPU and 26 Gb  |
| Worker/Data   |  n1-highmem-8   |  8 vCPU and 52 Gb  |
| ------------- | --------------- | ------------------ |
| Master/Util   |  n1-highmem-8   | 8 vCPU and 52 Gb   |
| Worker/Data   |  n1-highmem-16  | 16 vCPU and 104 Gb |

 
### Changing Machine Type:
```
$ gcloud compute instances set-machine-type tdh-d01 --machine-type n1-highmem-16
$ gcloud compute instances set-machine-type tdh-d02 --machine-type n1-highmem-16
$ gcloud compute instances set-machine-type tdh-d03 --machine-type n1-highmem-16
```

