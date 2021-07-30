---
layout: post
title:  "Setting up the Kubernetes dashboard"
description: "Setting up the dashboard in a multi-node Kubernetes cluster"
date:   2021-04-18 21:05:17
categories: devops
tags: [k8s]
comments: true
---

* TOC
{:toc}

Whilst the Kubernetes dashboard is directly setup by environments and tools like Minikube, when setting a Kubernetes instance from scratch, this must be manually enabled.

<!--more-->

This is more subtle when deploying within a cluster of Kubernetes nodes, since (as other Kubernetes resources) the dashboard is deployed and accessible from the node where the commands are executed. Attempting to access from other nodes will result into routing issues.

### Setting up the Dashboard in a specific node

Following this instructions it will be possible to deploy specific Kubernetes resources that will be accessible on the node where these are requested. In this case, I consider a 3-node deployment, with 1 master and 2 worker nodes. The dashboard will run in the master node, after having enabled the pod scheduling in the master or control plane.

First you have to make sure that the dashboard port (8001) is accessible from your current environment (e.g., localhost) to the Kubernetes node where you will run the dashboard. For Vagrant environments, you could check [this file](https://github.com/CarolinaFernandez/curso-infra-cloud/blob/master/tools/kubernetes/Vagrantfile#L72) and adapt to your needs.

Then, it is time to create specific resources like Pod, ServiceAccount and Deployment through applying the following YAML descriptors. The content is taken from the [Kubernetes-dashboard repository itself](https://raw.githubusercontent.com/kubernetes/dashboard/v2.2.0/aio/deploy/recommended.yaml). It is, however, slightly adapted to force the location of the Deployment resource into the current node, as per the instructions in the [Kubernetes guides](https://kubernetes.io/docs/tasks/configure-pod-container/assign-pods-nodes/).

For instance, this is the list of available nodes, where the current node is "k8s-master".

```bash
$ kubectl get nodes
NAME                    STATUS     ROLES                  AGE   VERSION
k8s-master              Ready      control-plane,master   31d   v1.21.2
k8s-node01              Ready      <none>                 31d   v1.21.2
k8s-node02              Ready      <none>                 31d   v1.21.2
```

The name of the current node (in this case, the name of the master node) is exported and will be used in the next step to create the resources.
```bash
export K8S_MASTER_NODE_NAME=$(kubectl get nodes | grep master | cut -d" " -f1)
```

Now, create all dashboard-related resources.
```bash
cat <<EOF | kubectl apply -f -
# Copyright 2017 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

apiVersion: v1
kind: Namespace
metadata:
  name: kubernetes-dashboard

---

apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard

---

kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  ports:
    - port: 443
      targetPort: 8443
  selector:
    k8s-app: kubernetes-dashboard

---

apiVersion: v1
kind: Secret
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard-certs
  namespace: kubernetes-dashboard
type: Opaque

---

apiVersion: v1
kind: Secret
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard-csrf
  namespace: kubernetes-dashboard
type: Opaque
data:
  csrf: ""

---

apiVersion: v1
kind: Secret
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard-key-holder
  namespace: kubernetes-dashboard
type: Opaque

---

kind: ConfigMap
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard-settings
  namespace: kubernetes-dashboard

---

kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
rules:
  # Allow Dashboard to get, update and delete Dashboard exclusive secrets.
  - apiGroups: [""]
    resources: ["secrets"]
    resourceNames: ["kubernetes-dashboard-key-holder", "kubernetes-dashboard-certs", "kubernetes-dashboard-csrf"]
    verbs: ["get", "update", "delete"]
    # Allow Dashboard to get and update 'kubernetes-dashboard-settings' config map.
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["kubernetes-dashboard-settings"]
    verbs: ["get", "update"]
    # Allow Dashboard to get metrics.
  - apiGroups: [""]
    resources: ["services"]
    resourceNames: ["heapster", "dashboard-metrics-scraper"]
    verbs: ["proxy"]
  - apiGroups: [""]
    resources: ["services/proxy"]
    resourceNames: ["heapster", "http:heapster:", "https:heapster:", "dashboard-metrics-scraper", "http:dashboard-metrics-scraper"]
    verbs: ["get"]

---

kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
rules:
  # Allow Metrics Scraper to get metrics from the Metrics server
  - apiGroups: ["metrics.k8s.io"]
    resources: ["pods", "nodes"]
    verbs: ["get", "list", "watch"]

---

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: kubernetes-dashboard
subjects:
  - kind: ServiceAccount
    name: kubernetes-dashboard
    namespace: kubernetes-dashboard

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kubernetes-dashboard
subjects:
  - kind: ServiceAccount
    name: kubernetes-dashboard
    namespace: kubernetes-dashboard

---

kind: Deployment
apiVersion: apps/v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: kubernetes-dashboard
  template:
    metadata:
      labels:
        k8s-app: kubernetes-dashboard
    spec:
      containers:
        - name: kubernetes-dashboard
          image: kubernetesui/dashboard:v2.2.0
          imagePullPolicy: Always
          ports:
            - containerPort: 8443
              protocol: TCP
          args:
            - --auto-generate-certificates
            - --namespace=kubernetes-dashboard
            # Uncomment the following line to manually specify Kubernetes API server Host
            # If not specified, Dashboard will attempt to auto discover the API server and connect
            # to it. Uncomment only if the default does not work.
            # - --apiserver-host=http://my-address:port
          volumeMounts:
            - name: kubernetes-dashboard-certs
              mountPath: /certs
              # Create on-disk volume to store exec logs
            - mountPath: /tmp
              name: tmp-volume
          livenessProbe:
            httpGet:
              scheme: HTTPS
              path: /
              port: 8443
            initialDelaySeconds: 30
            timeoutSeconds: 30
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsUser: 1001
            runAsGroup: 2001
      nodeName: ${K8S_MASTER_NODE_NAME}
      volumes:
        - name: kubernetes-dashboard-certs
          secret:
            secretName: kubernetes-dashboard-certs
        - name: tmp-volume
          emptyDir: {}
      serviceAccountName: kubernetes-dashboard
      nodeSelector:
        "kubernetes.io/os": linux
      # Comment the following tolerations if Dashboard must not be deployed on master
      tolerations:
        - key: node-role.kubernetes.io/master
          effect: NoSchedule

---

kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: dashboard-metrics-scraper
  name: dashboard-metrics-scraper
  namespace: kubernetes-dashboard
spec:
  ports:
    - port: 8000
      targetPort: 8000
  selector:
    k8s-app: dashboard-metrics-scraper

---

kind: Deployment
apiVersion: apps/v1
metadata:
  labels:
    k8s-app: dashboard-metrics-scraper
  name: dashboard-metrics-scraper
  namespace: kubernetes-dashboard
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: dashboard-metrics-scraper
  template:
    metadata:
      labels:
        k8s-app: dashboard-metrics-scraper
      annotations:
        seccomp.security.alpha.kubernetes.io/pod: 'runtime/default'
    spec:
      containers:
        - name: dashboard-metrics-scraper
          image: kubernetesui/metrics-scraper:v1.0.6
          ports:
            - containerPort: 8000
              protocol: TCP
          livenessProbe:
            httpGet:
              scheme: HTTP
              path: /
              port: 8000
            initialDelaySeconds: 30
            timeoutSeconds: 30
          volumeMounts:
          - mountPath: /tmp
            name: tmp-volume
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsUser: 1001
            runAsGroup: 2001
      serviceAccountName: kubernetes-dashboard
      nodeSelector:
        "kubernetes.io/os": linux
      # Comment the following tolerations if Dashboard must not be deployed on master
      tolerations:
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
      volumes:
        - name: tmp-volume
          emptyDir: {}
EOF
```

Create a few extra resources to use a different ServiceAccount instead.

```bash
# Create a service account
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# Create a cluster role binding
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
```

Wait few seconds after this (e.g., 15 seconds, maybe less) to allow the dashboard to get to run.
Check the resources, for instance the Pod resources generated by the Deployments set above:

```bash
$ kubectl get pods -n kubernetes-dashboard
NAME                                         READY   STATUS    RESTARTS   AGE
dashboard-metrics-scraper-856586f554-7m7bv   1/1     Running   0          15s
kubernetes-dashboard-85b5f4579c-4xhzk        1/1     Running   0          15s
```

Verify the generated pod is reachable already:

```bash
kube_dashboard_ns="kubernetes-dashboard"
kube_dashboard_pod_name=$(kubectl get pods -n ${kube_dashboard_ns} | grep "kubernetes-dashboard" | cut -d" " -f1)
kube_dashboard_pod_ip=$(kubectl get pod -n ${kube_dashboard_ns} ${kube_dashboard_pod_name} -o wide | awk -F ' ' '{print $6}' | tail -1)
ping -c 1 ${kube_dashboard_pod_ip}
```

If so, obtain and copy the token provided by the Secret resource defined above.

```bash
TOKEN=$(kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}")
kubectl config set-credentials admin-user --token="${TOKEN}"
echo $TOKEN
```

Finally, if you want to access the dashboard from outside the node where this runs, issue a `kubectl proxy` command.
*Note: this will be a background process. Its PID is provided right after its execution, in case you ought to terminate it.*

```bash
nohup kubectl proxy --kubeconfig=/home/vagrant/.kube/config --address='0.0.0.0' --port=8001 --accept-hosts='.*' > kubectl_proxy_dashboard.log &
```

Now, the dashboard will be located at [http://127.0.0.1:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy](http://127.0.0.1:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy). You may access it and input the token from the previous step.

*Note: if you run this into a remote environment (whether in a VM or in some external cloud), you may not have access to the localhost. In such case, you should make sure to forward specific ports from that VM to your localhost. If using Vagrant, you may examine [this Vagrantfile](https://github.com/CarolinaFernandez/curso-infra-cloud/blob/master/tools/kubernetes/Vagrantfile#L72) first.*

When all above is taken care of, the dashboard will be ready to interact with.
