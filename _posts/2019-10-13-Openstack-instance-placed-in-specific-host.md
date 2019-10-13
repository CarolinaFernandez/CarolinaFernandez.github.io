---
layout: post
title:  "OpenStack instance placed in specific host"
description: "Create an instance in OpenStack in a specific availability zone and host"
date:   2019-10-13 20:12:37
categories: deployment
tags: [openstack, cloud]
comments: true
---

* TOC
{:toc}

When using OpenStack, the *nova-scheduler* service is the one picking the specific host where a new VM (or instance) will be deployed.

Yet, sometimes you do not want this to happen. Maybe a specific host in your availability zone and/or cluster is configured in such a way that you would still prefer to have the new instance running there -- even at the cost of over-provisioning.

<!--more-->

### The basics

OpenStack's *nova-scheduler* decides internally where a new server instance will be placed based on [multiple factors](https://docs.openstack.org/nova/latest/admin/availability-zones.html#using-availability-zones-to-select-hosts) (few of them being the classical amount of RAM, CPU and disk).

All of that also has into account a large amount of filters that can be properly enabled or defined; for instance, to "hint" that a specific host should not be used or on the other hand, to suggest that a set of instances should all be deployed in the same host or to filter by availability zone; among many others.

Thus, if you have three physical hosts and two of them are full, it seems highly likely that a new instance will be deployed in that third host. However, if this host is excluded from the list, the result will vary.

### Define specific location during server creation

The easiest way I went for is the one where the command to create the instance also includes the specific host to place this new instance.

Whilst this is documented in the [OpenStack's nova guide](https://docs.openstack.org/nova/latest/admin/availability-zones.html#using-availability-zones-to-select-hosts), you can find here a quick example to adapt. **Note** that this is based on the *Mitaka* version. As you can see from the Nova guide, the basic syntax can follow any of the options below:

```bash
openstack server create --availability-zone $ZONE ... $SERVER_ID
openstack server create --availability-zone $ZONE:$HOST ... $SERVER_ID
openstack server create --availability-zone $ZONE::$NODE ... $SERVER_ID

```

#### Finding the zone, the host and the node

The following command can be run to easily get the "zone" and the "host". It is more interesting than the `openstack availability zone list` command since that one just provides the "zone".

```bash
$ openstack host list
+-------------------------------------------+-------------+----------+
| Host Name                                 | Service     | Zone     |
+-------------------------------------------+-------------+----------+
| server2-nova-conductor-container-76cf50fd | conductor   | internal |
| server0-nova-conductor-container-64a4948b | conductor   | internal |
| server1-nova-conductor-container-a302505e | conductor   | internal |
| server2-nova-scheduler-container-8145a5da | scheduler   | internal |
| server0-nova-scheduler-container-e68205ad | scheduler   | internal |
| server1-nova-scheduler-container-993a8796 | scheduler   | internal |
| server1-nova-console-container-d4a3c746   | consoleauth | internal |
| server0-nova-console-container-6647cc1a   | consoleauth | internal |
| server2-nova-console-container-f6a024bf   | consoleauth | internal |
| server1                                   | compute     | nova     |
| server2                                   | compute     | nova     |
| server3                                   | compute     | nova     |
+-------------------------------------------+-------------+----------+
```

In this example, we have three servers (1, 2, 3) with the "compute" service. Any of these can be chosen for the placement of a new server (or VM instance).

#### Creating the instance with the specific location

Assuming you want to deploy the instance in "server3" (under the "nova" availability zone), the command would be as follows:

```bash
openstack server create --flavor=ec1b56f0-4df3-43c2-9663-833a3fad909c --image=aacb59b3-a029-41d5-a79a-35e87db68f22 --security-group=55665ae6-5fe4-4118-a473-4c0457fcfc2c --key-name=test1 --availability-zone=nova:server3 --nic net-id=1fef4ecc-da6b-4db1-9271-89486adf2b91 --nic net-id=00d1e117-2579-4818-938e-b3cbc6dda086 --user-data=/home/test/vm-test1_cloud-init.txt vm-test1
```

### Other approaches

As introduced above, there are different options to force this deployment on the desired host.

#### Disabling specific hosts

As explained in [this thread](https://ask.openstack.org/en/question/1104/how-do-i-disable-a-nova-compute-node/), it should also be theoretically possible to disable the host(s) you would not wish to deploy to by using the following:

```bash
nova service-disable <host_name> nova-compute
```

This approach did not work for me, but again; I have not access to the Nova configuration to investigate why that would be overridden by any other setting.

#### Migrating from another host

The option of migrating a server instance from a source compute node to another is as well another theoretical option. Again, I tried this but the process seemed stuck and I had no access to the logs for further investigation.

If you want to try it, check the [documentation](https://docs.openstack.org/nova/latest/admin/live-migration-usage.html) and try this command:

```bash
openstack server migrate $SERVER_ID --live $HOST_NAME
```
