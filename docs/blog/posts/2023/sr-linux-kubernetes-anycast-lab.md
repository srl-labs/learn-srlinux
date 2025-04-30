---
date: 2023-08-10
tags:
  - kubernetes
  - minikube
  - sr linux
  - containerlab
  - metallb
  - anycast
  - evpn
authors:
  - michelredondo
  - rdodin
---

# Exposing Kubernetes Services to SR Linux-based IP Fabric with Anycast Gateway and MetalLB

In the era of applications, it is easy to forget about the underlying infrastructure that interconnects them. However, the network is still the foundation of any application as it provides the connectivity and services that applications rely on.

The most popular container orchestration system - Kubernetes - is no exception to this rule where infrastructure is essential for several reasons:

1. **DC fabric**: Almost every k8s cluster leverages a DC fabric underneath to interconnect worker nodes.
2. **Communication Between Services**: Kubernetes applications are often composed of multiple microservices that need to communicate with each other. A well-designed network infrastructure ensures reliable and efficient communication between these services, contributing to overall application performance.
3. **Load Balancing**: Kubernetes distributes incoming traffic across multiple instances of an application for improved availability and responsiveness. A robust network setup provides load balancing capabilities, preventing overload on specific instances and maintaining a smooth user experience.
4. **Scalability and Resilience**: Kubernetes is renowned for scaling applications up or down based on demand. A resilient network infrastructure supports this scalability by efficiently routing traffic and maintaining service availability even during high traffic periods.

Getting familiar with all these features is vital for any network engineer working with a fabric supporting a k8s cluster. Wouldn't it be great to have a way to get into all of this without the need of a physical lab?

In this blog post we will dive into a lab topology that serves as a virtual environment to test the integration of a Kubernetes cluster with an IP fabric. The emulated fabric topology consists of a [SR Linux-based](https://learn.srlinux.dev/) Clos fabric with the Kubernetes cluster nodes connected to it. The k8s cluster features a [MetalLB](https://metallb.universe.tf/) load-balancer that unlocks the capability of announcing deployed services to the IP fabric.

Throughout the lab, we will explore the way k8s services are announced to the IP fabric, and how L3 EVPN service with Anycast Gateway can be leveraged to create a simple and efficient overlay network for external users of the k8s services.

As for the tooling used to bring up the lab we will use [Minikube](https://minikube.sigs.k8s.io/) to deploy a personal virtual k8s cluster and [Containerlab](https://containerlab.dev/) will handle the IP fabric emulation and the connection between both environments.

<!-- more -->

## Lab summary

| Summary                   |                                                                                                                                                                                                 |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Lab name**              | SR Linux Kubernetes Anycast Lab                                                                                                                                                                 |
| **Lab components**        | Nokia SR Linux, Kubernetes, MetalLB                                                                                                                                                             |
| **Resource requirements** | :fontawesome-solid-microchip: 6 vCPU <br/>:fontawesome-solid-memory: 12 GB                                                                                                                      |
| **Lab**                   | [srl-labs/srl-k8s-anycast-lab][lab]                                                                                                                                                             |
| **Version information**   | [`containerlab:0.44.3`](https://containerlab.dev/install/), [`srlinux:23.7.1`](https://github.com/nokia/srlinux-container-image),[`minikube v1.30.1`](https://minikube.sigs.k8s.io/docs/start/) |
| **Authors**               | Míchel Redondo [:material-linkedin:][mr-linkedin]                                                                                                                                               |

At the end of this blog post you can find a [quick summary](#tldr) of the steps performed to deploy the lab and configure the use cases.

## Prerequisites

The following tools are required to run the lab on any Linux host. The links will get you to the installation instructions.

* The lab leverages [Containerlab](https://containerlab.dev/install/) to spin up a Leaf/Spine Fabric coupled with [Minikube](https://minikube.sigs.k8s.io/docs/start/) to deploy the Kubernetes cluster.
* [Docker engine](https://docs.docker.com/engine/install/) to power containerlab.
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) CLI client is also required to interact with the k8s cluster.

## Lab description

### Topology

This lab aims to provide users with an environment to test the network integration of a Kubernetes cluster with a Leaf/Spine SR Linux fabric.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/topology.drawio"}'></div>
  <figcaption>Topology</figcaption>
</figure>

The topology consists of:

* A Leaf/Spine Clos Fabric: 2xSpines, 4xLeaf switches
* Minikube kubernetes cluster with MetalLB load balancing implementation (3 nodes)
* Linux clients to simulate connections to k8s service (4 clients)

### Kubernetes Service

To illustrate the integration between the workloads running in the k8s cluster and the IP fabric, we will deploy a simple NGINX Echo service replicated across the three k8s nodes. A [MetalLB](https://metallb.universe.tf/)-based [LoadBalancer](https://www.tkng.io/services/loadbalancer/) service is created to expose the NGINX Echo instances to the fabric and the outside world by establishing BGP sessions with Leaf switches to announce the IP addresses of the exposed services to the IP fabric.

!!!note
    The external IP address that a Load Balancer associates with the service is often called a "virtual IP address" or "VIP".

With simulated clients, we will verify how traffic is distributed among the different nodes/pods using `curl` and reaching over to the exposed service IP address.

### Underlay Networking

The [eBGP unnumbered peering](https://documentation.nokia.com/srlinux/23-7/books/routing-protocols/bgp.html#bgp-unnumbered-peer) makes the core of our IP fabric. Each leaf switch is configured with a unique ASN, whereas all spines share the same ASN, which is a common practice in Leaf/Spine fabrics:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/fabric_ebgp.drawio"}'></div>
  <figcaption>Underlay IPv6 Link Local eBGP sessions</figcaption>
</figure>

With eBGP unnumbered peers feature it is easy to setup BGP-based underlay connectivity between the leaf and spine switches while leveraging BGP's high scalability and proven resiliency[^1].

!!!tip inline end
    Configuration applied to the fabric nodes can be found in [config directory](https://github.com/srl-labs/srl-k8s-anycast-lab/tree/main/configs) of a lab repo.

Through eBGP the loopback/system IP addresses are exchanged between the leaves, making it possible to setup iBGP sessions for the overlay EVPN services that are consumed by the k8s nodes and clients:

### Overlay Networking

To deploy EVPN services on top of the IP fabric we need to peer all leaves in our datacenter/pod with each other. Due to the potential scale of the network, it is not practical to establish full mesh iBGP sessions between all leaves. Instead, we will use the Spine switches running in a Route Reflector mode to reduce the number of iBGP sessions required to establish full connectivity between all leaves.[^3]

With this configuration, each leaf switch will establish an iBGP session with each spine switch and the spine switches will exchange the routes learned from the leaves with each other. This way, all leaves will learn the routes from all other leaves without the need to establish iBGP sessions with each other.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/fabric_ibgp.drawio"}'></div>
  <figcaption>Overlay iBGP EVPN sessions</figcaption>
</figure>

To connect k8s nodes and external clients with the IP fabric we create a routed network - `ip-vrf-1` - implemented as a distributed L3 EVPN service running on the leaf switches. Two subnets are configured for this network to interconnect k8s nodes and emulated clients:

* k8s nodes subnet: 192.168.1.0/24
* clients subnet: 192.168.2.0/24

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/logical.drawio"}'></div>
  <figcaption>Logical network topology</figcaption>
</figure>

Subnets are configured with Integrated Routing and Bridging (IRB) interfaces serving as default gateways for the k8s nodes and clients. The IRB interfaces are configured with the same IP address and MAC address across all leaf switches. This configuration is known as [Anycast Gateway](https://documentation.nokia.com/srlinux/23-7/books/evpn-vxlan/evpn-vxlan-tunnels-layer-3.html#anycast-gateways) which avoids inefficiencies for all-active multi-homing and speeds up convergence for host mobility.

From the SR Linux configuration perspective, each leaf would have the following network instances created jointly implementing the L3 EVPN service:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":1,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/logical.drawio"}'></div>
  <figcaption>Network instances composition</figcaption>
</figure>

MetalLB Load Balancer pods will establish BGP sessions to these anycast-GW IP addresses and advertise the IP addresses of the exposed k8s services.

## Containerlab topology file

The whole lab topology is declared in the Containerlab [`srl-k8s-lab.clab.yml`][clab-topo] file.

Let's review the different components of our topology definition file:

### Images

First we look at the different container images that will be used:

```yaml title="SR Linux and Client images"
topology:
  kinds:
    srl:
      image: ghcr.io/nokia/srlinux:23.7.1
      type: ixrd2l
    linux:
      image: ghcr.io/hellt/network-multitool
  # -- snip --
```

We will use the [SR Linux image v23.7.1](https://github.com/nokia/srlinux-container-image) that can be pulled as easily as `docker pull ghcr.io/nokia/srlinux:23.7.1`.

Our emulated clients will be deployed from the [network-multitool](https://github.com/users/hellt/packages/container/package/network-multitool) versatile Linux image.

Minikube directly manages Kubernetes container images and container creation.

### Nodes

The central stage of the Lab is taken by the Leaf/Spine switches, K8s nodes and Linux clients. Let's see how we define them:

```yaml title="Defining nodes"
topology:
  # -- snip --
  nodes:
    leaf1:
      kind: srl
      startup-config: configs/leaf1.conf

    cluster1:
      kind: ext-container #(1)!
      exec:
        - ip address add 192.168.1.11/24 dev eth1
        - ip route add 192.168.0.0/16 via 192.168.1.1

    client1:
     kind: linux
     binds:
        - configs/client-config.sh:/client-config.sh
     exec:
        - bash /client-config.sh 192.168.2.11 #(2)!
# -- snip --
```

1. Minikube will name k8s container nodes as `minikube` by default. With minikube's `profile` option we set cluster's node names to `cluster1`, `cluster1-m02` and `cluster-m03`.
2. `client-config.sh` is a script that configures client IP addresses and routes. It also updates the shell prompt with the name of the container, so it's easier to see which client we are connected to when we attach to the container's shell.

Containerlab will configure the Leaf/Spine nodes during the lab deployment by applying configuration commands stored in the [config][clab-configs] folder of the lab repository.

Minikube nodes are referenced in the topology using the `ext-container` kind. Nodes of `ext-container` kind are not deployed by containerlab, but belong to a topology and therefore can be "wired" with other nodes in the links section. Additionally, containerlab configures the cluster nodes with IP and routing information defined in the `exec` section.

!!!tip
    Consult with [containerlab](https://containerlab.dev/manual/kinds/ext-container/) documentation to learn more about the `ext-container` kind.

### Links

And finally, let's see how we interconnect all elements:

```yaml title="Defining links"
topology:
# -- snip --

  links:
    ### #### fabric ### ####
    - endpoints: ["spine1:e1-1", "leaf1:e1-49"]
    - endpoints: ["spine1:e1-2", "leaf2:e1-49"]
    - endpoints: ["spine1:e1-3", "leaf3:e1-49"]
    - endpoints: ["spine1:e1-4", "leaf4:e1-49"]

    - endpoints: ["spine2:e1-1", "leaf1:e1-50"]
    - endpoints: ["spine2:e1-2", "leaf2:e1-50"]
    - endpoints: ["spine2:e1-3", "leaf3:e1-50"]
    - endpoints: ["spine2:e1-4", "leaf4:e1-50"]
    
    #### minikube ####
    - endpoints: ["leaf1:e1-1", "cluster1:eth1"]
    - endpoints: ["leaf2:e1-1", "cluster1-m02:eth1"]
    - endpoints: ["leaf3:e1-1", "cluster1-m03:eth1"]

    #### clients ####
    - endpoints: ["client1:eth1", "leaf1:e1-2"]
    - endpoints: ["client2:eth1", "leaf2:e1-2"]
    - endpoints: ["client3:eth1", "leaf3:e1-2"]
    - endpoints: ["client4:eth1", "leaf4:e1-2"]
```

This is the full definition of all the connections required. As you can see, we use the first port (`e1-1`) of every leaf switch to connect the k8s node and second port (`e1-2`) to connect a client for tests.

!!! note
    minikube nodes `eth0` interfaces are connected to the docker bridge of the host running the topology. `eth1` interfaces, connected to Leaf switches, will be the ones used by MetalLB to establish the BGP sessions. As reachability is signaled through this interface, clients will also reach k8s cluster services through `eth1` interface.

## Lab deployment

In this section we go over the steps required to deploy the lab from scratch.

If not already done, clone the lab repository:

```bash
https://github.com/srl-labs/srl-k8s-anycast-lab.git && cd srl-k8s-anycast-lab
```

Deploy k8s 3-node cluster using minikube:

```bash title="k8s cluster deployment"
minikube start --nodes 3 -p cluster1
```

With this command, Minikube starts three k8s nodes (`cluster1`, `cluster1-m02` and `cluster1-m03`) and configures `kubectl` to use this cluster. We can verify that the nodes are up and running:

```bash
❯ kubectl get nodes
NAME           STATUS   ROLES           AGE   VERSION
cluster1       Ready    control-plane   59s   v1.27.3
cluster1-m02   Ready    <none>          39s   v1.27.3
cluster1-m03   Ready    <none>          23s   v1.27.3
```

After k8s cluster is started, deploy Containerlab topology:

```bash title="Containerlab topology deployment"
sudo clab deploy
```

At the end of the deployment process, you will see the summary table with details about the deployed nodes:

```text
--snip--
+----+--------------+--------------+-------------------------------------------------------------------------------------------------------------+---------------+---------+-----------------+----------------------+
| #  |     Name     | Container ID |                                                    Image                                                    |     Kind      |  State  |  IPv4 Address   |     IPv6 Address     |
+----+--------------+--------------+-------------------------------------------------------------------------------------------------------------+---------------+---------+-----------------+----------------------+
|  1 | cluster1     | d38f1b9d3b06 | gcr.io/k8s-minikube/kicbase:v0.0.40@sha256:8cadf23777709e43eca447c47a45f5a4635615129267ce025193040ec92a1631 | ext-container | running | 192.168.49.2/24 | N/A                  |
|  2 | cluster1-m02 | 14ce21a95c0f | gcr.io/k8s-minikube/kicbase:v0.0.40@sha256:8cadf23777709e43eca447c47a45f5a4635615129267ce025193040ec92a1631 | ext-container | running | 192.168.49.3/24 | N/A                  |
|  3 | cluster1-m03 | 9b889be40278 | gcr.io/k8s-minikube/kicbase:v0.0.40@sha256:8cadf23777709e43eca447c47a45f5a4635615129267ce025193040ec92a1631 | ext-container | running | 192.168.49.4/24 | N/A                  |
|  4 | client1      | 1907d66ceded | ghcr.io/hellt/network-multitool                                                                             | linux         | running | 172.20.20.10/24 | 2001:172:20:20::a/64 |
|  5 | client2      | 9a5130920578 | ghcr.io/hellt/network-multitool                                                                             | linux         | running | 172.20.20.5/24  | 2001:172:20:20::5/64 |
|  6 | client3      | de5ff1fb4956 | ghcr.io/hellt/network-multitool                                                                             | linux         | running | 172.20.20.3/24  | 2001:172:20:20::3/64 |
|  7 | client4      | 49002bc56914 | ghcr.io/hellt/network-multitool                                                                             | linux         | running | 172.20.20.8/24  | 2001:172:20:20::8/64 |
|  8 | leaf1        | 0f6e63225b6c | ghcr.io/nokia/srlinux:23.7.1                                                                                | srl           | running | 172.20.20.11/24 | 2001:172:20:20::b/64 |
|  9 | leaf2        | ab15530f4542 | ghcr.io/nokia/srlinux:23.7.1                                                                                | srl           | running | 172.20.20.9/24  | 2001:172:20:20::9/64 |
| 10 | leaf3        | 3c20b7404aa4 | ghcr.io/nokia/srlinux:23.7.1                                                                                | srl           | running | 172.20.20.4/24  | 2001:172:20:20::4/64 |
| 11 | leaf4        | 9ebc55bc2bae | ghcr.io/nokia/srlinux:23.7.1                                                                                | srl           | running | 172.20.20.6/24  | 2001:172:20:20::6/64 |
| 12 | spine1       | 89de7d80fa3d | ghcr.io/nokia/srlinux:23.7.1                                                                                | srl           | running | 172.20.20.7/24  | 2001:172:20:20::7/64 |
| 13 | spine2       | 19b8121babd5 | ghcr.io/nokia/srlinux:23.7.1                                                                                | srl           | running | 172.20.20.12/24 | 2001:172:20:20::c/64 |
+----+--------------+--------------+-------------------------------------------------------------------------------------------------------------+---------------+---------+-----------------+----------------------+
```

These simple steps conclude the lab deployment. At this point, we have a fully functional Leaf/Spine fabric and a bare three-node k8s cluster. In the next sections we will configure k8s networking and deploy a test service.

## MetalLB installation

A key component of our lab use case is the [MetalLB](https://metallb.universe.tf/) load balancer that is used to announce services IP addresses to the IP fabric. MetalLB is not installed by default in Minikube, so we need to enable it:

```bash
minikube addons enable metallb -p cluster1
```

MetalLB has two [operation modes](https://metallb.universe.tf/concepts/): Layer2 and BGP. We will use the BGP mode.

MetalLB also provides two different [BGP implementations](https://metallb.universe.tf/concepts/bgp/):

1. Native
2. FRR (provides BGP sessions with BFD support)

We will use the *FRR* implementation. We install it with the following command:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-frr.yaml
```

## Fabric verification

Coming to this step we have a configured IP Fabric and a ready k8s cluster.

The k8s test service (Nginx Echo Server) is not yet deployed, so our MetalLB BGP sessions between Leaves and kubernetes nodes are not established yet, but the BGP/EVPN sessions between Leaf and Spine switches should be working by now. We can verify that by checking the BGP related information on leaves and spines:

=== "Spine1 BGP Neighbors"
    BGP underlay sessions are configured with [unnumbered peering](https://documentation.nokia.com/srlinux/23-7/books/routing-protocols/bgp.html#bgp-unnumbered-peer) and 4 dynamic peers are seen from spine1 perspective.

    iBGP EVPN sessions are established between system IP interfaces forming 4 configured iBGP neighbors.
    ```srl
    A:spine1# show network-instance default protocols bgp neighbor
    ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    BGP neighbor summary for network-instance "default"
    Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
    ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    +--------------------+-----------------------------+--------------------+-------+-----------+----------------+----------------+--------------+-----------------------------+
    |      Net-Inst      |            Peer             |       Group        | Flags |  Peer-AS  |     State      |     Uptime     |   AFI/SAFI   |       [Rx/Active/Tx]        |
    +====================+=============================+====================+=======+===========+================+================+==============+=============================+
    | default            | 10.0.1.1                    | overlay            | S     | 64321     | established    | 0d:0h:0m:56s   | evpn         | [12/0/29]                   |
    | default            | 10.0.1.2                    | overlay            | S     | 64321     | established    | 0d:0h:0m:56s   | evpn         | [12/0/29]                   |
    | default            | 10.0.1.3                    | overlay            | S     | 64321     | established    | 0d:0h:0m:55s   | evpn         | [12/0/29]                   |
    | default            | 10.0.1.4                    | overlay            | S     | 64321     | established    | 0d:0h:0m:57s   | evpn         | [5/0/36]                    |
    | default            | fe80::1849:9ff:feff:31%ethe | leafs              | D     | 65003     | established    | 0d:0h:1m:2s    | ipv4-unicast | [2/1/4]                     |
    |                    | rnet-1/3.0                  |                    |       |           |                |                | ipv6-unicast | [2/1/4]                     |
    | default            | fe80::189b:aff:feff:31%ethe | leafs              | D     | 65004     | established    | 0d:0h:1m:3s    | ipv4-unicast | [2/1/4]                     |
    |                    | rnet-1/4.0                  |                    |       |           |                |                | ipv6-unicast | [2/1/4]                     |
    | default            | fe80::18a2:8ff:feff:31%ethe | leafs              | D     | 65002     | established    | 0d:0h:1m:2s    | ipv4-unicast | [2/1/4]                     |
    |                    | rnet-1/2.0                  |                    |       |           |                |                | ipv6-unicast | [2/1/4]                     |
    | default            | fe80::18aa:7ff:feff:31%ethe | leafs              | D     | 65001     | established    | 0d:0h:1m:2s    | ipv4-unicast | [2/1/4]                     |
    |                    | rnet-1/1.0                  |                    |       |           |                |                | ipv6-unicast | [2/1/4]                     |
    +--------------------+-----------------------------+--------------------+-------+-----------+----------------+----------------+--------------+-----------------------------+
    ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    Summary:
    4 configured neighbors, 4 configured sessions are established,0 disabled peers
    4 dynamic peers
    ```
    Great! All sessions are established and prefixes are exchanged.

=== "Leaf1 BGP Neighbors"
    We can also have a look at BGP sessions from the perspective of the leaf switch:

    ```srl
    A:leaf1# show network-instance default protocols bgp neighbor
    ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    BGP neighbor summary for network-instance "default"
    Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
    ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    +--------------------+-----------------------------+--------------------+-------+-----------+----------------+----------------+--------------+-----------------------------+
    |      Net-Inst      |            Peer             |       Group        | Flags |  Peer-AS  |     State      |     Uptime     |   AFI/SAFI   |       [Rx/Active/Tx]        |
    +====================+=============================+====================+=======+===========+================+================+==============+=============================+
    | default            | 10.1.0.1                    | overlay            | S     | 64321     | established    | 0d:0h:11m:49s  | evpn         | [26/26/12]                  |
    | default            | 10.1.0.2                    | overlay            | S     | 64321     | established    | 0d:0h:11m:42s  | evpn         | [26/0/12]                   |
    | default            | fe80::183a:cff:feff:1%ether | spines             | D     | 64601     | established    | 0d:0h:11m:54s  | ipv4-unicast | [4/4/5]                     |
    |                    | net-1/50.0                  |                    |       |           |                |                | ipv6-unicast | [4/4/5]                     |
    | default            | fe80::1866:bff:feff:1%ether | spines             | D     | 64601     | established    | 0d:0h:11m:55s  | ipv4-unicast | [4/4/2]                     |
    |                    | net-1/49.0                  |                    |       |           |                |                | ipv6-unicast | [4/4/2]                     |
    +--------------------+-----------------------------+--------------------+-------+-----------+----------------+----------------+--------------+-----------------------------+
    ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    Summary:
    2 configured neighbors, 2 configured sessions are established,0 disabled peers
    2 dynamic peers
    ```
    All looking good too.

=== "Leaf1 ip-vrf Route Table"
    K8s Cluster nodes and clients are connected to the `ip-vrf-1` network instance via respective mac-vrfs. Let's have a look at the routing table of this vrf:
    ```srl
      A:leaf1# show network-instance ip-vrf-1 route-table
      -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      IPv4 unicast route table of network instance ip-vrf-1
      -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      +-----------------------------+-------+------------+----------------------+----------------------+----------+---------+------------------+------------------+-----------------------+
      |           Prefix            |  ID   | Route Type |     Route Owner      |        Active        |  Origin  | Metric  |       Pref       | Next-hop (Type)  |  Next-hop Interface   |
      |                             |       |            |                      |                      | Network  |         |                  |                  |                       |
      |                             |       |            |                      |                      | Instance |         |                  |                  |                       |
      +=============================+=======+============+======================+======================+==========+=========+==================+==================+=======================+
      | 192.168.1.0/24              | 0     | bgp-evpn   | bgp_evpn_mgr         | False                | ip-vrf-1 | 0       | 170              | 10.0.1.2/32      |                       |
      |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
      |                             |       |            |                      |                      |          |         |                  | 10.0.1.3/32      |                       |
      |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
      | 192.168.1.0/24              | 8     | local      | net_inst_mgr         | True                 | ip-vrf-1 | 0       | 0                | 192.168.1.1      | irb1.1                |
      |                             |       |            |                      |                      |          |         |                  | (direct)         |                       |
      | 192.168.1.1/32              | 8     | host       | net_inst_mgr         | True                 | ip-vrf-1 | 0       | 0                | None (extract)   | None                  |
      | 192.168.1.11/32             | 8     | arp-nd     | arp_nd_mgr           | True                 | ip-vrf-1 | 0       | 1                | 192.168.1.11     | irb1.1                |
      |                             |       |            |                      |                      |          |         |                  | (direct)         |                       |
      | 192.168.1.12/32             | 0     | bgp-evpn   | bgp_evpn_mgr         | True                 | ip-vrf-1 | 0       | 170              | 10.0.1.2/32      |                       |
      |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
      | 192.168.1.13/32             | 0     | bgp-evpn   | bgp_evpn_mgr         | True                 | ip-vrf-1 | 0       | 170              | 10.0.1.3/32      |                       |
      |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
      | 192.168.1.255/32            | 8     | host       | net_inst_mgr         | True                 | ip-vrf-1 | 0       | 0                | None (broadcast) |                       |
      | 192.168.2.0/24              | 0     | bgp-evpn   | bgp_evpn_mgr         | False                | ip-vrf-1 | 0       | 170              | 10.0.1.2/32      |                       |
      |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
      |                             |       |            |                      |                      |          |         |                  | 10.0.1.3/32      |                       |
      |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
      |                             |       |            |                      |                      |          |         |                  | 10.0.1.4/32      |                       |
      |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
      | 192.168.2.0/24              | 9     | local      | net_inst_mgr         | True                 | ip-vrf-1 | 0       | 0                | 192.168.2.1      | irb1.2                |
      |                             |       |            |                      |                      |          |         |                  | (direct)         |                       |
      | 192.168.2.1/32              | 9     | host       | net_inst_mgr         | True                 | ip-vrf-1 | 0       | 0                | None (extract)   | None                  |
      | 192.168.2.255/32            | 9     | host       | net_inst_mgr         | True                 | ip-vrf-1 | 0       | 0                | None (broadcast) |                       |
      +-----------------------------+-------+------------+----------------------+----------------------+----------+---------+------------------+------------------+-----------------------+
      -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      IPv4 routes total                    : 11
      IPv4 prefixes with active routes     : 9
      IPv4 prefixes with active ECMP routes: 2
      -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ```
    Subnet `192.168.1.0/24`, where cluster nodes are connected is present as well as `192.168.2.0/24` subnet to which clients are connected. It was containerlab who connected both clients and cluster nodes with links to the leaves and configured IP addresses for those interfaces. Now we see these interfaces/subnets exchanged over EVPN and populated in the `ip-vrf-1` routing table.

=== "Leaf1 MetalLB BGP session"
    Let's have a look at the BGP session status between leaf1 and node1. This BGP session set up in the `ip-vrf-1` network instance is used to receive k8s services prefixes from MetalLB Load Balancer.

    ```srl
    A:leaf1# show network-instance ip-vrf-1 protocols bgp neighbor
    ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    BGP neighbor summary for network-instance "ip-vrf-1"
    Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
    ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    +--------------------+-----------------------------+--------------------+-------+-----------+----------------+----------------+--------------+-----------------------------+
    |      Net-Inst      |            Peer             |       Group        | Flags |  Peer-AS  |     State      |     Uptime     |   AFI/SAFI   |       [Rx/Active/Tx]        |
    +====================+=============================+====================+=======+===========+================+================+==============+=============================+
    | ip-vrf-1           | 192.168.1.11                | metal              | S     | 65535     | active         | -              |              |                             |
    +--------------------+-----------------------------+--------------------+-------+-----------+----------------+----------------+--------------+-----------------------------+
    ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    Summary:
    1 configured neighbors, 0 configured sessions are established,0 disabled peers
    0 dynamic peers
    ```

    As expected, the session is not yet established because MetalLB is not yet configured.

## MetalLB configuration

After we have verified that the IP Fabric is properly configured, it's time to configure MetalLB load balancer by creating a couple of resources from [metallb.yaml][metallb-cfg] file.

Let's look at those resources applicable to MetalLB:

### IP Address Pool

With [IPAddressPool resource](https://metallb.universe.tf/configuration/#defining-the-ips-to-assign-to-the-load-balancer-services) we instruct MetalLB which range of IP addresses we want to use when exposing k8s services to the fabric. In our case, we assign 100 IPv4 addresses

```yaml title="IPAddressPool: defines VIP address range used by MetalLB"
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: vip-pool
  namespace: metallb-system
spec:
  addresses:
  - 1.1.1.100-1.1.1.200
```

### BGP Peer

Another mandatory custom resource (CR) MetalLB requires is `BGPPeer`. With `BGPPeer` CR we configure the BGP speaker part of the load balancer. Namely, we set up the ASN numbers and peer address.

Leaf switches are configured with a distributed L3 EVPN service where the same anycast-gw IP address (192.168.1.1/24 for K8s nodes subnet and 192.168.2.1/24 for clients subnet) is used.

```yaml title="BGPPeer: BGP peer definition"
apiVersion: metallb.io/v1beta2
kind: BGPPeer
metadata:
  name: peer
  namespace: metallb-system
spec:
  myASN: 65535
  peerASN: 65535
  peerAddress: 192.168.1.1
```

As you can see, MetalLB configuration is static for all speakers, this is due to the anycast-gw peer address that is the same on all leaf switches.

Here is how the iBGP PE-CE session is configured on the leaves switch:

```srl
network-instance ip-vrf-1 {
    protocols {
        bgp {
            admin-state enable
            autonomous-system 65535
            router-id 192.168.1.1
            afi-safi ipv4-unicast {
                admin-state enable
            }
            preference { #(2)!
                ibgp 169
            }
            group metal {
                admin-state enable
                export-policy metal-export
                import-policy metal-import
                peer-as 65535
                afi-safi ipv4-unicast {
                    admin-state enable
                }
                local-as {
                    as-number 65535
                }
            }
            neighbor 192.168.1.11 { #(1)!
                admin-state enable
                peer-group metal
            }
        }
    }
}
```

1. neighbor address is different on leaf switches
2. see [fabric overlay verification](#fabric-overlay) for more details on the role of this preference

### BGP Advertisement

Finally, we need to instruct MetalLB to use the BGP mode. We do it with the `BGPAdvertisement` CR.

```yaml title="BGPAdvertisement: instructs MetalLB to use the BGP mode"
apiVersion: metallb.io/v1beta1
kind: BGPAdvertisement
metadata:
  name: bgpadv
  namespace: metallb-system
```

And now deploy them all with:

```bash
kubectl apply -f metallb.yaml
```

At the end of the day, the session is established between ip-vrf on leaves and MetalLB speakers on the nodes:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":2,"zoom":2.4,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/logical.drawio"}'></div>
</figure>

And finally we can see that the BGP session between MetalLB and our leaves is established:

```srl title="Leaf1 MetalLB BGP session status"
A:leaf1# show network-instance ip-vrf-1 protocols bgp neighbor * 
-------------------------------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "ip-vrf-1"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
-------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------
+---------------+----------------------+---------------+------+--------+-------------+-------------+-----------+----------------------+
|   Net-Inst    |         Peer         |     Group     | Flag | Peer-  |    State    |   Uptime    | AFI/SAFI  |    [Rx/Active/Tx]    |
|               |                      |               |  s   |   AS   |             |             |           |                      |
+===============+======================+===============+======+========+=============+=============+===========+======================+
| ip-vrf-1      | 192.168.1.11         | metal         | S    | 65535  | established | 0d:0h:0m:25 | ipv4-unic | [0/0/5]              |
|               |                      |               |      |        |             | s           | ast       |                      |
+---------------+----------------------+---------------+------+--------+-------------+-------------+-----------+----------------------+
-------------------------------------------------------------------------------------------------------------------------------------------
Summary:
1 configured neighbors, 1 configured sessions are established,0 disabled peers
0 dynamic peers
```

## K8s service deployment

The final touch is to deploy a test service in our k8s cluster and create a load balancer service for it. We will use the [Nginx Echo Server](https://hub.docker.com/r/nginxdemos/hello/) that responds with some pod information.

```yaml title="Deployment: HTTP echo service deployment"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginxhello
spec:
  replicas: 3 # (1)!
  selector:
    matchLabels:
      app: nginxhello
  template:
    metadata:
      labels:
        app: nginxhello
    spec:
      containers:
      - name: nginxhello
        image: nginxdemos/hello:plain-text # (2)!
        ports:
        - name: http
          containerPort: 80
```

1. Three pods will be deployed in our cluster
2. The Nginx hello image echoes back the name and IP address of the pod

We also create a k8s service of type LoadBalancer selecting the pods with the label `app: nginxhello` and exposing the service on port 80:

```yaml title="Service: exposing our nginxhello application"
apiVersion: v1
kind: Service
metadata:
  name: nginxhello
spec:
  ports:
  - name: http
    port: 80 # (1)!
    protocol: TCP
    targetPort: 80 # (2)!
  selector:
    app: nginxhello
  type: LoadBalancer
  externalTrafficPolicy: Cluster # (3)!
```

1. **port** exposes the Kubernetes service on the specified port within the cluster. Other pods within the cluster can communicate with this server on the specified port
2. **targetPort** is the port on which the service will send requests, that your pod will be listening on
3. Two possible configurations: **Local** or **Cluster**

    **Local** means that when the packet reaches a node, kube-proxy will only distribute the load within the same node

    **Cluster** means that when the packet reaches a node, kube-proxy will distribute the load to all the nodes comprising the service

Let's deploy it:

```bash
kubectl apply -f nginx.yaml
```

That's it! Now we have the IP fabric running and the service configured to be available outside of the cluster. Let's see how it all works.

## Verifications

### k8s resources

Before jumping into the details of control- and data-plane operation let's verify that it is good from the k8s standpoint.

=== "nodes"
    Checking that our three node cluster is doing great:
    ```
    # kubectl get nodes
    NAME           STATUS   ROLES           AGE   VERSION
    cluster1       Ready    control-plane   79m   v1.26.3
    cluster1-m02   Ready    <none>          78m   v1.26.3
    cluster1-m03   Ready    <none>          78m   v1.26.3
    ```

=== "pods"
    Checking that our replicated deployment of Nginx Echo Server is running and distributed across the cluster:
    ```
    # kubectl get pods -o wide
    NAME                         READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
    nginxhello-7d95548fc-7q44k   1/1     Running   0          18h   10.244.0.3   cluster1       <none>           <none>
    nginxhello-7d95548fc-lthz6   1/1     Running   0          18h   10.244.1.3   cluster1-m02   <none>           <none>
    nginxhello-7d95548fc-rhfth   1/1     Running   0          18h   10.244.2.3   cluster1-m03   <none>           <none>
    ```

=== "service"
    Checking that our LoadBalancer service is running and has an external IP address from the assigned range:
    ```
    # kubectl get svc
    NAME         TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
    kubernetes   ClusterIP      10.96.0.1        <none>        443/TCP        85m
    nginxhello   LoadBalancer   10.107.153.252   1.1.1.100     80:30608/TCP   51m
    ```

    We can make sure that the ClusterIP service that LoadBalancer is based on works, by running the following command a few times and see that the request is loadbalanced between the pods:

    ```
    # kubectl exec nginxhello-7d95548fc-7q44k -- curl -s 1.1.1.100
    Server address: 10.244.2.3:80
    Server name: nginxhello-7d95548fc-rhfth
    Date: 25/Aug/2023:15:01:28 +0000
    URI: /
    Request ID: 70183d16865d3fdae08165f00ede6d85
    ```

    !!!note
        Traffic internal to k8s cluster uses egress-based load-balancing and resolves the destination node IP address using the ClusterIP service. Given that our minikube cluster nodes have `eth0` interfaces connected to a docker network, traffic internal to cluster uses this network. Contrary to that, traffic external to the cluster uses the IP fabric.

=== "MetalLB speaker pods"
    At every node, MetalLB deploys a pod that runs the FRR to speak BGP to our leaves:
    ```
    # kubectl get pods -A | grep speaker
    metallb-system   speaker-4gcj8                      4/4     Running   0             56m
    metallb-system   speaker-bs2mq                      4/4     Running   0             56m
    metallb-system   speaker-cpdnj                      4/4     Running   0             55m
    ```

=== "MetalLB pod speaker FRR"
    We can connect to speakers FRR shell using `kubectl exec -it speaker-<pod-rand-name> --namespace=metallb-system -- vtysh`. Once connected, we can use FRR vtysh commands to verify FRR configuration.

    Below we are checking that FRR is announcing the VIP prefix its peer - leaf switch:
    ```bash
    cluster1# sh ip bgp neighbors 192.168.1.1 advertised-routes
    BGP table version is 1, local router ID is 192.168.49.2, vrf id 0
    Default local pref 100, local AS 65535
    Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
                  i internal, r RIB-failure, S Stale, R Removed
    Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
    Origin codes:  i - IGP, e - EGP, ? - incomplete
    RPKI validation codes: V valid, I invalid, N Not found

      Network          Next Hop            Metric LocPrf Weight Path
    *> 1.1.1.100/32     0.0.0.0                  0    100  32768 i

    Total number of prefixes 1
    ```

### Fabric overlay

We have [already verified](#bgp-advertisement) that once MetalLB is configured, leaf switches successfully establish BGP peering with MetalLB speakers. But now when the service is deployed we can see that leaves receive the VIP prefix from MetalLB:

=== "Leaf1 BGP peering with MetalLB"
    ```srl
    A:leaf1# show network-instance ip-vrf-1 protocols bgp neighbor
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    BGP neighbor summary for network-instance "ip-vrf-1"
    Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    +--------------------+-----------------------------+--------------------+-------+-----------+----------------+----------------+--------------+-----------------------------+
    |      Net-Inst      |            Peer             |       Group        | Flags |  Peer-AS  |     State      |     Uptime     |   AFI/SAFI   |       [Rx/Active/Tx]        |
    +====================+=============================+====================+=======+===========+================+================+==============+=============================+
    | ip-vrf-1           | 192.168.1.11                | metal              | S     | 65535     | established    | 0d:0h:1m:23s   | ipv4-unicast | [1/1/5]                     |
    +--------------------+-----------------------------+--------------------+-------+-----------+----------------+----------------+--------------+-----------------------------+
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    Summary:
    1 configured neighbors, 1 configured sessions are established,0 disabled peers
    0 dynamic peers
    ```

=== "Leaf1 vrf1 BGP received routes"
    We can see k8s node1 sends Leaf1 the `1.1.1.100` prefix. We can also expect the same output on leaf2 and leaf3.
    ```

    A:leaf1# show network-instance ip-vrf-1 protocols bgp neighbor 192.168.1.11 received-routes ipv4
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    Peer        : 192.168.1.11, remote AS: 65535, local AS: 65535
    Type        : static
    Description : None
    Group       : metal
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    Status codes: u=used, *=valid, >=best, x=stale
    Origin codes: i=IGP, e=EGP, ?=incomplete
    +-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
    |       Status                Network               Path-id              Next Hop                 MED                 LocPref               AsPath                Origin        |
    +===============================================================================================================================================================================+
    |         u*>           1.1.1.100/32          0                     192.168.1.11                   -                    100                                          i          |
    +-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    1 received BGP routes : 1 used 1 valid
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ```

Let's have a look how leaves install the VIP prefix in the `ip-vrf-1` routing table:

=== "Leaf1 vrf1 route table"
    The route table below shows that the VIP `1.1.1.100` has been learned from two sources:

    - from MetalLB via iBGP session in the `ip-vrf-1` network instance with the next-hop of the MetalLB BGP speaker.
    - from iBGP/EVPN neighbors - leaf2 and leaf3 - with next-hop corresponding to a remote leaf using VXLAN tunneling.

    Since both VIP prefixes have the same Preference and Metric, we influence the route selection by decreasing Preference for routes learned from MetalLB peer by [setting it to 169](https://github.com/srl-labs/srl-k8s-anycast-lab/blob/e2a9c2c7e773750a8c94a05c68cb964518b79845/configs/leaf1.conf#L235). That way the route learned from MetalLB peer will be preferred over the same route learned from EVPN peers. Consequently, the incoming traffic on a particular leaf will be forwarded to the local Pod instead of sending it over the network.

    !!!note
        In future SR Linux releases it will be possible to ECMP between PE-CE and EVPN routes, so that the traffic will be loadbalanced between the local and remote Pods.

    The same logic and route selection is applied to leaf2 and leaf3.

    ```srl
    A:leaf1# show network-instance ip-vrf-1 route-table
    ------------------------------------------------------------------------------------------------------------------------------------------------------
    IPv4 unicast route table of network instance ip-vrf-1
    ------------------------------------------------------------------------------------------------------------------------------------------------------
    +--------------------+------+-----------+--------------------+--------------------+---------+--------+-------------+-------------+--------------+
    |       Prefix       |  ID  |   Route   |    Route Owner     |       Active       | Origin  | Metric |    Pref     |  Next-hop   |   Next-hop   |
    |                    |      |   Type    |                    |                    | Network |        |             |   (Type)    |  Interface   |
    |                    |      |           |                    |                    | Instanc |        |             |             |              |
    |                    |      |           |                    |                    |    e    |        |             |             |              |
    +====================+======+===========+====================+====================+=========+========+=============+=============+==============+
    | 1.1.1.100/32       | 0    | bgp       | bgp_mgr            | True               | ip-     | 0      | 169         | 192.168.1.0 | irb1.1       |
    |                    |      |           |                    |                    | vrf-1   |        |             | /24 (indire |              |
    |                    |      |           |                    |                    |         |        |             | ct/local)   |              |
    | 1.1.1.100/32       | 0    | bgp-evpn  | bgp_evpn_mgr       | False              | ip-     | 0      | 170         | 10.0.1.2/32 |              |
    |                    |      |           |                    |                    | vrf-1   |        |             | (indirect/v |              |
    |                    |      |           |                    |                    |         |        |             | xlan)       |              |
    |                    |      |           |                    |                    |         |        |             | 10.0.1.3/32 |              |
    |                    |      |           |                    |                    |         |        |             | (indirect/v |              |
    |                    |      |           |                    |                    |         |        |             | xlan)       |              |
    # ... truncated
    |                    |      |           |                    |                    | vrf-1   |        |             | (broadcast) |              |
    +--------------------+------+-----------+--------------------+--------------------+---------+--------+-------------+-------------+--------------+
    ------------------------------------------------------------------------------------------------------------------------------------------------------
    IPv4 routes total                    : 13
    IPv4 prefixes with active routes     : 10
    IPv4 prefixes with active ECMP routes: 3
    ------------------------------------------------------------------------------------------------------------------------------------------------------
    ```

=== "Leaf1 VIP prefix details"

    Using the below command we can see the details for a prefix installed in the Route Table. There we can confirm that the next-hop belongs to the MetalLB speaker pod and it is resolved via `irb1.1` interface.

    ```srl
    A:leaf1# show  network-instance ip-vrf-1 route-table ipv4-unicast prefix 1.1.1.100/32 detail
    -------------------------------------------------------------------------------------------
    IPv4 unicast route table of network instance ip-vrf-1
    -------------------------------------------------------------------------------------------
    Destination            : 1.1.1.100/32
    ID                     : 0
    Route Type             : bgp
    Route Owner            : bgp_mgr
    Origin Network Instance: ip-vrf-1
    Metric                 : 0
    Preference             : 169
    Active                 : true
    Last change            : 2023-08-25T14:28:54.782Z
    Resilient hash         : false
    -------------------------------------------------------------------------------------------
    Next hops: 1 entries
    192.168.1.11 (indirect) resolved by route to 192.168.1.0/24 (local)
    via 192.168.1.1 (direct) via [irb1.1]
    # truncated
    ```

=== "Leaf4 vrf1 route table"
    While leaves 1,2 and 3 have similar service configuration and hence the same routing table, leaf4 is different. Leaf4 doesn't have k8s node connected to it and hence it doesn't have local peering with MetalLB load balancer.

    Still, thanks to leaf4 participation in the EVPN service the VIP `1.1.1.100` is installed in leaf4 route table as an ECMP prefix with three possible next-hops: leaf1, leaf2 and leaf3

    ```srl
    A:leaf4# show network-instance ip-vrf-1 route-table
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    IPv4 unicast route table of network instance ip-vrf-1
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    +-----------------------------+-------+------------+----------------------+----------------------+----------+---------+------------------+------------------+-----------------------+
    |           Prefix            |  ID   | Route Type |     Route Owner      |        Active        |  Origin  | Metric  |       Pref       | Next-hop (Type)  |  Next-hop Interface   |
    |                             |       |            |                      |                      | Network  |         |                  |                  |                       |
    |                             |       |            |                      |                      | Instance |         |                  |                  |                       |
    +=============================+=======+============+======================+======================+==========+=========+==================+==================+=======================+
    | 1.1.1.100/32                | 0     | bgp-evpn   | bgp_evpn_mgr         | True                 | ip-vrf-1 | 0       | 170              | 10.0.1.1/32      |                       |
    |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
    |                             |       |            |                      |                      |          |         |                  | 10.0.1.2/32      |                       |
    |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
    |                             |       |            |                      |                      |          |         |                  | 10.0.1.3/32      |                       |
    |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
    # truncated
    +-----------------------------+-------+------------+----------------------+----------------------+----------+---------+------------------+------------------+-----------------------+
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    IPv4 routes total                    : 9
    IPv4 prefixes with active routes     : 8
    IPv4 prefixes with active ECMP routes: 3
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    ```

What we conclude from the verifications done so far is that:

* leaf1/leaf2/leaf3 install the route to the VIP `1.1.1.100` with the next-hop of the locally connected k8s node.
* leaf4, which is not connected to a kubernetes node, only to a client, installs the route to `1.1.1.100` pointing to the three switches where k8s nodes are connected. Traffic will be encapsulated in VXLAN, forwarded to any of the three VTEPs and finally delivered to the k8s node.

With this setup, it is expected that the traffic to `1.1.1.100` from clients connected to leaf1/leaf2/leaf3 will be delivered to the local k8s node.

In the case of clients connected to leaf4, the switch will load-balance traffic between the three k8s nodes.

## Using LoadBalancer service

And now we reach a point where we can try out our LoadBalancer service by issuing HTTP requests from external clients to the NGINX Echo service Pods.

We use the following command to connect to our clients: `client1`, `client2`, `client3` and `client4`:

```bash
docker exec -it client1 bash
```

First let's review again where nginx pods are located so that we identify which pod will serve requests from clients:

```
# kubectl get pods -o wide
NAME                         READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
nginxhello-7d95548fc-7q44k   1/1     Running   0          31h   10.244.0.3   cluster1       <none>           <none>
nginxhello-7d95548fc-lthz6   1/1     Running   0          31h   10.244.1.3   cluster1-m02   <none>           <none>
nginxhello-7d95548fc-rhfth   1/1     Running   0          31h   10.244.2.3   cluster1-m03   <none>           <none>
```

Then let's issue a curl request from our clients to the VIP and see which pod responds. Sometimes it takes a few requests to see the load-balancing in action.

=== "client1"
    From client1, connected to leaf1, we try to reach the VIP:
    ```
    root@client1:/ $ curl 1.1.1.100
    Server address: 10.244.0.3:80
    Server name: nginxhello-7d95548fc-7q44k
    Date: 26/Aug/2023:22:28:39 +0000
    URI: /
    Request ID: 96d2a109b8a615e30c0b7f63b866ff84

    root@client1:/ $ curl 1.1.1.100
    Server address: 10.244.1.3:80
    Server name: nginxhello-7d95548fc-lthz6
    Date: 26/Aug/2023:22:28:33 +0000
    URI: /
    Request ID: 0abd422ff9d0ad625fa9cfe328a83c22
    ```
    we can see our traffic has been load balanced to pods on nodes `cluster1` and `cluster1-m02`.

=== "client2"
    From client2, connected to leaf2, we try to reach the VIP:
    ```
    root@client2:/ $ curl 1.1.1.100
    Server address: 10.244.1.3:80
    Server name: nginxhello-7d95548fc-lthz6
    Date: 26/Aug/2023:22:30:13 +0000
    URI: /
    Request ID: 72b5009ff2262fb33e4c4c6387d8a558

    root@client2:/ $ curl 1.1.1.100
    Server address: 10.244.1.3:80
    Server name: nginxhello-7d95548fc-lthz6
    Date: 26/Aug/2023:22:30:16 +0000
    URI: /
    Request ID: b3edeb76da1cf6769c5e1ed378b74a99

    root@client2:/ $ curl 1.1.1.100
    Server address: 10.244.0.3:80
    Server name: nginxhello-7d95548fc-7q44k
    Date: 26/Aug/2023:22:30:17 +0000
    URI: /
    Request ID: b90bf4f35d2faf08db6724c6d837da21
    ```
    It took 3 requests to see a different pod serving our request, anyhow we again see cluster1 and cluster1-m02 nodes serving our requests. Issuing more requests eventually shows that all three pods are serving our requests.

=== "client4"
    From client4, connected to leaf4, we also reach the VIP and can see our traffic load balanced to node2 and node3
    ```
    root@client4:/ $ curl 1.1.1.100
    Server address: 10.244.2.3:80
    Server name: nginxhello-7d95548fc-rhfth
    Date: 26/Aug/2023:22:32:24 +0000
    URI: /
    Request ID: 84b148dc1463c581aa9d3a68f66ee16d

    root@client4:/ $ curl 1.1.1.100
    Server address: 10.244.0.3:80
    Server name: nginxhello-7d95548fc-7q44k
    Date: 26/Aug/2023:22:32:27 +0000
    URI: /
    Request ID: fd9ed8cacd1c3146c1ddad4aefc7dc99
    ```

Great, we have verified that our service is working as expected. External clients can reach the exposed service and it is load balanced across our fabric and served by a scaled-out application.

## K8s Cluster Load Balancing

From the previous tests we can confirm that, independently where requests are coming from, all connections from clients are spread over the three pods.

We can easily explain how traffic from `client4` is load balanced over the three nodes: leaf4 has three possible next-hops to reach the VIP prefix, so it will ECMP the traffic between the three nodes.

But how is it possible that traffic from `client1`, `client2` and `client3` is also load balanced, when we [specifically set preference](#__tabbed_4_1) for locally learned prefix to be preferred and therefore the requests coming to leafX should only be served by nodeX?

The explanation is simple, we have already seen it in the Kubernetes service definition. **kube-proxy**, thanks to the [`externalTrafficPolicy: Cluster`](https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer/#preserving-the-client-source-ip) configuration (default value), will load balance the traffic between the service endpoints:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/cluster-load-balancing-Cluster.drawio"}'></div>
</figure>

Notice how kube-proxy now uses source and destination NAT to distribute this traffic.

If we had configured `externalTrafficPolicy: Local`,  then `client1`, `client2` and `client3` traffic to VIP would only reach its locally connected cluster node:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":1,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/cluster-load-balancing-Cluster.drawio"}'></div>
</figure>

With the `Local` policy, kube-proxy does not modify the source IP address.

!!!tip
    Minikube-flavored default Kubernetes installation uses iptables rules to perform these src/dst NAT policies. You can check this in kubernetes nodes with `iptables -vnL -t nat` command.

## Network Load Balancing

We have just seen how Kubernetes manages load balancing for external traffic hitting its LoadBalancer service. When it comes to the network switches, the key ingredient for load balancing is ECMP (Equal-Cost Multipath). ECMP allows a router to distribute traffic across multiple paths with equal routing costs, improving network efficiency and fault tolerance.

SR Linux load-balances egressing VXLAN traffic over multiple equal-cost links/next-hops with a hashing algorithm that uses header fields in tenant packets to calculate which link/next-hop to use.

The goal of the hash computation is to keep packets in the same flow on the same network path while distributing traffic proportionally across the ECMP next-hops so that each of the N ECMP next-hops carries approximately 1/Nth of the load.

Classic ECMP hashing is susceptible to changes in the ECMP set; if, for example, one of the cluster nodes fails, the hashing will change and the switch may select a different next-hop for the same destination. Consider the case when client4 is sending traffic to the VIP prefix consuming the service. Leaf4 will ECMP the traffic between the three nodes. If one of the nodes fails, the hashing will change and the switch may select a different next-hop for the same destination. This may lead to traffic switchover and the client will have to re-establish the connection.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/ecmp_hash.drawio"}'></div>
  <figcaption>Hash recalculation may lead to traffic switchover</figcaption>
</figure>

SR Linux provides a way to minimize the number of flows that are moved when the size of the ECMP set changes. This feature is called **Resilient Hashing**[^2]. When a next-hop is removed only flows that were previously hashed to that next-hop are moved.

To configure resilient hashing, you have to provide the prefix and two parameters:

* `hash-buckets-per-path`: the number of times each next-hop is repeated in the hash-bucket fill pattern
* `max-paths`: the maximum number of ECMP next-hops per route associated with the resilient-hash prefix

The idea behind **Resilient Hashing** is that we pre-calculate the hashes in buckets so that in case the ECMP set changes, we don't redistribute the flows.

```srl title="Resilient Hashing configuration"
set network-instance ip-vrf-1 ip-load-balancing resilient-hash-prefix 1.1.1.100/32 max-paths 6 hash-buckets-per-path 4
```

We can apply and remove this configuration to leaf4 and see how it affects traffic flow distribution to traffic generated from `client4`.

## Unleash automation

While going through the steps of this lab, you may have noticed that there is a lot of manual configuration involved both in the IP fabric and in the k8s cluster. We did it swiftly in a lab environment, but in a production environment, separate teams usually perform configuration of the network and the application infrastructure.

An experienced operations engineer could smell potential misalignments between the two teams and the possibility of human errors. A BGP peering might not be established, a route might not be installed, a FIB might be exhausted. The list of things that can go wrong is long and typically it is because network doesn't know about applications it supports.

The solution to this problem is to make network aware of the application infrastructure it serves. This is where [SR Linux NDK](../../../ndk/index.md) comes into play. NDK allows you to write applications that can be deployed on SR Linux nodes and that can interact with SR Linux itself as well as with any external system.

A good demonstration of NDK capabilities in the context of k8s applications is the [kButler application](../../../ndk/apps/kbutler.md) that provides enhanced visibility and correlation between k8s services and NOS internal state. It is a good example of how to use NDK to automate the configuration of the network infrastructure based on the application requirements.

## Summary

What a journey it has been! We've seen how to deploy a local virtual k8s cluster with minikube and connect it with an IP fabric deployed with containerlab.

With both container orchestration and network infrastructure in place, we deployed a simple Nginx echo service in a distributed fashion. We learned how to expose that service to external clients using a LoadBalancer service and announce it to external BGP peers using MetalLB.

We witnessed the simplification of the network configuration thanks to the use of EVPN with Anycast-GW and BGP unnumbered. Finally, we verified that traffic from external clients performs load balancing across the cluster nodes both when clients are connected to the same leaf as the k8s node and when they are connected to a different leaf.

As a bonus we also saw how to configure resilient hashing to minimize the number of flows that are moved when the size of the ECMP set changes.

## TL;DR

Here is a quick summary of the steps to reproduce this lab from start to finish:

```bash title="quick summary"
git clone https://github.com/srl-labs/srl-k8s-anycast-lab && cd srl-k8s-anycast-lab
minikube start --nodes 3 -p cluster1
sudo clab deploy
minikube addons enable metallb -p cluster1
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-frr.yaml
kubectl apply -f metallb.yaml
kubectl apply -f nginx.yaml
docker exec -it client4 curl 1.1.1.100
```

## Lab lifecycle

To delete this lab:

1. Destroy Containerlab topology: `clab destroy --topo srl-k8s-lab.clab.yml`
2. Delete Minikube node: `minikube delete --all`

[mr-linkedin]: https://linkedin.com/in/michelredondo
[lab]: https://github.com/srl-labs/srl-k8s-anycast-lab
[clab-topo]: https://github.com/srl-labs/srl-k8s-anycast-lab/blob/main/srl-k8s-lab.clab.yml
[clab-configs]: https://github.com/srl-labs/srl-k8s-anycast-lab/tree/main/configs
[metallb-cfg]: https://github.com/srl-labs/srl-k8s-anycast-lab/blob/main/metallb.yaml

[^1]: See https://datatracker.ietf.org/doc/html/rfc7938
[^2]: Also known as [consistent hashing](https://datatracker.ietf.org/doc/html/rfc7938#section-6.4).
[^3]: As of SR Linux 23.7.1, support of EVPN over BGP unnumbered overlay is in a preview state.

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
