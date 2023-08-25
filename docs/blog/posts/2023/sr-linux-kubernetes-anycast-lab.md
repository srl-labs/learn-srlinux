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
---

# SR Linux Kubernetes Anycast Lab

In the era of applications, it is easy to forget about the underlying infrastructure that interconnects them. However, the network is still the foundation of any application as it provides the connectivity and services that applications rely on.

The most popular container orchestration system - Kubernetes - is no exception to this rule where infrastructure is essential for several reasons:

1. **DC fabric**: Almost every k8s cluster leverages a DC fabric underneath to interconnect worker nodes.
2. **Communication Between Services**: Kubernetes applications are often composed of multiple microservices that need to communicate with each other. A well-designed network infrastructure ensures reliable and efficient communication between these services, contributing to overall application performance.
3. **Load Balancing**: Kubernetes distributes incoming traffic across multiple instances of an application for improved availability and responsiveness. A robust network setup provides load balancing capabilities, preventing overload on specific instances and maintaining a smooth user experience.
4. **Scalability and Resilience**: Kubernetes is renowned for scaling applications up or down based on demand. A resilient network infrastructure supports this scalability by efficiently routing traffic and maintaining service availability even during high traffic periods.

Getting familiar with all these features is vital for any network engineer working with a fabric supporting a k8s cluster. Wouldn't it be great to have a way to get into all of this without the need of a physical lab?

In this blog post we will dive into a lab topology that serves as a virtual environment to test the integration of a Kubernetes cluster with an IP fabric. The emulated fabric topology consists of a Leaf/Spine [SR Linux](https://learn.srlinux.dev/) nodes with the Kubernetes Cluster nodes connected to it. The k8s Cluster features a [MetalLB](https://metallb.universe.tf/) load-balancer that unlocks the capability of having anycast services deployed in our fabric.

With [Minikube](https://minikube.sigs.k8s.io/) we will deploy a personal virtual k8s cluster and [Containerlab](https://containerlab.dev/) will handle the IP fabric emulation and the connection between both environments.

<!-- more -->

## Lab summary

| Summary                   |                                                                                                                                                                                                 |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Lab name**              | SR Linux Kubernetes Anycast Lab                                                                                                                                                                 |
| **Lab components**        | Nokia SR Linux, Kubernetes, MetalLB                                                                                                                                                             |
| **Resource requirements** | :fontawesome-solid-microchip: 6 vCPU <br/>:fontawesome-solid-memory: 16 GB                                                                                                                      |
| **Lab**                   | [srl-labs/srl-k8s-anycast-lab][lab]                                                                                                                                                             |
| **Version information**   | [`containerlab:0.44.3`](https://containerlab.dev/install/), [`srlinux:23.7.1`](https://github.com/nokia/srlinux-container-image),[`minikube v1.30.1`](https://minikube.sigs.k8s.io/docs/start/) |
| **Authors**               | Míchel Redondo [:material-linkedin:][mr-linkedin]                                                                                                                                               |

At the end of this blog post you can find a [quick summary](#tldr-version) of the steps performed to deploy the lab and configure the use cases.

## Prerequisites

The following tools are required to be installed to run the lab on any Linux host. The links will get you to the installation instructions.

* The lab leverages [Containerlab](https://containerlab.dev/install/) to spin up a Leaf/Spine Fabric coupled with [Minikube](https://minikube.sigs.k8s.io/docs/start/) to deploy the Kubernetes cluster.
* [Docker engine](https://docs.docker.com/engine/install/) to power containerlab.
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) CLI client is also required to interact with the k8s cluster.

## Lab description

### Topology

The goal of this lab is to provide users with an environment to test the network integration of a Kubernetes cluster with a Leaf/Spine SR Linux fabric.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/topology.drawio"}'></div>
  <figcaption>Topology</figcaption>
</figure>

The setup consists of:

* A Leaf/Spine Fabric: 2xSpines, 4xLeaf switches
* Minikube kubernetes cluster with MetalLB load balancing implementation (3 nodes)
* Kubernetes service deployed on top of Cluster
* Linux clients to simulate connections to k8s service (4 clients)

Courtesy of MetalLB, Kubernetes nodes establish BGP sessions with Leaf switches. Through the BGP sessions the IP addresses of the exposed services (loadBalancerIPs, commonly known as Virtual IPs or VIPs for short) are announced to the IP fabric.

### Kubernetes Service

To illustrate the integration between the workloads running in the k8s cluster and the IP fabric, we will deploy a simple NGINX server replicated across the three k8s nodes. A MetalLB-based [LoadBalancer](https://tkng.io/services/loadbalancer/) service is created to expose the NGINX instances to the fabric and the outside world.

With simulated clients, we will verify how traffic is distributed among the different nodes/pods using `curl` and reaching over to the exposed service IP address.

### Underlay Networking

The [eBGP unnumbered peering](https://documentation.nokia.com/srlinux/23-7/books/routing-protocols/bgp.html#bgp-unnumbered-peer) makes the core of our IP fabric. Each leaf switch is configured with a unique ASN, whereas all spines share the same ASN, which is a common practice in Leaf/Spine fabrics:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/fabric_ebgp.drawio"}'></div>
  <figcaption>Underlay IPv6 Link Local eBGP sessions</figcaption>
</figure>

Through eBGP the loopback/system IP addresses are exchanged between the leaves, making it possible to setup iBGP sessions for the overlay EVPN services that are consumed by the k8s nodes and clients:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/fabric_ibgp.drawio"}'></div>
  <figcaption>Overlay iBGP EVPN sessions</figcaption>
</figure>

### Overlay Networking

To enable network connectivity between the nodes of the k8s cluster we create a routed network - `ip-vrf-1` - implemented as a distributed L3 EVPN service running on the leaf switches. Two subnets are configured for this network to interconnect k8s nodes and emulated clients:

* k8s nodes subnet: 192.168.1.0/24
* clients subnet: 192.168.2.0/24

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/logical.drawio"}'></div>
  <figcaption>Logical network topology</figcaption>
</figure>

Subnets are configured with Integrated Routing and Bridging (IRB) interfaces serving as default gateways for the k8s nodes and clients. The IRB interfaces are configured with the same IP address and MAC address across all leaf switches. This configuration is known as [Anycast Gateway](https://documentation.nokia.com/srlinux/23-7/books/evpn-vxlan/evpn-vxlan-tunnels-layer-3.html#anycast-gateways) that avoids inefficiencies for all-active multi-homing and speeds up convergence for host mobility.

From the SR Linux configuration perspective, each leaf would have the following network instances created jointly implementing the L3 EVPN service:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":1,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/logical.drawio"}'></div>
  <figcaption>Network instances composition</figcaption>
</figure>

Kubernetes nodes, thanks to MetalLB, will establish BGP sessions to these anycast-GW IP addresses and advertise the IP addresses of the exposed k8s services.

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

We will use the [SR linux image v23.7.1](https://github.com/nokia/srlinux-container-image) that can be pulled as easily as `docker pull ghcr.io/nokia/srlinux:23.7.1`.

Our emulated clients will be deployed from the [network-multitool](https://github.com/users/hellt/packages/container/package/network-multitool) versatile Linux image.

Kubernetes container images and container creation are directly managed by Minikube.

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

1. Minikube will name k8s container nodes as `minikube` by default. We set minikube's `profile` option to `cluster1` that sets cluster's first node name to `cluster1`, second `cluster1-m02` and `cluster-m03` for the third node.
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
    Let's have a look at the BGP session status between leaf1 and node1. This BGP session set up in the ip-vrf-1 network instance is used to receive k8s services prefixes from MetalLB Load Balancer.

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

After we have verified that the IP Fabric is properly configured, it's time to configure MetalLB loadbalancer by creating a couple of resources from [metallb.yaml][metallb-cfg] file.

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

Another mandatory custom resource (CR) MetalLB requires is `BGPPeer`. With `BGPPeer` CR we configure the BGP speaker part of the loadbalancer. Namely we set up the ASN numbers and peer address.

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

The final touch is to deploy a test service in our k8s cluster and create a loadbalancer service for it. We will use the [Nginx Echo Server](https://hub.docker.com/r/nginxdemos/hello/) that responses with some pod information.

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
2. **targetPort** is the port on which the service will send requests to, that your pod will be listening on
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
    NAME                          READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
    nginxhello-6b97fd8857-4vp6z   1/1     Running   0          81m   10.244.0.3   cluster1       <none>           <none>
    nginxhello-6b97fd8857-b2vf8   1/1     Running   0          81m   10.244.2.3   cluster1-m03   <none>           <none>
    nginxhello-6b97fd8857-f2ggp   1/1     Running   0          81m   10.244.1.3   cluster1-m02   <none>           <none>
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
    # kubectl exec nginxhello-7d95548fc-7q44k -- curl -s 10.102.93.1
    Server address: 10.244.2.3:80
    Server name: nginxhello-7d95548fc-rhfth
    Date: 25/Aug/2023:15:01:28 +0000
    URI: /
    Request ID: 70183d16865d3fdae08165f00ede6d85
    ```

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

We have already verified the underlay Fabric and Kubernetes Cluster in the previous steps, now that we have the Echo service ready, the BGP sessions between Leaf switches and k8s nodes should be established:

=== "Leaf1 vrf1 MetalLB BGP session"
    We check the MetalLB BGP session between the Leaf1 switch and the k8s Node1:
    ```
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
    As expected, the session is now established and k8s node1 is announcing one prefix

=== "Leaf2 vrf1 MetalLB BGP session"
    We check the MetalLB BGP session between the Leaf2 switch and the k8s Node2:
    ```
    A:leaf2# show network-instance ip-vrf-1 protocols bgp neighbor
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    BGP neighbor summary for network-instance "ip-vrf-1"
    Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    +--------------------+-----------------------------+--------------------+-------+-----------+----------------+----------------+--------------+-----------------------------+
    |      Net-Inst      |            Peer             |       Group        | Flags |  Peer-AS  |     State      |     Uptime     |   AFI/SAFI   |       [Rx/Active/Tx]        |
    +====================+=============================+====================+=======+===========+================+================+==============+=============================+
    | ip-vrf-1           | 192.168.1.12                | metal              | S     | 65535     | established    | 0d:0h:3m:50s   | ipv4-unicast | [1/1/5]                     |
    +--------------------+-----------------------------+--------------------+-------+-----------+----------------+----------------+--------------+-----------------------------+
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    Summary:
    1 configured neighbors, 1 configured sessions are established,0 disabled peers
    0 dynamic peers

    ```
    As expected, the session is now established and k8s node2 is announcing one prefix

=== "Leaf3 vrf1 MetalLB BGP session"
    We check the MetalLB BGP session between the Leaf3 switch and the k8s Node3:
    ```
    A:leaf3# show network-instance ip-vrf-1 protocols bgp neighbor
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    BGP neighbor summary for network-instance "ip-vrf-1"
    Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    +--------------------+-----------------------------+--------------------+-------+-----------+----------------+----------------+--------------+-----------------------------+
    |      Net-Inst      |            Peer             |       Group        | Flags |  Peer-AS  |     State      |     Uptime     |   AFI/SAFI   |       [Rx/Active/Tx]        |
    +====================+=============================+====================+=======+===========+================+================+==============+=============================+
    | ip-vrf-1           | 192.168.1.13                | metal              | S     | 65535     | established    | 0d:0h:5m:34s   | ipv4-unicast | [1/1/5]                     |
    +--------------------+-----------------------------+--------------------+-------+-----------+----------------+----------------+--------------+-----------------------------+
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    Summary:
    1 configured neighbors, 1 configured sessions are established,0 disabled peers
    0 dynamic peers
    ```
    As expected, the session is now established and k8s node3 is announcing one prefix

We have reviewed that MetalLB sessions are established. Now we can check the contents of the route tables and MetalLB BGP sessions:

=== "Leaf1 vrf1 MetalLB BGP prefix"
    We can see k8s node1 sends Leaf1 the `1.1.1.100` prefix. We can also expect the same output in leaf2 and leaf3.
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

=== "Leaf1 vrf1 route table"
    We can see that VIP `1.1.1.100` is installed in our route table, with the next-hop of the direcly connected k8s node1 eth1 interface.

    We can also see that in Leaf1 we receive 1.1.1.100 prefixes from leaf2 and leaf3. These routes are not installed because we prefer locally received bgp prefixes over over bgp-evpn ones. We force this behavior by lowering the preference of local BGP session to 169 (170 is the default preference). 

    The same result is expected if leaf2 and leaf3. Locally learned MetalLB prefix is installed.
    ```
    
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
    | 192.168.1.0/24     | 0    | bgp-evpn  | bgp_evpn_mgr       | False              | ip-     | 0      | 170         | 10.0.1.2/32 |              |
    |                    |      |           |                    |                    | vrf-1   |        |             | (indirect/v |              |
    |                    |      |           |                    |                    |         |        |             | xlan)       |              |
    |                    |      |           |                    |                    |         |        |             | 10.0.1.3/32 |              |
    |                    |      |           |                    |                    |         |        |             | (indirect/v |              |
    |                    |      |           |                    |                    |         |        |             | xlan)       |              |
    | 192.168.1.0/24     | 8    | local     | net_inst_mgr       | True               | ip-     | 0      | 0           | 192.168.1.1 | irb1.1       |
    |                    |      |           |                    |                    | vrf-1   |        |             | (direct)    |              |
    | 192.168.1.1/32     | 8    | host      | net_inst_mgr       | True               | ip-     | 0      | 0           | None        | None         |
    |                    |      |           |                    |                    | vrf-1   |        |             | (extract)   |              |
    | 192.168.1.11/32    | 8    | arp-nd    | arp_nd_mgr         | True               | ip-     | 0      | 1           | 192.168.1.1 | irb1.1       |
    |                    |      |           |                    |                    | vrf-1   |        |             | 1 (direct)  |              |
    | 192.168.1.12/32    | 0    | bgp-evpn  | bgp_evpn_mgr       | True               | ip-     | 0      | 170         | 10.0.1.2/32 |              |
    |                    |      |           |                    |                    | vrf-1   |        |             | (indirect/v |              |
    |                    |      |           |                    |                    |         |        |             | xlan)       |              |
    | 192.168.1.13/32    | 0    | bgp-evpn  | bgp_evpn_mgr       | True               | ip-     | 0      | 170         | 10.0.1.3/32 |              |
    |                    |      |           |                    |                    | vrf-1   |        |             | (indirect/v |              |
    |                    |      |           |                    |                    |         |        |             | xlan)       |              |
    | 192.168.1.255/32   | 8    | host      | net_inst_mgr       | True               | ip-     | 0      | 0           | None        |              |
    |                    |      |           |                    |                    | vrf-1   |        |             | (broadcast) |              |
    | 192.168.2.0/24     | 0    | bgp-evpn  | bgp_evpn_mgr       | False              | ip-     | 0      | 170         | 10.0.1.2/32 |              |
    |                    |      |           |                    |                    | vrf-1   |        |             | (indirect/v |              |
    |                    |      |           |                    |                    |         |        |             | xlan)       |              |
    |                    |      |           |                    |                    |         |        |             | 10.0.1.3/32 |              |
    |                    |      |           |                    |                    |         |        |             | (indirect/v |              |
    |                    |      |           |                    |                    |         |        |             | xlan)       |              |
    |                    |      |           |                    |                    |         |        |             | 10.0.1.4/32 |              |
    |                    |      |           |                    |                    |         |        |             | (indirect/v |              |
    |                    |      |           |                    |                    |         |        |             | xlan)       |              |
    | 192.168.2.0/24     | 9    | local     | net_inst_mgr       | True               | ip-     | 0      | 0           | 192.168.2.1 | irb1.2       |
    |                    |      |           |                    |                    | vrf-1   |        |             | (direct)    |              |
    | 192.168.2.1/32     | 9    | host      | net_inst_mgr       | True               | ip-     | 0      | 0           | None        | None         |
    |                    |      |           |                    |                    | vrf-1   |        |             | (extract)   |              |
    | 192.168.2.255/32   | 9    | host      | net_inst_mgr       | True               | ip-     | 0      | 0           | None        |              |
    |                    |      |           |                    |                    | vrf-1   |        |             | (broadcast) |              |
    +--------------------+------+-----------+--------------------+--------------------+---------+--------+-------------+-------------+--------------+
    ------------------------------------------------------------------------------------------------------------------------------------------------------
    IPv4 routes total                    : 13
    IPv4 prefixes with active routes     : 10
    IPv4 prefixes with active ECMP routes: 3
    ------------------------------------------------------------------------------------------------------------------------------------------------------

    ```

=== "Leaf4 vrf1 route table"
    We can see that VIP `1.1.1.100` is installed in leaf4 route table as an ECMP prefix with three possible next-hops: leaf1, leaf2 and leaf3
    ```
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
    | 192.168.1.0/24              | 0     | bgp-evpn   | bgp_evpn_mgr         | True                 | ip-vrf-1 | 0       | 170              | 10.0.1.1/32      |                       |
    |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
    |                             |       |            |                      |                      |          |         |                  | 10.0.1.2/32      |                       |
    |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
    |                             |       |            |                      |                      |          |         |                  | 10.0.1.3/32      |                       |
    |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
    | 192.168.1.11/32             | 0     | bgp-evpn   | bgp_evpn_mgr         | True                 | ip-vrf-1 | 0       | 170              | 10.0.1.1/32      |                       |
    |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
    | 192.168.1.12/32             | 0     | bgp-evpn   | bgp_evpn_mgr         | True                 | ip-vrf-1 | 0       | 170              | 10.0.1.2/32      |                       |
    |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
    | 192.168.1.13/32             | 0     | bgp-evpn   | bgp_evpn_mgr         | True                 | ip-vrf-1 | 0       | 170              | 10.0.1.3/32      |                       |
    |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
    | 192.168.2.0/24              | 0     | bgp-evpn   | bgp_evpn_mgr         | False                | ip-vrf-1 | 0       | 170              | 10.0.1.1/32      |                       |
    |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
    |                             |       |            |                      |                      |          |         |                  | 10.0.1.2/32      |                       |
    |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
    |                             |       |            |                      |                      |          |         |                  | 10.0.1.3/32      |                       |
    |                             |       |            |                      |                      |          |         |                  | (indirect/vxlan) |                       |
    | 192.168.2.0/24              | 6     | local      | net_inst_mgr         | True                 | ip-vrf-1 | 0       | 0                | 192.168.2.1      | irb1.2                |
    |                             |       |            |                      |                      |          |         |                  | (direct)         |                       |
    | 192.168.2.1/32              | 6     | host       | net_inst_mgr         | True                 | ip-vrf-1 | 0       | 0                | None (extract)   | None                  |
    | 192.168.2.255/32            | 6     | host       | net_inst_mgr         | True                 | ip-vrf-1 | 0       | 0                | None (broadcast) |                       |
    +-----------------------------+-------+------------+----------------------+----------------------+----------+---------+------------------+------------------+-----------------------+
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    IPv4 routes total                    : 9
    IPv4 prefixes with active routes     : 8
    IPv4 prefixes with active ECMP routes: 3
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    ```

The summary from these route table verifications is that:

* leaf1/leaf2/leaf3 install the route to the VIP `1.1.1.100` with the next-hop of the locally connected k8s node.
* leaf4, which is not connected to a kubernetes node, only to a client, installs the route to `1.1.1.100` pointing to the three switches where k8s nodes are connected. Traffic will be encapsulated in VXLAN, forwarded to any of the three VTEPs and finally delivered to the k8s node.

With this setup, it is expected that the traffic to `1.1.1.100` from clients connected to leaf1/leaf2/leaf3 will be delivered to the local k8s node.

In the case of clients connected to leaf4, the switch will load-balance traffic between the three k8s nodes.  

## HTTP Echo end service Verification

Now that we have verified that VIP `1.1.1.100` is learned in our network, we can check if clients can access that service.

We use the following command to connect to our clients: `client1`, `client2`, `client3` and `client4`:

```bash
docker exec -it client1 bash
```

=== "k8s pods placement"
    First let's review again where nginx pods are located:
    ```
    # kk get pods -o wide
    NAME                          READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
    nginxhello-6b97fd8857-4vp6z   1/1     Running   0          81m   10.244.0.3   cluster1       <none>           <none>
    nginxhello-6b97fd8857-b2vf8   1/1     Running   0          81m   10.244.2.3   cluster1-m03   <none>           <none>
    nginxhello-6b97fd8857-f2ggp   1/1     Running   0          81m   10.244.1.3   cluster1-m02   <none>           <none>
    ```
    In the curl responses we can see the IP address of the pod that served the request. This will help us understand how traffic was load balanced.

=== "client1"
    From client1, connected to leaf1, we try to reach the VIP:
    ```
    root@client1:/ $ curl 1.1.1.100
    Server address: 10.244.0.3:80
    Server name: nginxhello-6b97fd8857-4vp6z
    Date: 09/Aug/2023:10:27:55 +0000
    URI: /
    Request ID: 15c8f5967a98e1455e0c3d7c8bed5018
    root@client1:/ $ curl 1.1.1.100
    Server address: 10.244.1.3:80
    Server name: nginxhello-6b97fd8857-f2ggp
    Date: 09/Aug/2023:10:27:58 +0000
    URI: /
    Request ID: b39222e042f977438b427c8c71abd0c0
    root@client1:/ $
    ```
    we can see our traffic has been load balanced to `pod1` and `pod2`

=== "client2"
    From client2, connected to leaf2, we try to reach the VIP:
    ```
    root@client2:/ $ curl 1.1.1.100
    Server address: 10.244.0.3:80
    Server name: nginxhello-6b97fd8857-4vp6z
    Date: 09/Aug/2023:10:56:41 +0000
    URI: /
    Request ID: 22eee500ff00fdf1a15947c4cc8790d6
    root@client2:/ $ curl 1.1.1.100
    Server address: 10.244.1.3:80
    Server name: nginxhello-6b97fd8857-f2ggp
    Date: 09/Aug/2023:10:56:45 +0000
    URI: /
    Request ID: c8530bfa2d44a05c80b22eb2783d0b9a
    root@client2:/ $
    ```
    we can see our traffic has been load balanced to `pod1` and `pod2`

=== "client3"
    From client3, connected to leaf3, we try to reach the VIP:
    ```
    root@client3:/ $ curl 1.1.1.100
    Server address: 10.244.2.3:80
    Server name: nginxhello-6b97fd8857-b2vf8
    Date: 09/Aug/2023:10:58:02 +0000
    URI: /
    Request ID: c90cf6e835d68365467a0f0e246d6990
    root@client3:/ $ curl 1.1.1.100
    Server address: 10.244.1.3:80
    Server name: nginxhello-6b97fd8857-f2ggp
    Date: 09/Aug/2023:10:58:07 +0000
    URI: /
    Request ID: 88eceb46b29ac8bab585cf9d60c8a043
    root@client3:/ $
    ```
    we can see our traffic has been load balanced to `pod3` and `pod2`

=== "client4"
    From client4, connected to leaf4, we try to reach the VIP:
    ```
    root@client4:/ $ curl 1.1.1.100
    Server address: 10.244.2.3:80
    Server name: nginxhello-6b97fd8857-b2vf8
    Date: 09/Aug/2023:12:47:55 +0000
    URI: /
    Request ID: ae64530197cee8dcf906cd4cd1521178
    root@client4:/ $ curl 1.1.1.100
    Server address: 10.244.1.3:80
    Server name: nginxhello-6b97fd8857-f2ggp
    Date: 09/Aug/2023:12:47:57 +0000
    URI: /
    Request ID: 7cc312436a0ee5fe0774203648ce5651
    ```
    we can see our traffic has been load balanced to `pod3` and `pod2`

## Kubernetes Cluster Load Balancing

From the previous tests we can confirm that, independently where requests are coming from, all connections from clients are spread over the three pods.

We can easily explain how traffic from `client4` is load balanced over the three nodes: ECMP in leaf4 distributes the traffic.

But how is it possible that traffic from `client1`, `client2` and `client3` is also load balanced, when previously we confirmed that it will be routed locally to the kubernetes node?

The explanation is simple, we have already seen it in the Kubernetes service definition. **kube-proxy**, thanks to the `externalTrafficPolicy: Cluster` configuration, will load balance the traffic between the available nodes:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/cluster-load-balancing-Cluster.drawio"}'></div>
</figure>

Notice how **kube-proxy** in this case uses source and destination NAT to distribute this traffic.

If we had configured `externalTrafficPolicy: Local`,  then `client1`, `client2` and `client3` traffic to VIP would only reach its locally connected cluster node:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/cluster-load-balancing-Local.drawio"}'></div>
</figure>

With the `Local` policy, **kube-proxy** is not modifying the source IP address.

!!!tip
    Kubernetes uses iptables rules to perform these src/dst NAT policies. You can  check this in kubernetes nodes with the command `iptables -vnL -t nat`

## ECMP hash calculation

We have just seen how Kubernetes manages load balancing internally. In the case of switches, the key ingredient is ECMP (Equal-Cost Multipath). ECMP refers to the distribution of packets over two or more outgoing links that share the same routing cost.

SR Linux load-balances traffic over multiple equal-cost links/next-hops with a hashing algorithm that uses header fields from incoming packets to calculate which link/next-hop to use.

The goal of the hash computation is to keep packets in the same flow on the same network path, while distributing traffic proportionally across the ECMP next-hops, so that each of the N ECMP next-hops carries approximately 1/Nth of the load.

What happens if the number of possible next-hops changes? In our current kubernetes example, what happens when the number of cluster node changes?

If for example one of the cluster nodes fails, the hashing will change so it's possible that the switch will select a different next-hop:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/ecmp_hash.drawio"}'></div>
</figure>

SR Linux provides a way to minimize the number of flows that are moved when the size of the ECMP set changes. This feature is called **Resilient Hashing**. When a next-hop is removed only flows that were previously hashed to that next-hop are moved.

To configure it you have to provide the prefix and two parameters:

* hash-buckets-per-path: the number of times each next-hop is repeated in the hash-bucket fill pattern
* max-paths: the maximum number of ECMP next-hops per route associated with the resilient-hash prefix

The idea behind **Resilient Hashing** is that we pre-calculate the hashes in buckets so in case the ECMP set changes, we don't redistribute the flows.

```bash title="Resilient Hashing configuration"
set network-instance ip-vrf-1 ip-load-balancing resilient-hash-prefix 1.1.1.100 max-paths 6 hash-buckets-per-path 4
```

We can apply and remove this configuration to leaf4 and see how it affects traffic flow distribution to traffic generated from `client4`.

## TL;DR version <a name="tldr"></a>

Want to see a quick summary of the steps? Here you go:

```bash title="quick summary"
git clone https://github.com/srl-labs/srl-k8s-anycast-lab && cd srl-k8s-anycast-lab
minikube start --nodes 3 -p cluster1
sudo clab deploy --topo srl-k8s-lab.clab.yml
minikube addons enable metallb -p cluster1
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-frr.yaml
kubectl apply -f metal-lb-hello-cluster1.yaml
docker exec -it client4 curl 1.1.1.100
```

We have built a lab that deploys a Leaf/Spine Fabric connected to a kubernetes cluster. We deployed a simple Nginx echo service in **Anycast** mode, in which we publish that service from multiple locations. And finally, we have verified that traffic is distributed to the different nodes of the cluster.

## Lab lifecycle

To delete this lab:

1. Destroy Containerlab topology: `clab destroy --topo srl-k8s-lab.clab.yml`
2. Delete Minikube node: `minikube delete --all`

[mr-linkedin]: https://linkedin.com/in/michelredondo
[lab]: https://github.com/srl-labs/srl-k8s-anycast-lab
[clab-topo]: https://github.com/srl-labs/srl-k8s-anycast-lab/blob/main/srl-k8s-lab.clab.yml
[clab-configs]: https://github.com/srl-labs/srl-k8s-anycast-lab/tree/main/configs
[metallb-cfg]: https://github.com/srl-labs/srl-k8s-anycast-lab/blob/main/metallb.yaml

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
