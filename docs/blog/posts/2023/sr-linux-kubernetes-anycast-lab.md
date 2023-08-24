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

To illustrate the integration between the workloads running in the k8s cluster and the IP fabric, we will deploy a simple NGINX server replicated across the three k8s nodes. A kubernetes ClusterIP service will be created to expose the NGINX server inside the cluster and a MetalLB loadBalancer service will be created to expose the NGINX server to the outside world.

With simulated clients, we will verify how traffic is distributed among the different nodes/pods using `curl` and reaching over to the exposed service IP address.

### Underlay Networking

The [eBGP unnumbered peering](https://documentation.nokia.com/srlinux/23-7/books/routing-protocols/bgp.html#bgp-unnumbered-peer) makes the core of our IP fabric. Each leaf switch is configured with a unique ASN, whereas all spines share the same ASN, which is a common practice in Leaf/Spine fabrics:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/fabric_ebgp.drawio"}'></div>
  <figcaption>Underlay IPv6 Link Local eBGP sessions</figcaption>
</figure>

Through eBGP the loopback/system IP addresses are exchanged between the leaves, making it possible to setup iBGP sessions for the overlay services that support the k8s cluster:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/fabric_ibgp.drawio"}'></div>
  <figcaption>Overlay iBGP EVPN sessions</figcaption>
</figure>

### Overlay Networking

Clients and k8s nodes are conected to a dedicated L3 EVPN network-instance `ip-vrf1`. This network instance is present in every leaf switch. Traffic between switches is encapsulated in VXLAN and transported by Spines. Two subnets are configured under this `ip-vrf1`:

* k8s nodes subnet: 192.168.1.0/24
* clients subnet: 192.168.2.0/24

In an distributed EVPN L3 scenario, all IRB interfaces facing the hosts must have the same IP address and MAC (.1 IP address in our case); that is, an [anycast-GW](https://documentation.nokia.com/srlinux/23-3/books/evpn-vxlan/evpn-vxlan-tunnels-layer-3.html#evpn-l3-multi-hom-anycast-gateways) configuration. This avoids inefficiencies for all-active multi-homing and speeds up convergence for host mobility.

Kubernetes nodes, thanks to MetalLB, will establish BGP sessions to these anycast-GW IP addresses. These peering sessions are used to advertise the IP addresses of the exposed services.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":1.7,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-k8s-anycast-lab/main/images/logical.drawio"}'></div>
  <figcaption>Logical network topology</figcaption>
</figure>

## Containerlab topology file

The whole lab topology,  is declared in the Containerlab [`srl-k8s-lab.clab.yml`][clab-topo] file.

Let's review the different components of our definition file:

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

We will use the latest [SR linux image](https://github.com/nokia/srlinux-container-image) as of today, that can be pulled as easily as `docker pull ghcr.io/nokia/srlinux:23.7.1`.

[network-multitool](https://github.com/users/hellt/packages/container/package/network-multitool) versatile Linux image for the client.

Kubernetes container images and container creation are directly managed by Minikube.

### Nodes

And let's also review the definition of our Lab components: Leaf/Spine switches, K8s nodes and Linux clients:

```yaml title="node definition"
topology:
  # -- snip --
  nodes:
    leaf1:
      kind: srl
      startup-config: configs/leaf1.conf
 
    cluster1: 
      kind: ext-container # (1)
      exec:
        - ip address add 192.168.1.11/24 dev eth1
        - ip route add 192.168.0.0/16 via 192.168.1.1
  
    client1:
     kind: linux
     binds:
        - configs/hostname.sh:/hostname.sh
        - configs/client1-config.sh:/client1-config.sh
     exec:
        - bash /hostname.sh # (2)
        - bash /client1-config.sh # (3)
# -- snip --
```

1. Minikube will name k8s container nodes with the  name `minikube` by default. If the minikube option `profile` is used, it will use the profile name. Here, we use the profile name `cluster1`. First node is named `cluster1`, second `cluster1-m02`...
2. `bash /hostname.sh` is just a hacky script that updates the shell with the name of the container, so it's easier to see where we are connected when we attach to the client containers.
3. Client IP addresses and routes are configured through this script.

Containerlab will configure the Leaf/Spine fabric at boot time. You can check the configurations in the [config][clab-configs] folder.

Minikube nodes are referenced by using the `kind: ext-container` option. This option instructs Containerlab to interact with containers with the name declared (`cluster1` in the example). Clab will take care of creating the interface (`192.168.1.11/24 dev eth1`) and default route. Take note that Minikube node creation it's not managed by Containerlab, is directly managed by the Minikube client.

Later in the blog post we will carefully explain the process to fully boot up the Lab.

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
    `eth0`minikube node interfaces are connected to the docker bridge of the host running the topology. `eth1` interfaces, connected to Leaf switches, will be the ones used by MetalLB to establish the BGP the sessions. As reachability is signaled through this interface, clients will also reach k8s cluster services though `eth1`.

## Lab deployment

First, clone the lab:

```bash
https://github.com/srl-labs/srl-k8s-anycast-lab.git && cd srl-k8s-anycast-lab
```

Start Minikube cluster:

```bash title="Minikube node deployment"
minikube start --nodes 3 -p cluster1
```

With this command, Minikube has started three k8s nodes (`cluster1`, `cluster1-m02` and `cluster1-m03`) under the profile `cluster`.

Once Minikube has finished, deploy Containerlab topology:

```bash title="Containerlab topology deployment"
clab deploy --topo srl-k8s-lab.clab.yml
```

At the end of the deployment process, you will see the summary table with details about deployed nodes:

```text
INFO[0000] Containerlab v0.44.1 started
--snip--
+----+--------------+--------------+-------------------------------------------------------------------------------------------------------------+---------------+---------+-----------------+----------------------+
| #  |     Name     | Container ID |                                                    Image                                                    |     Kind      |  State  |  IPv4 Address   |     IPv6 Address     |
+----+--------------+--------------+-------------------------------------------------------------------------------------------------------------+---------------+---------+-----------------+----------------------+
|  1 | cluster1     | 9fa3a758bb4b | gcr.io/k8s-minikube/kicbase:v0.0.39@sha256:bf2d9f1e9d837d8deea073611d2605405b6be904647d97ebd9b12045ddfe1106 | ext-container | running | 192.168.49.2/24 | N/A                  |
|  2 | cluster1-m02 | 376501089ecc | gcr.io/k8s-minikube/kicbase:v0.0.39@sha256:bf2d9f1e9d837d8deea073611d2605405b6be904647d97ebd9b12045ddfe1106 | ext-container | running | 192.168.49.3/24 | N/A                  |
|  3 | cluster1-m03 | 64a4e8bbdd73 | gcr.io/k8s-minikube/kicbase:v0.0.39@sha256:bf2d9f1e9d837d8deea073611d2605405b6be904647d97ebd9b12045ddfe1106 | ext-container | running | 192.168.49.4/24 | N/A                  |
|  4 | client1      | 592e09690912 | ghcr.io/hellt/network-multitool                                                                             | linux         | running | 172.20.20.8/24  | 2001:172:20:20::8/64 |
|  5 | client2      | 95220f94b6f0 | ghcr.io/hellt/network-multitool                                                                             | linux         | running | 172.20.20.10/24 | 2001:172:20:20::a/64 |
|  6 | client3      | 7572185a5ca4 | ghcr.io/hellt/network-multitool                                                                             | linux         | running | 172.20.20.9/24  | 2001:172:20:20::9/64 |
|  7 | client4      | d97d63b2204b | ghcr.io/hellt/network-multitool                                                                             | linux         | running | 172.20.20.4/24  | 2001:172:20:20::4/64 |
|  8 | leaf1        | f409d3e950a3 | ghcr.io/nokia/srlinux:23.7.1                                                                                | srl           | running | 172.20.20.7/24  | 2001:172:20:20::7/64 |
|  9 | leaf2        | bf9c6d3e327f | ghcr.io/nokia/srlinux:23.7.1                                                                                | srl           | running | 172.20.20.2/24  | 2001:172:20:20::2/64 |
| 10 | leaf3        | c76005991d80 | ghcr.io/nokia/srlinux:23.7.1                                                                                | srl           | running | 172.20.20.11/24 | 2001:172:20:20::b/64 |
| 11 | leaf4        | ccfd9ddc66f2 | ghcr.io/nokia/srlinux:23.7.1                                                                                | srl           | running | 172.20.20.6/24  | 2001:172:20:20::6/64 |
| 12 | spine1       | c34f4f75a29f | ghcr.io/nokia/srlinux:23.7.1                                                                                | srl           | running | 172.20.20.3/24  | 2001:172:20:20::3/64 |
| 13 | spine2       | c2ebfe43499e | ghcr.io/nokia/srlinux:23.7.1                                                                                | srl           | running | 172.20.20.5/24  | 2001:172:20:20::5/64 |
+----+--------------+--------------+-------------------------------------------------------------------------------------------------------------+---------------+---------+-----------------+----------------------+

```

## Minikube MetalLB installation

As are using MetalLB, first we need to enable it in the Minikube cluster:

```bash
minikube addons enable metallb -p cluster1
```

MetalLB has two [modes of operation](https://metallb.universe.tf/concepts/): Layer2 and BGP. For this Lab we will use BGP.

MetalLB also provides two different [BGP implementations](https://metallb.universe.tf/concepts/bgp/):

1. Native
2. FRR (provides BGP sessions with BFD support)

We will use the *FRR* implementation. We install it with the following command:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-frr.yaml
```

## Leaf/Spine fabric verification

By this step, the DC Fabric is deployed and configured and k8s cluster is also ready.

Our k8s test service (Nginx Echo Server) is not yet deployed so our MetalLB BGP sessions between Leaf and kubernetes nodes are not established yet, but the underlay DC Fabric BGP/EVPN sessions between Leaf and Spines switches should be working by now. We can verify that it's working properly:

=== "Spine1"
    BGP underlay sessions are configured with [unnumbered peering](https://documentation.nokia.com/srlinux/23-3/books/routing-protocols/bgp.html#bgp-unnumbered-peer).

    BGP EVPN sessions are established between system IP interfaces.
    ```
      A:spine1# show network-instance default protocols bgp neighbor
      -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      BGP neighbor summary for network-instance "default"
      Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
      -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
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
      -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      Summary:
      4 configured neighbors, 4 configured sessions are established,0 disabled peers
      4 dynamic peers
    ```
    Great! All sessions established and exchanging prefixes.
=== "Leaf1"
    We can also have a look at BGP sessions  from the perspective of the leaf switch:
    ```
    A:leaf1# show network-instance default protocols bgp neighbor
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    BGP neighbor summary for network-instance "default"
    Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
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
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    Summary:
    2 configured neighbors, 2 configured sessions are established,0 disabled peers
    2 dynamic peers
    ```
    All looking good too.

=== "Leaf1 vrf1 Route Table"
    K8s Cluster and clients are connected to the `ip-vrf-1` route table. We can check that routes are present:
    ```
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
    Subnet `192.168.1.0/24`, where Cluster nodes are conected is present, and subnet `192.168.2.0/24`, where clients are connectted is present too.

=== "Leaf1 vrf1 MetalLB BGP session"
    We can also check the MetalLB BGP session between the Leaf1 switch and the k8s Node1:
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
    | ip-vrf-1           | 192.168.1.11                | metal              | S     | 65535     | active         | -              |              |                             |
    +--------------------+-----------------------------+--------------------+-------+-----------+----------------+----------------+--------------+-----------------------------+
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    Summary:
    1 configured neighbors, 0 configured sessions are established,0 disabled peers
    0 dynamic peers
    ```
    As expected, the session is not yet established. We first have to deploy the Kubernetes service.

## Kubernetes service deployment

After we have verified that the DC Fabric is properly configured, it's time to deploy the end service, represented in the k8s Resource definition file [metal-lb-hello-cluster1.yaml][metal-lb-hello-cluster1]

Let's first review the different parameters that define it:

```yaml title="IPAddressPool: defines VIP address range used by MetalLB"
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: poolone
  namespace: metallb-system
spec:
  addresses:
  - 1.1.1.100-1.1.1.200
```

```yaml title="BGPAdvertisement: instructs MetalLB to use the BGP mode"
apiVersion: metallb.io/v1beta1
kind: BGPAdvertisement
metadata:
  name: bgpadv
  namespace: metallb-system
```

```yaml title="BGPPeer: BGP peer definition"
apiVersion: metallb.io/v1beta2
kind: BGPPeer
metadata:
  name: peer
  namespace: metallb-system
spec:
  myASN: 65535
  peerASN: 65535
  peerAddress: 192.168.1.1 # (1)
```

1. Leaf switches are configured with a distributed L3 evpn service where every switch is configured with the same gw IP address (192.168.1.1/24 for K8s nodes subnet and 192.168.2.1/24 for clients subnet)

```yaml title="Deployment: HTTP echo service deployment"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginxhello
spec:
  replicas: 3 # (1)
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
        image: nginxdemos/hello:plain-text # (2)
        ports:
        - name: http
          containerPort: 80
```

1. Three pods will be deployed in our cluster
2. The Nginx hello image echoes back the name and IP address of the pod

```yaml title="Service: exposing our nginxhello application"
apiVersion: v1
kind: Service
metadata:
  name: nginxhello
spec:
  ports:
  - name: http
    port: 80 # (1)
    protocol: TCP
    targetPort: 80 # (2)
  selector:
    app: nginxhello
  type: LoadBalancer
  externalTrafficPolicy: Cluster # (3)
```

1. **port** exposes the Kubernetes service on the specified port within the cluster. Other pods within the cluster can communicate with this server on the specified port
2. **targetPort** is the port on which the service will send requests to, that your pod will be listening on
3. Two possible configurations: **Local** or **Cluster**

    **Local** means that when the packet arrives to a node, kube-proxy will only distribute the load within the same node
  
    **Cluster** means that when the packet arrives to a node, kube-proxy will distribute the load to all the nodes present in the service

Finally, it's time to deploy our service. As you can see in the Resource definition file [metal-lb-hello-cluster1.yaml][metal-lb-hello-cluster1], these resources are grouped together in the same file (separated by --- in YAML).

To deploy the service:

```bash
kubectl apply -f metal-lb-hello-cluster1.yaml
```

That's it!! We have the fabric running and the service configured. Let's do some checks.

## Kubernetes verification

We can check the status of our k8s cluster and the service we have just deployed:

=== "k8s nodes"
    We check that our three node cluster is ready:
    ```
    # kubectl get nodes
    NAME           STATUS   ROLES           AGE   VERSION
    cluster1       Ready    control-plane   79m   v1.26.3
    cluster1-m02   Ready    <none>          78m   v1.26.3
    cluster1-m03   Ready    <none>          78m   v1.26.3
    ```
    looks good!

=== "k8s pods"
    We check that end service consisting of three Nginx echo pods are ready too:
    ```
    # kk get pods -o wide
    NAME                          READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
    nginxhello-6b97fd8857-4vp6z   1/1     Running   0          81m   10.244.0.3   cluster1       <none>           <none>
    nginxhello-6b97fd8857-b2vf8   1/1     Running   0          81m   10.244.2.3   cluster1-m03   <none>           <none>
    nginxhello-6b97fd8857-f2ggp   1/1     Running   0          81m   10.244.1.3   cluster1-m02   <none>           <none>
    ```
    Nginx pods running, and we can see that the Kubernetes scheduler has placed one Nginx pod at each k8s node.

=== "k8s service"
    We check that the service exposure is correct:
    ```
    # kubectl get svc
    NAME         TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
    kubernetes   ClusterIP      10.96.0.1        <none>        443/TCP        85m
    nginxhello   LoadBalancer   10.107.153.252   1.1.1.100     80:30608/TCP   51m
    ```
    nginxhello service configured!

=== "k8s MetalLB speaker pods"
    At every node, MetalLB deploys a pod that runs the FRR daemon. We can check it:
    ```
    # kubectl get pods -A | grep speaker
    metallb-system   speaker-4gcj8                      4/4     Running   0             56m
    metallb-system   speaker-bs2mq                      4/4     Running   0             56m
    metallb-system   speaker-cpdnj                      4/4     Running   0             55m
    ```
    pods running!
=== "k8s MetalLB pod speaker FRR "
    We can connect to speakers with the command `kubectl exec -it speaker-4gcj8 --namespace=metallb-system  -- vtysh`. Once connected, we can use different commands to verify status, including `show run` to display configuration:
    ```
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
    cluster1#
    ```
    As expected, FRR daemon is announcing the VIP.

## Fabric Overlay verification

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
[metal-lb-hello-cluster1]: https://github.com/srl-labs/srl-k8s-anycast-lab/blob/main/metal-lb-hello-cluster1.yaml

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
