TDH-GCP
=========
Timothy C. Arland <tcarland@gmail.com>

## Overview

A framework for building compute instances and deploying the TDH distribution
of Hadoop.

The compute instances are managed by a set of scripts for initializing the
master and worker node instances. The scripts wrap the Google Cloud API via
the *gcloud* CLI tool and accordingly, the Google Cloud SDK should be installed
for creating GCP-based instances, though GCP is not a strict requirement for
the bootstrapping scripts provided. 

Ansible playbooks are used for installing or upgrading a TDH cluster. 
Refer to the `README.md` located in *./ansible*. The playbooks
are idempotent and are *not* GCP specific.

## Configuration

The `tdh-gcp-env.sh` script provides the configuration and defaults for
the various *instance* scripts and some *utility* scripts as well. The 
scripts rely on relative directory to locate the configuration, so the 
tools are intended to be run from the root project directory.


## Instance scripts:

- **gcp-compute.sh**:

  This is the base script for creating or managing a GCP Compute Instance. It
  will create an instance and optionally attach data disks to the instance as
  well as stopping, deleting, or checking an instance. It is used by the
  *tdh-instance-init* script for creating GCP instances.

- **tdh-instance-init.sh**:

  Wraps `gcp-compute.sh` with defaults for initializing TDH master/worker hosts.
  Ansible is then used to deploy and configure the cluster. The first master 
  is commonly used as the primary management node for running Ansible. The
  the script will use the `master_id` file as the Ansible Server SSH public key.
  The first host's key is generated and used as the master if none is provided.

- **gke-init.sh**:

  Script for initializing a Google Kubernetes Cluster (GKE) including options 
  for creating a GKE *Private* Cluster.


## Utility Scripts 

Additional support scripts used for various environment bootstrapping.

- **gcp-networks.sh**:

  Provides a wrapper for creating custom GCP Networks and Subnets. If not
  specified, GCP will revert to using the `default` network and subnet. If the
  intention is to deploy on a specific network, this script is first run to
  define the subnet and associated address range in CIDR Format.

- **gcp-fw-ingress.sh**:

  Convenience script for adding ingress fw rules.

- **tdh-remote-format.sh**:

  The GCP instance scripts format attached drives at create, however
  for situations where the instances are not created by those scripts, 
  this script will format and mount a sequential set of attached 
  storage via ssh.


## Support scripts:

Support scripts are utilized by the initialization scripts in some cases, 
but are not GCP specific and can be used for any environment where compute
instances have already been created.

- **tdh-push.sh**:

  A script for pushing a directory of assets to a host. The script will
  automatically archive a directory, ensuring the directory to be archived
  remains as the root directory and any soft links within are honored. It
  creates a tarball to be transferred to a given host.

  The environment variable TDH_PUSH_HOST is used as the default target host
  when not provided directly to the script. In the context of TDH, this script
  is used to push updates, such as this repository (tdh-gcp), TDH Manager
  (tdh-mgr), cluster configs from `tdh-config`, and a python3 distribution.
  The script also uses a common distribution path for pushing files. By
  default, this is set to `/tmp/dist`, but can be changed by setting
  TDH_DIST_PATH in the environment.
  ```
  $ export TDH_PUSH_HOST="tdh-m01"
  $ ./bin/tdh-push.sh -G .
    => result: gcloud compute scp tdh-gcp.tar.gz tdh-m01:tmp/dist/
  $ ./bin/gcp-push.sh -G ../tdh-mgr
    => result: gcloud compute scp tdh-mgr.tar.gz tdh-m01:tmp/dist/
  $ ./bin/gcp-push.sh -G ../tdh-config/gcpwest1 tdh-cluster-conf
    => result: gcloud compute scp tdh-cluster-conf.tar.gz tdh-m01:tmp/dist/
  $ ./bin/gcp-push.sh -G /opt/python/anaconda3 tdh-anaconda3
    => result: gcloud compute scp tdh-anaconda3.tar.gz tdh-m01:tmp/dist/
  ```
- **tdh-prereqs.sh**:

  Installs host prerequisites that may be needed prior to Ansible (eg. wget,
  bind-tools). Note this is not set executable intentionally until it is
  to be ran on a target host.

- **tdh-format.sh**:

  Script for formatting and mounting a new data drive for a given instance. This
  is used by the master/worker init scripts for attached data drives.
  The master and worker init scripts copy this to the remote host to locally
  format and add the drive(s) to the system, supporting either Ext4 or XFS
  filesystems. This is *not* set executable until placed on the host in question.

- **ssh-hostkey-provision.sh**:

  Script for remotely configuring a cluster of hosts for passwordless login
  via a selected bastion host.

- **gcp-hosts-gen.sh**:

  Script for building a hosts file of GCP Instances.

<br>

---

<br>

## Running the TDH instance script:

The scripts rely on relative path to each other and should be run from
the parent `tdh-gcp` directory. Below are some examples of creating master
and worker nodes.


- Create three master nodes, first with a test run, using the default network:
  ```
  ./bin/tdh-instance-init.sh -t 'n1-standard-2' test m01 m02 m03
  ./bin/tdh-instance-init.sh -t 'n1-standard-4' run m01 m02 m03
  ```

  Note the creation of the file `./ansible/.ansible/master-id_rsa.pub` which 
  is the public key for the first master created, *tdh-m01* in the above example.
  Be aware that this file is not removed or cleaned up between runs.

- Create four worker nodes, with 256G boot drive as SSD and default machine-type.
  ```
  ./bin/tdh-instance-init.sh -b 256GB -S run d01 d02 d03 d04
  ```

- This example first creates a new GCP Network and Subnet for the cluster,
  attaches a data disk formatted as XFS instead of Ext4.
  ```
  ./bin/gcp-networks.sh --addr 172.16.200.0/24 create tdh-net tdh-subnet-200

  ./bin/tdh-instance-init.sh --network tdh-net --subnet tdh-subnet-200 \
    --tags tdh --type n1-standard-4 run m01 m02 m03

  ./bin/tdh-instance-init.sh --network tdh-net --subnet tdh-subnet-200 \
    --tags tdh --type n1-highmem-4 --attach --disknum 4 --disksize 256GB \
    --use-xfs run d01 d02 d03 d04
  ```

## Creating GKE clusters

Creating a private GKE cluster requires an existing VPC Network and Subnet.
A private cluster is designated at create by providing a set of IP Addresses
allowed to reach the public endpoint dynamically created by GKE. The 
*gke-init.sh* script defines this private filter list via the `-P` or `--private` 
option.

Example:
```sh
./bin/gcp-networks.sh -a 10.10.64.0/23 create tdhnet tdhc1
./bin/gke-init -A -N tdhnet -n tdhc1 -c 8 -P '73.26.197.175/32' create tdhc
```

<br>

---

<br>

## Environment Variables

 Most of the various scripts support overriding defaults via the command-line
or by environment variable.  Some defaults, such as GCP region and zone are
taken from the active GCloud API configuration. Note that options provided at
script run-time take precedence over environment variables.

The order of precedence is:   `default < env-var < cmd-line`.

| Environment Variable |  Description  |
| -------------------- | ------------- |
| `GCP_REGION`         | Override the default region, most scripts (except networks) rely on the zone only.
| `GCP_ZONE`           | Override the default zone (set in gcloud api).
| `GCP_MACHINE_TYPE`   | Provided via the `--type` cmdline parameter, it can alternatively be provided by the environment.
| `GCP_MACHINE_IMAGE`  | Override the default machine image of `ubuntu-minimal-2204-lts`.
| `GCP_IMAGE_PROJECT`  | Override the default Image Project of `ubuntu-cloud`.
| `GCP_NETWORK`        | The network to use for create operations.
| `GCP_SUBNET`         | The Network Subnet to use for create operations.
| `TDH_PUSH_HOST`      | Host to use for push operations used by *tdh-push.sh*.
| `TDH_DIST_PATH`      | The distribution path for binary packages. Utilized by *tdh-push.sh*.
| `TDH_PREREQS`        | List of package prerequistes to be installed.


<br>

---

<br>

## Resource considerations:

All of this varies on data sizes and workloads and is intended purely as 
an example or starting point.

Ideal Memory values for a not too small, usable cluster:
- NN/SN = 4 Gb ea.
- DN/NM (worker) = 1 Gb ea
- Hive Meta|S2  = 12 Gb ea
- Zookeeper  = 1 Gb
- Hbase Master = 4 Gb
- HBase RegionServers = 4 to 20 Gb depending


### Small dev layout with minimal values:

**Master 01**:

|     Component          |  HeapSize   | Cores |
| ---------------------- | ----------- | ----- |
|  NameNode (primary)    |  2 Gb       |  1    |
|  ResourceManager       |  2 Gb       |  1    |
|  HBase Master          |  2 Gb       |  1    |
|  Zookeeper             |  1 Gb       |  1    |
|  JournalNode           |  1 Gb       |  1    |
|  **Total**             |  **8Gb**    | **5** |

<br>

**Master 02**:

|     Component           |  HeapSize   | Cores |
| ----------------------- | ----------- | ----- |
|  NameNode (secondary)   |  2 Gb       |  1    |
|  ResourceManager        |  2 Gb       |  1    |
|  Zookeeper              |  1 Gb       |  1    |
|  JournalNode            |  1 Gb       |  1    |
|  **Total**              |  **6Gb**    | **4** |

<br>

**Master 03**:

|     Component           |  HeapSize   | Cores |
| ----------------------- | ----------- | ----- |
|  Hive Metastore         |  2 Gb       |   1   |
|  Hive Server2           |  2 Gb       |   1   |
|  Spark HistoryServer    |  1 Gb       |   1   |
|  Zookeeper              |  1 Gb       |   1   |
|  JournalNode            |  1 Gb       |   1   |
|  **Total**              |  **7Gb**    | **5** |

<br>

---

<br>

## GCP Machine-Types:

|    Role       |  Machine Type   |  vCPU and Memory   |
| ------------- | --------------- | ------------------ |
| Master/Util   |  n1-standard-1  |  1 vCPU and 3.7 Gb |  
| Master/Util   |  n1-standard-2  |  2 vCPU and 7.5 Gb | 
| Master/Util   |  n1-standard-4  |  4 vCPU and 15 Gb  |
| Master/Util   |  n1-highmem-4   |  4 vCPU and 26 Gb  |
| ------------- | --------------- | ------------------ |
| Worker/Data   |  n1-standard-8  |  8 vCPU and 30 Gb  |
| Worker/Data   |  n1-highmem-8   |  8 vCPU and 52 Gb  |
| Worker/Data   |  n1-highmem-16  | 16 vCPU and 104 Gb |
| Worker/Data   |  n1-highmem-32  | 32 vCPU and 208 Gb |

A complete list can be dumped by passing `--list-machine-types` 
to *gcp-compute.sh*.

<br>

## Changing GCP Machine Type:
- Shut down the instance first.
  ```
  $ gcp-compute.sh stop tdh-d01
  ```

- Set the new instance machine-type and restart
  ```
  $ gcloud compute instances set-machine-type tdh-d01 \
    --machine-type n1-highmem-16
  $ gcp-compute.sh start tdh-d01
  ```
