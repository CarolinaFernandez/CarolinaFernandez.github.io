---
layout: post
title:  "Bulk remove LXC instances"
description: "Quickly removing a subset of LXC instances"
date:   2018-04-18 20:35:18
categories: deployment
tags: [unix, centos]
comments: true
---

* TOC
{:toc}

Linux Containers (LXC) provide tools to operate on individual containers., as any other sort of (let's put it this way) "virtualised processing environments", bind their interfaces to other interfaces in the hosting server; so that traffic between the virtual environment and its host is allowed. This procedure is typically automated by the hypervisor or any other set of automated scripts. In this case, detecting and removing any leftover is needed.

<!--more-->

### Problem

Linux Containers (LXC) provide tools to operate on individual containers. However, no straightforward method seems to be available to quickly remove a subset of them.

```
# lxc-destroy *
lxc-destroy: missing container name, use --name option
# lxc-destroy --name *
Container is not defined
```

### Solution

Simple bash scripting and iterating on them is enough. There is just a caveat: if trying to use the listing command (<code>lxc-ls</code>, for CentOS); it will not directly work.

Instead, you may just as well use the directories storing the container data; as these share name. Not that you need to slightly adapt commands for a non-CentOS system.

```bash
#!/bin/bash

# Define the prefix you want to filter (e.g., OpenStack-Ansible/All-in-One uses "aio" as a prefix for every of its LXCs)
container_prefix=""

LXC_CFG="/var/lib/lxc/${container_prefix}*"

for f in $LXC_CFG
do
  container=$(basename $f)
  lxc-stop --name $container
  lxc-destroy --name $container
done
```

Further outputs of <code>lxc-ls</code> should render no more the "filtered" LXC instances.
