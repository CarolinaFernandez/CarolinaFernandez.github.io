---
layout: post
title:  "Tunneling and SSH hops"
date:   2017-09-17 20:12:18
categories: deployment
tags: [unix, networks]
comments: true
---

* TOC
{:toc}

This post intends to provide basic guidelines on SSH tunneling (here, local port forwarding), double SSH hop and double or proxied "SCP hop".

<!--more-->

### Local port forwarding

SSH tunneling is a technique to set-up and end-to-end connection between two hosts, by forwarding local or remote ports (a more detailed explanation [here](https://chamibuddhika.wordpress.com/2012/03/21/ssh-tunnelling-explained/)). The tunneling is useful for multiple scenarios, such as reaching services in networks that are placed behind a gateway, firewalled, etc.

Assume a service running on port 8000 and a VM running in a private network, here 10.0.0.0/24. This VM is accessible through a gateway. By defining an end-to-end tunnel towards this VM and service (using local port forwarding, *-L*), it is possible to reach the service from the local host.

```bash
# Details for gateway
gwport=22
gwuser=user1
gwkey=~/.ssh/id_gw
gwip=270.0.0.20

# Details for private host
prip=10.10.0.10
prport=8000

# Details for localhost
loport=8001

# General form
ssh -L ${loport}:${prip}:${prport} -p${gwport} -i ${gwkey} ${gwuser}@${gwip}

# Specific example
ssh -L 8001:10.10.0.10:8000 -p9999 -i ~/.ssh/id_gw user1@270.0.0.20
```

Here, the port 8001 (in localhost) is the *left-side* of the tunnel, while the *right-side* is the remote port 8000 (in 10.10.0.10), where the service is running. Note the tunnel is set-up after there is a connection established towards the gateway (ip=270.0.0.20, port=9999).

```
    localhost                gateway                        private
   ------------------------------------------------------------------

   [ internal network (10.0.0.0/24) ]

                            port=I1                           port=I2
                                |                               |
                                +-------------------------------+

   [ ssh connection (localhost -> 270.0.0.20) ]

    port=S1                  port=9999
        |                       |
        +-----------------------+

    [ tunneling with local port forwarding ]

    port=8001                                               port=8000
        |                                                       |
        +-------------------------------------------------------+
```

With the tunnel in place it is possible to access this service from localhost; e.g. an HTTPS-based REST API would be accessed via https://localhost:8001.

### Double SSH hop

A double-hop in SSH will jump from localhost to a remote server, having an intermediate hop on an intermediate server. Specific ports and keys can be incorporated.

This is handy to directly access hosts under a gateway (or even proxy some commands to such hosts). The generalisation to multiple-hop SSH is not trivial and may imply the combination of tunnels and usage of SSH configuration like [*ProxyCommand* and *ProxyJump*](https://en.wikibooks.org/wiki/OpenSSH/Cookbook/Proxies_and_Jump_Hosts).

```bash
# Details for server 1
s1port=9998
s1user=user1
s1key=~/.ssh/id_s1
s1ip=175.0.0.20

# Details for server 2
s2port=9999
s2user=user2
s2key=~/.ssh/id_s2
s2ip=213.0.0.30

# General form
ssh -p${s1port} -i${s1key} ${s1user}@${s1ip} -t ssh -p${s2port} -i ${s2key} ${s2user}@${s2ip}

# Specific example
ssh -p9998 -i ~/.ssh/id_s1 user1@175.0.0.20 -t ssh -p9999 -i ~/.ssh/id_s2 user2@213.0.0.30
```

Here, two SSH connections are established in sequence. Because of that, server1 must be authorised to connect to server2 (that is, the *"~/.ssh/id_s2"* must be located in server1).

```
    localhost                server1                        server2
   ------------------------------------------------------------------

   [ ssh connection (localhost -> 175.0.0.20) ]

    port=S1                  port=9998
        |                       |
        +-----------------------+

   [ ssh connection (175.0.0.20 -> 213.0.0.30 ]

                             port=S2                        port=9999
                                |                               |
                                +-------------------------------+
```

### Double SCP hop

Imagine now another scenario, similar to the ones mentioned before; where someone wants to transmit some file to a host that lies behind a gateway or network. Combining SCP with some *ProxyCommand* instructions shall do the work.

```bash
# Details for server 1
s1port=9998
s1user=user1
s1key=~/.ssh/id_s1
s1ip=175.0.0.20
s1file=/opt/file

# Details for server 2
s2port=9999
s2user=user2
s2key=~/.ssh/id_s2
s2ip=213.0.0.30
s2file=/tmp/file

# General form
scp -o ProxyCommand="ssh -p${s1port} ${s1user}@${s1ip} nc ${s2ip} ${s2port}" \
    -o IdentityFile="${s2key}" ${s1file} ${s2user}@${s2ip}:${s2file}

# Specific example
scp -o ProxyCommand="ssh -p9998 user1@175.0.0.20 nc 213.0.0.30 9999" \
    -o IdentityFile="~/.ssh/id_s2" /opt/file user2@213.0.0.30:/tmp/file
```

Note that this scenario is different to the one above: even if server2 is only accessible from server1, localhost must be authorised to access server2 (that is, the *"~/.ssh/id_s2"* must be located in localhost).
