TDH-GCP
=========
Timothy C. Arland  ( tcarland@gmail.com  |  tarland@trace3.com  )

## Overview

A framework for building compute instances and deploying the TDH distribution
of Hadoop.

The compute instances are managed by a set of scripts for initializing the
master and worker node instances. The scripts wrap the Google Cloud API via
the *gcloud* CLI tool and accordingly, the Google Cloud SDK should be installed
for creating GCP-based instances, though GCP is not a strict requirement for
some of the bootstrapping scripts provided.

Ansible playbooks are used for installing or updating/upgrading a TDH
cluster. The playbook is currently OS focused on RHEL or CentOS flavors
of Linux. Refer to the `README.md` located in *./ansible*. The playbooks
are idempotent and are also not GCP specific.


## Instance scripts:

* gcp-compute.sh:

  This is the base script for creating or managing a GCP Compute Instance. It
  will create an instance and optionally attach data disks to the instance as
  well as stopping, deleting, or checking an instance. It is used by the
  tdh master and worker init scripts for creating GCP instances.

* tdh-masters-init.sh:

  Wraps `gcp-copmpute.sh` with defaults for initializing TDH master hosts.
  This will also bootstrap master hosts with Mysqld. Ansible is then used to
  deploy and configure the cluster. The first master is commonly used as the
  primary management node for running Ansible.

* tdh-workers-init.sh:  

  Builds TDH worker nodes in similarly to the masters init, but generally
  of a different machine type. Installs a few prerequisites such as the
  mysql client library and tools like `wget` that may be needed prior to
  Ansible bootstrapping.

* gke-init.sh:

  Script for initializing a GCP Kubernetes Cluster


## Utility Scripts:

Additional support scripts used for various environment bootstrapping.

* gcp-networks.sh:

  Provides a wrapper for creating custom GCP Networks and Subnets. If not specified,
  GCP will revert to using the `default` network and subnet. If the intention is to
  deploy on a specific network, this script is first run to define the subnet and
  associated address range in CIDR Format.

* tdh-mysql-install.sh:

  Bootstraps a Mysql 5.7 Server instance (on given master hosts). It takes
  care of an initial install of mysql server and client, setting the root password
  as well as ensuring `server-id` is set in accordance to the number of masters.
  Actual slave configuration and accounts are provisioned later by Ansible
  playbooks.

* tdh-push.sh

  A simple script for pushing a directory of assets to a host. The script will
  automatically archive a directory, ensuring the directory to be archived
  remains as the root directory and any soft links within are honored. It
  creates a tarball to be transferred to a given host.

  The environment variable TDH_PUSH_HOST is used as the default target host when
  not provided directly to the script. In the context of TDH, this script is used
  to push updates, such as this repository (tdh-gcp), TDH Manager (tdh-mgr),
  cluster configs from `tdh-config`, and a python3 distribution. The script
  also uses a common distribution path for pushing files. By default, this is
  set to `/tmp/dist`, but can be changed by setting TDH_DIST_PATH in the
  environment.
  ```
  $ export TDH_PUSH_HOST="tdh-m01"
  $ ./bin/tdh-push.sh -G .
    => result: gcloud compute scp tdh-gcp.tar.gz tdh-m01:tmp/dist/
  $ ./bin/gcp-push.sh -G ../tdh-mgr
    => result: gcloud compute scp tdh-mgr.tar.gz tdh-m01:tmp/dist/
  $ ./bin/gcp-push.sh -G ../tdh-config/gcpwest1 tdh-conf
    => result: gcloud compute scp tdh-conf.tar.gz tdh-m01:tmp/dist/
  $ ./bin/gcp-push.sh -G /opt/python/anaconda3 tdh-anaconda3
    => result: gcloud compute scp tdh-anaconda3.tar.gz tdh-m01:tmp/dist/
  ```

* tdh-remote-format.sh:

  The GCP instance scripts already format attached drives at create, however
  for situations where the instances are not created by those scripts (like
  non-GCP hosts), this script will format and mount a sequential set of
  attached storage via ssh. This makes use of the format support script.

* tdh-ssh-provision.sh:

  Script for remotely configuring a cluster of hosts for passwordless login
  via a master host.

## Support scripts:

Support scripts are utilized by the initialization scripts in some cases, but
are not GCP specific and can be used for any environment where the compute
instances have already been created.

* tdh-prereqs.sh:

  Installs host prerequisites that may be needed prior to Ansible (eg. wget,
  bind-tools). Note this is not set executable intentionally until it is
  to be ran on a target host to avoid running this accidentally.

* tdh-format.sh:

  Script for formatting and mounting a new data drive for a given instance. This
  is used by the master/worker init scripts when using an attached data drive.
  The Init scripts copy this to the remote host to locally format and add the
  drive(s) to the system, supporting either Ext4 or XFS filesystems. This is
  not set executable until placed on the host in question.

* gcp-hosts-gen.sh

  Script for building a hosts file of GCP Instances.

* gfw-ssh.sh:

  Handy script for easily adding ssh only access for remote networks.

---

## Running the instance scripts:

The scripts rely on relative path to each other and should be run from
the parent `tdh-gcp` directory. Below are some examples of creating master
and worker nodes.


Create three master nodes, first with a test run, using the default network:
```
./bin/tdh-masters-init.sh -t 'n1-standard-2' test m01 m02 m03
./bin/tdh-masters-init.sh -t 'n1-standard-4' run m01 m02 m03
```

Create four worker nodes, with 256G boot drive as SSD and default machine-type.
```
./bin/tdh-workers-init.sh -b 256GB -S run d01 d02 d03 d04
```

This example first creates a new GCP Network and Subnet for the cluster,
attaches a data disk formatted as XFS instead of Ext4.
```
./bin/gcp-networks.sh --addr 172.16.200.0/24 create tdh-net tdh-subnet-200

./bin/tdh-masters-init.sh --network tdh-net --subnet tdh-subnet-200 \
  --pwfile mysqlpw.txt --tags tdh --type n1-standard-4 \
  run m01 m02 m03

./bin/tdh-workers-init.sh --network tdh-net --subnet tdh-subnet-200 \
  --tags tdh --type n1-highmem-4 --attach --disksize 256GB --use-xfs \
  run d01 d02 d03 d04


```

---

## Resource considerations:

All of this varies, of course, on data sizes and workloads and is
intended purely as a starting point.

Memory values for a small, usable cluster:
*  NN/SN = 4 Gb ea.
*  DN/NM (worker) = 1 Gb ea
*  Hive Meta|S2  = 12 Gb ea
*  Hbase Master = 4 Gb
*  Zookeeper  = 1 Gb
*  HBase RegionServers = 8 to 20 Gb depending

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

---

## GCP Machine-Types:

|    Role       |  Machine Type   |  vCPU and Memory   |
| ------------- | --------------- | ------------------ |
| Master/Util   |  n1-standard-2  |  2 vCPU and 7.5 Gb |  VERY SMALL
| Worker/Data   |  n1-standard-4  |  4 vCPU and 15 Gb  |
| Worker/Data   |  n1-standard-8  |  8 vCPU and 30 Gb  |
| ------------- | --------------- | ------------------ |
| Master/Util   |  n1-highmem-8   | 8 vCPU and 52 Gb   |
| Worker/Data   |  n1-highmem-16  | 16 vCPU and 104 Gb |
| Worker/Data   |  n1-highmem-32  | 32 vCPU and 208 Gb |


## Changing GCP Machine Type:
  Shut down the instance first.
```
$ gcloud compute instances set-machine-type tdh-d01 \
  --machine-type n1-highmem-16
```

---

## Environment Variables

 Most of the various scripts support overriding defaults via the command-line
or by environment variable.  Some defaults, such as GCP region and zone are taken
from the active GCloud API configuration. Note that options provided at script
run-time take precedence over environment variables.

 The precedence order is:   `default < env-var < cmd-line`.

| Environment Variable |  Description  |
| -------------------- | ------------- |
| `GCP_REGION`         | Override the default region, generally not needed as most scripts (save for networks) rely on the zone only.
| `GCP_ZONE`           | Override the default zone (set in gcloud api).
| `GCP_MACHINE_TYPE`   | Generally provided via the `--type` cmdline parameter, it can alternatively be provided by the environment.
| `GCP_MACHINE_IMAGE`  | Override the default machine image of `centos-7`.
| `GCP_IMAGE_PROJECT`  | Override the default Image Project of `centos-cloud`.
| `GCP_NETWORK`        | Provide the network to use for create operations. Otherwise needed at the command-line via the `--network` parameter.
| `GCP_SUBNET`         | Provide the Network Subnet to use for create operations. Note this should match the correct network. Same as the command-line parameter `--subnet`.
| `TDH_PUSH_HOST`      | Host to use for push operations used by *tdh-push.sh*.
| `TDH_DIST_PATH`      | The distribution path to drop binary packages. Utilized by *tdh-push.sh*.

### TODO

Add support for GCP Ubuntu images:
--image-family ubuntu-1804-lts --image-project ubuntu-os-cloud
