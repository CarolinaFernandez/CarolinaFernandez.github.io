---
layout: post
title:  "Multi-node Kubernetes cluster in VirtualBox"
description: "Considerations to setup the Kubernetes networking when initialising a multi-node cluster in VirtualBox"
date:   2021-06-28 22:37:41
categories: devops
tags: [k8s, docker]
comments: true
---

* TOC
{:toc}

Deploying a multi-node k8s cluster (e.g., multiple workers) while following the official Kubernetes instructions (i.e., not using options such as Minikube or frameworks like Rancher) can easily lead to networking errors. Furthermore, if using Vagrant for that task, there is also another network-related consideration to bear in mind for multi-node setups.

<!--more-->

Networking considerations are to be taken in mind here, because otherwise the *Container Network Interface (CNI)* may not be properly configured and, even independently of that, worker nodes will not be able to join the cluster.

To illustrate the environment at hand, a 3-node k8s cluster (one master/CP, two workers) deployed in VirtualBox, with the Vagrantfile and scripts [available in GitHub](https://github.com/CarolinaFernandez/curso-infra-cloud/tree/master/tools/kubernetes).

The networking part will look like this in the different nodes:

| Node | Hostname | iface=enp0s3 | iface=enp0s8 |
| ------ | ------ | ------ | ------ |
| k8s-cp | cp | 10.0.2.15/24 | 192.178.33.110/24 |
| k8s-worker1 | worker1 | 10.0.2.15/24 | 192.178.33.120/24 |
| k8s-worker2 | worker2 | 10.0.2.15/24 | 192.178.33.130/24 |

Thee major issue to address is that the k8s-cp IP used to advertise the cluster to the rest of nodes shall be explicitly indicated in any environment *whose primary interface does not expose a publicly reachable IP to all other nodes*.

This is the case of a VirtualBox environment (here used through Vagrant). The primary interface is `enp0s3`, which uses NAT and gets assigned the 10.0.2.15/24 IP. This means that **all** VirtualBox VMs will have this same IP assigned to `enp0s3`.
This will cause failures both to:
* Allow any other node to join the cluster; and
* Cause conflict in the CNI (here, Calico) because k8s-cp will have the cluster advertised on the primary, NATted IP; and future workers will try to access services hosted in k8s-cp (such as kube-apiserver) that will instead be searched for in their own private network. 

An example of the first error is shown below, resulting into the joining node to attempt to look for the kube-apiserver in its own address:

```bash
sudo kubeadm join 10.0.2.15:6443 --token qualsk.0584iwavwhmmq0ox \
	--discovery-token-ca-cert-hash sha256:7cb2ec38493492631ebb3de5aac2823747191ae62cfbaa5426578ed8803bdcb8 
Joining cluster from host with IP=192.178.33.110
[preflight] Running pre-flight checks

error execution phase preflight: couldn't validate the identity of the API Server: Get "https://10.0.2.15:6443/api/v1/namespaces/kube-public/configmaps/cluster-info?timeout=10s": dial tcp 10.0.2.15:6443: connect: connection refused
To see the stack trace of this error execute with --v=5 or higher
```

An example of the second error is shown below, and results in k8s-worker1 to not be able to get to a stable, fully running state:

```bash
vagrant@cp:~$ kubectl get pod -A
NAMESPACE     NAME                                       READY   STATUS             RESTARTS   AGE
kube-system   calico-kube-controllers-5f6cfd688c-fcfnj   1/1     Running            0          16m
kube-system   calico-node-5rhk6                          0/1     CrashLoopBackOff   7          12m
kube-system   calico-node-k2x9k                          1/1     Running            0          16m
kube-system   coredns-74ff55c5b-7f8jc                    1/1     Running            0          16m
kube-system   coredns-74ff55c5b-9ls7h                    1/1     Running            0          16m
kube-system   etcd-k8scp                                 1/1     Running            0          16m
kube-system   kube-apiserver-k8scp                       1/1     Running            0          16m
kube-system   kube-controller-manager-k8scp              1/1     Running            0          16m
kube-system   kube-proxy-8qkvn                           1/1     Running            0          16m
kube-system   kube-proxy-pjj8r                           1/1     Running            0          12m
kube-system   kube-scheduler-k8scp                       1/1     Running            0          16m
```

{% capture note-text %}Note how the Felix service runs a liveness check on a non-existing service on localhost, and how the BIRD service tries to fetch data from a non-existing file.
{% endcapture %}
{% include highlight-note.html %}

```bash
vagrant@cp:~$ kubectl describe pod calico-node-5rhk6 -n kube-system
(...)
Node:                 worker1/192.178.33.120
(...)
IP:                   192.178.33.120
(...)
Containers:
  calico-node:
    Container ID:   cri-o://0ddff8a64db5a95388d00d2aa5086a89e14359afc7030d3993018469ee963914
    (...)
    Ready:          False
    (...)
    Liveness:   exec [/bin/calico-node -felix-live -bird-live] delay=10s timeout=10s period=10s #success=1 #failure=6
    Readiness:  exec [/bin/calico-node -felix-ready -bird-ready] delay=0s timeout=10s period=10s #success=1 #failure=3
    (...)
    Environment:
      (...)
      IP:                                 autodetect
      (...)
      CALICO_IPV4POOL_CIDR:               172.178.33.10/16
      IP_AUTODETECTION_METHOD:            can-reach=192.178.33.110
      (...)
Conditions:
  Type              Status
  Initialized       True 
  Ready             False 
  ContainersReady   False 
  PodScheduled      True 
(...)
Tolerations:     :NoSchedule op=Exists
                 :NoExecute op=Exists
                 CriticalAddonsOnly op=Exists
                 node.kubernetes.io/disk-pressure:NoSchedule op=Exists
                 node.kubernetes.io/memory-pressure:NoSchedule op=Exists
                 node.kubernetes.io/network-unavailable:NoSchedule op=Exists
                 node.kubernetes.io/not-ready:NoExecute op=Exists
                 node.kubernetes.io/pid-pressure:NoSchedule op=Exists
                 node.kubernetes.io/unreachable:NoExecute op=Exists
                 node.kubernetes.io/unschedulable:NoSchedule op=Exists
Events:
  Type     Reason     Age                   From               Message
  ----     ------     ----                  ----               -------
  Normal   Scheduled  12m                   default-scheduler  Successfully assigned kube-system/calico-node-5rhk6 to worker1
  Normal   Pulling    12m                   kubelet            Pulling image "docker.io/calico/cni:v3.20.0"
  Normal   Pulled     12m                   kubelet            Successfully pulled image "docker.io/calico/cni:v3.20.0" in 14.711193713s
  Normal   Started    12m                   kubelet            Started container upgrade-ipam
  Normal   Created    12m                   kubelet            Created container upgrade-ipam
  Normal   Created    12m                   kubelet            Created container install-cni
  Normal   Pulled     12m                   kubelet            Container image "docker.io/calico/cni:v3.20.0" already present on machine
  Normal   Started    12m                   kubelet            Started container install-cni
  Normal   Pulling    12m                   kubelet            Pulling image "docker.io/calico/pod2daemon-flexvol:v3.20.0"
  Normal   Created    12m                   kubelet            Created container flexvol-driver
  Normal   Pulled     12m                   kubelet            Successfully pulled image "docker.io/calico/pod2daemon-flexvol:v3.20.0" in 6.61434581s
  Normal   Started    12m                   kubelet            Started container flexvol-driver
  Normal   Pulling    12m                   kubelet            Pulling image "docker.io/calico/node:v3.20.0"
  Normal   Pulled     11m                   kubelet            Successfully pulled image "docker.io/calico/node:v3.20.0" in 9.621457222s
  Normal   Created    11m                   kubelet            Created container calico-node
  Normal   Started    11m                   kubelet            Started container calico-node
  Warning  Unhealthy  10m (x5 over 11m)     kubelet            Liveness probe failed: calico/node is not ready: Felix is not live: Get "http://localhost:9099/liveness": dial tcp 127.0.0.1:9099: connect: connection refused
  Warning  Unhealthy  2m22s (x47 over 11m)  kubelet            Readiness probe failed: calico/node is not ready: BIRD is not ready: Failed to stat() nodename file: stat /var/lib/calico/nodename: no such file or directory
```

### Exposing a specific interface (IP) to init the cluster

The master/CP IP is passed and advertised to all nodes in the cluster that would like to join later on.

Define some networking variables first to use later.
{% include codeblock-header.html %}
```bash
CP_IP="192.178.33.110"
POD_CIDR="172.178.33.0/16"
```

Then decide whether to bring up the cluster using the CLI parameters or a YAML file. This guide focuses on the simplest method (CLI parameters).

With CLI parameters:
{% include codeblock-header.html %}
```bash
sudo kubeadm init --pod-network-cidr ${POD_CIDR} --apiserver-advertise-address=${CP_IP}
```

{% capture note-text %}For the YAML file, check <a target="_blank" href="https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/#config-file">this guide</a>) and also check the command <tt>kubeadm config print init-defaults</tt>, which will likely help you translating CLI parameters to those in the YAML file (e.g., "--apiserver-advertise-address" will be defined in .localAPIEndpoint.advertiseAddress).
{% endcapture %}
{% include highlight-note.html %}

### Define the explicitly advertised IP in the CNI configuration

In this particular case, the CNI uses the Calico plugin. First download the Calico manifest.

{% include codeblock-header.html %}
```bash
wget https://docs.projectcalico.org/manifests/calico.yaml
cp -p calico.yaml calico-cni.yaml
```

Then modify the file to update with the specific networking data for your cluster, including the IP that was previously advertised (as well as the pod CIDR, as usual).

{% capture note-text %}Defining the explicit interface in Calico is important because, otherwise, the first interface found will be auto-detected (see <a target="_blank" href="https://docs.projectcalico.org/reference/node/configuration#ip-autodetection-methods">autodetection methods in Calico</a>).
{% endcapture %}
{% include highlight-warning.html %}

{% include codeblock-header.html %}
```bash
# Note: it is very important to apply correct indentation through spaces
sed -i "s|# - name: CALICO_IPV4POOL_CIDR|- name: CALICO_IPV4POOL_CIDR|g" calico-cni.yaml
sed -i "s|#   value: \"192.168.0.0/16\"|  value: \"${POD_CIDR}\"|g" calico-cni.yaml
# Note: the following can be used to make it further explicit, although it did not seem necessary to bring up the cluster
sed -i "s|#   value: \"192.168.0.0/16\"|  value: \"${POD_CIDR}\"\n            # Extra: adding to avoid auto-detection issues with IPs in VB\n            - name: IP_AUTODETECTION_METHOD\n              value: \"can-reach=${HOST_IP}\"|g" calico-cni.yaml
```

The resulting section will be as follows:
```yaml
            # The default IPv4 pool to create on startup if none exists. Pod IPs will be
            # chosen from this range. Changing this value after installation will have
            # no effect. This should fall within `--cluster-cidr`.
            - name: CALICO_IPV4POOL_CIDR
              value: "172.178.33.0/16"
            # Extra: adding to avoid auto-detection issues with IPs in VB
            - name: IP_AUTODETECTION_METHOD
              value: "can-reach=192.178.33.110"
```


After applying this change and recreating the cluster, the calico node on k8s-worker1 should converge to the "Running" status.

```bash
vagrant@cp:~$ kubectl get pods -A -o wide
NAMESPACE     NAME                                       READY   STATUS    RESTARTS   AGE     IP               NODE     NOMINATED NODE   READINESS GATES
kube-system   calico-kube-controllers-5f6cfd688c-sxtwd   1/1     Running   0          5m4s    172.178.74.129   cp    <none>           <none>
kube-system   calico-node-p949f                          1/1     Running   0          5m4s    192.178.33.110   cp    <none>           <none>
kube-system   calico-node-vwknl                          0/1     Running   0          43s     192.178.33.120   worker1   <none>           <none>
kube-system   coredns-74ff55c5b-49bsf                    1/1     Running   0          5m6s    172.178.74.130   cp    <none>           <none>
kube-system   coredns-74ff55c5b-s9msd                    1/1     Running   0          5m6s    172.178.74.131   cp    <none>           <none>
kube-system   etcd-k8scp                                 1/1     Running   0          5m14s   192.178.33.110   cp    <none>           <none>
kube-system   kube-apiserver-k8scp                       1/1     Running   0          5m14s   192.178.33.110   cp    <none>           <none>
kube-system   kube-controller-manager-k8scp              1/1     Running   0          5m14s   192.178.33.110   cp    <none>           <none>
kube-system   kube-proxy-s46ch                           1/1     Running   0          43s     192.178.33.120   worker1   <none>           <none>
kube-system   kube-proxy-x9wps                           1/1     Running   0          5m6s    192.178.33.110   cp    <none>           <none>
kube-system   kube-scheduler-k8scp                       1/1     Running   0          5m14s   192.178.33.110   cp    <none>           <none>
```

And the Calico pod in k8s-worker1 should now be successfully initialised and ready.

{% capture note-text %}However, the BIRD service is still failing the readiness probe. Some of the nodes may be unreachable via BGP and must be investigated.
{% endcapture %}
{% include highlight-warning.html %}

```bash
vagrant@cp:~$ kubectl describe pod calico-node-vwknl -n kube-system
(...)
Node:                 worker1/192.178.33.120
(...)
IP:                   192.178.33.120
Controlled By:  DaemonSet/calico-node
(...)
Containers:
  calico-node:
    Container ID:   docker://bc0276580a076444cf3fb23dadd4d1902d7f31efd95d1c09517dd20bb28419e4
    (...)
    Ready:          True
    (...)
    Liveness:   exec [/bin/calico-node -felix-live -bird-live] delay=10s timeout=10s period=10s #success=1 #failure=6
    Readiness:  exec [/bin/calico-node -felix-ready -bird-ready] delay=0s timeout=10s period=10s #success=1 #failure=3
    (...)
    Environment:
      (...)
      IP:                                 autodetect
      (...)
      CALICO_IPV4POOL_CIDR:               172.178.33.10/16
      IP_AUTODETECTION_METHOD:            can-reach=192.178.33.110
      (...)
Conditions:
  Type              Status
  Initialized       True 
  Ready             True 
  ContainersReady   True 
  PodScheduled      True 
(...)

Events:
  Type     Reason     Age   From               Message
  ----     ------     ----  ----               -------
  Normal   Scheduled  66s   default-scheduler  Successfully assigned kube-system/calico-node-vwknl to worker1
  Normal   Pulling    56s   kubelet            Pulling image "docker.io/calico/cni:v3.20.0"
  Normal   Pulled     45s   kubelet            Successfully pulled image "docker.io/calico/cni:v3.20.0" in 11.259383483s
  Normal   Created    44s   kubelet            Created container upgrade-ipam
  Normal   Started    44s   kubelet            Started container upgrade-ipam
  Normal   Pulled     44s   kubelet            Container image "docker.io/calico/cni:v3.20.0" already present on machine
  Normal   Created    44s   kubelet            Created container install-cni
  Normal   Started    44s   kubelet            Started container install-cni
  Normal   Pulling    43s   kubelet            Pulling image "docker.io/calico/pod2daemon-flexvol:v3.20.0"
  Normal   Pulled     38s   kubelet            Successfully pulled image "docker.io/calico/pod2daemon-flexvol:v3.20.0" in 4.55674576s
  Normal   Created    38s   kubelet            Created container flexvol-driver
  Normal   Started    38s   kubelet            Started container flexvol-driver
  Normal   Pulling    38s   kubelet            Pulling image "docker.io/calico/node:v3.20.0"
  Normal   Pulled     31s   kubelet            Successfully pulled image "docker.io/calico/node:v3.20.0" in 7.04211673s
  Normal   Created    30s   kubelet            Created container calico-node
  Normal   Started    30s   kubelet            Started container calico-node
  Warning  Unhealthy  28s   kubelet            Readiness probe failed: calico/node is not ready: BIRD is not ready: Error querying BIRD: unable to connect to BIRDv4 socket: dial unix /var/run/calico/bird.ctl: connect: connection refused
```

Even with the error above, all pods and nodes are ready at this point (although some Calico nodes may in unhealthy status).
A random test to see if the networking is okay is made now by downloading the Nginx Load Balancer and assessing a proper deployment.

```bash
vagrant@cp:~$ kubectl apply -f https://k8s.io/examples/controllers/nginx-deployment.yaml
deployment.apps/nginx-deployment created

vagrant@cp:~$ kubectl get pod -n default
NAME                               READY   STATUS    RESTARTS   AGE
nginx-deployment-9456bbbf9-bsfhg   1/1     Running   0          24s
nginx-deployment-9456bbbf9-mw7t5   1/1     Running   0          24s
nginx-deployment-9456bbbf9-r5g5p   1/1     Running   0          24s
```

Success.
