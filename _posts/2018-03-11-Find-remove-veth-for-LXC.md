---
layout: post
title:  "Find and remove veth's used for LXC"
description: "Find and remove virtual interfaces used for Linux containers"
date:   2018-03-11 18:52:04
categories: deployment
tags: [ansible, openstack, networking]
comments: true
---

* TOC
{:toc}

Linux Containers (LXC), as any other sort of (let's put it this way) "virtualised processing environments", bind their interfaces to other interfaces in the hosting server; so that traffic between the virtual environment and its host is allowed. This procedure is typically automated by the hypervisor or any other set of automated scripts. In this case, detecting and removing any leftover is needed.

<!--more-->

### Problem

At some stage, a previously defined pair of virtual interfaces conflicts with the operation of creating a new LXC instance.

This is the case of some automated scripts such as [OpenStack Ansible](https://github.com/openstack/openstack-ansible); where an initial run may fail and do not rollback afterwards. This leaves the system in a different status to the initial one and makes it necessary to manually undo the related configuration steps.

In this example, a second run of the OpenStack-Ansible scripts lead to a failure because of a previous definition of some network interfaces.

```
# lxc-start --name aio1_cinder_api_container-b78dc1c8 --foreground
lxc-start: network.c: instantiate_veth: 130 Failed to create veth pair "b78dc1c8_eth0" and "vethBMO7RR": File exists
                                                                                                                    lxc-start: network.c: lxc_create_network_priv: 2374 Failed to create network device
              lxc-start: start.c: lxc_spawn: 1271 Failed to create the network.
                                                                               lxc-start: start.c: __lxc_start: 1530 Failed to spawn container "aio1_cinder_api_container-b78dc1c8".
                                                                                                                                                                                    lxc-start: tools/lxc_start.c: main: 368 The container failed to start.
lxc-start: tools/lxc_start.c: main: 372 Additional information can be obtained by setting the --logfile and --logpriority options.
```

### Solution

Here, the interfaces were automatically defined and configured by `OpenStack-Ansible` and placed in configuration of each LXC instance (and its interfaces).

To avoid the failure in future runs, identify all the previously created interfaces (now producing failures) and remove them.
Note that this step can be cumbersome; so it is quicker to run the following script rather tan manually removing all related links.

#### For every LXC

The automated approach (recommended for this deployment, as 40+ interfaces are defined). This script iterates over each interface attached to any LXC instance (defined as `lxc.network.veth.pair = ` in the "config" file of each LXC); then deletes it from the network configuration.

```bash
#!/bin/bash

# Define the prefix you want to filter (e.g., OpenStack-Ansible/All-in-One uses "aio" as a prefix for every of its LXCs)
container_prefix=""

LXC_CFG="/var/lib/lxc/${container_prefix}*"

for IFNAME in $(grep "lxc\.network\.veth\.pair = " ${LXC_CFG}/config -R | awk 'match($0, /b(:?.*):lxc\.network\.veth\.pair = (.*)/) {print $3}'); do
  echo "$IFNAME"
  ip link delete $IFNAME
done
```

#### Per LXC

The manual way. Identify every LXC, check its interfaces against the network configuration (interfaces and bridges) and remove these.

First, identify every LXC instance affected.

```
# ll /var/lib/lxc/
...
drwxr-xr-x. 3 root root 4096 Mar 11 13:44 aio1_cinder_api_container-b78dc1c8
...
```

Check its configuration: generic (`config`) and per-interface (`eno{X}`).

```
# ls -lah /var/lib/lxc/aio1_cinder_api_container-b78dc1c8
...
-rw-r--r--.  1 root root 1443 Mar 11 13:25 config
...
-rw-r--r--.  1 root root  601 Mar 11 13:24 eno1.ini
-rw-r--r--.  1 root root  604 Mar 11 13:24 eno2.ini
...

# cat /var/lib/lxc/aio1_cinder_api_container-b78dc1c8/config
...
# Network configuration
lxc.network.type = veth
lxc.network.name = eth0
lxc.network.veth.pair = b78dc1c8_eth0
lxc.network.link = lxcbr0
...

# cat /var/lib/lxc/aio1_cinder_api_container-b78dc1c8/eno1.ini 
...
# Create a veth pair within the container
lxc.network.type = veth
# Network device within the container
lxc.network.name = eno1
# Name the veth after the container
# NOTE(major): The lxc.network.veth.pair line must appear right after
# lxc.network.name or it will be ignored.
lxc.network.veth.pair = b78dc1c8_eno1
# Host link to attach to, this should be a bridge if lxc.network.type = veth
lxc.network.link = br-mgmt
...

# cat /var/lib/lxc/aio1_cinder_api_container-b78dc1c8/eno2.ini 
# Create a veth pair within the container
lxc.network.type = veth
# Network device within the container
lxc.network.name = eno2
# Name the veth after the container
# NOTE(major): The lxc.network.veth.pair line must appear right after
# lxc.network.name or it will be ignored.
lxc.network.veth.pair = b78dc1c8_eno2
# Host link to attach to, this should be a bridge if lxc.network.type = veth
lxc.network.link = br-storage
...
```

Check against the virtual interfaces and bridges in the system. These can be found through multiple commands:

* network configuration (`ip a s`)
* bridge info (`brctl show`)
* `/proc/net/dev` file
* configuration of each LXC (`/var/lib/lxc/${container_name}/config`)

```
# ip a s
...
109: vethBMO7RR@b78dc1c8_eth0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN qlen 1000
    link/ether 9e:ad:ab:2e:f3:8f brd ff:ff:ff:ff:ff:ff
110: b78dc1c8_eth0@vethBMO7RR: <NO-CARRIER,BROADCAST,MULTICAST,UP,M-DOWN> mtu 1500 qdisc noqueue master lxcbr0 state LOWERLAYERDOWN qlen 1000
    link/ether fe:df:b0:e3:a5:2e brd ff:ff:ff:ff:ff:ff
...
```

```
# brctl show
bridge name	bridge id		STP enabled	interfaces
lxcbr0		8000.feeec5451826	no		b78dc1c8_eth0
```

---

After running this command, no bridges or virtual interfaces (associated to the previously failing LXCs) should exist.

```
# brctl show
bridge name	bridge id		STP enabled	interfaces
br-mgmt		8000.000000000000	no		
br-storage		8000.000000000000	no		
lxcbr0		8000.000000000000	no
```

Try once more to start the container. It should succeed now:

```
# lxc-start --name aio1_cinder_api_container-b78dc1c8 --foreground
systemd 219 running in system mode. (+PAM +AUDIT +SELINUX +IMA -APPARMOR +SMACK +SYSVINIT +UTMP +LIBCRYPTSETUP +GCRYPT +GNUTLS +ACL +XZ -LZ4 -SECCOMP +BLKID +ELFUTILS +KMOD +IDN)
Detected virtualization lxc.
Detected architecture x86-64.

Welcome to CentOS Linux 7 (Core)!

Failed to install release agent, ignoring: No such file or directory
Running in a container, ignoring fstab device entry for /dev/root.
Cannot add dependency job for unit display-manager.service, ignoring: Unit not found.
[  OK  ] Created slice Root Slice.
...
```

The network configuration is also correct now: the pair of virtual interfaces is created and bridges are attached to each interface of the LXC's instance:

```
# ip a s
...
392: b78dc1c8_eth0@if391: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master lxcbr0 state UP qlen 1000
    link/ether fe:78:f5:46:3b:5a brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::fc78:f5ff:fe46:3b5a/64 scope link 
       valid_lft forever preferred_lft forever
394: b78dc1c8_eno1@if393: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-mgmt state UP qlen 1000
    link/ether fe:b8:30:90:41:66 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::fcb8:30ff:fe90:4166/64 scope link 
       valid_lft forever preferred_lft forever
396: b78dc1c8_eno2@if395: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-storage state UP qlen 1000
    link/ether fe:8f:f0:6d:62:7c brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::fc8f:f0ff:fe6d:627c/64 scope link 
       valid_lft forever preferred_lft forever

# brctl show
bridge name	bridge id		STP enabled	interfaces
br-mgmt		8000.feb830904166	no		b78dc1c8_eno1
br-storage		8000.fe8ff06d627c	no		b78dc1c8_eno2
lxcbr0		8000.fe78f5463b5a	no		b78dc1c8_eth0
```
