---
date: 2023-06-22
tags:
  - evpn
  - mc-lag
  - datacenter
  - multi-homing
authors:
  - amitk
---

# Single Tier Datacenters - Evolving Away From Multi-chassis LAG

Multi-Chassis LAG (MC-LAG) was a welcome technology that helped enterprises move away from xSTP based L2 networks. It solved many of the issues inherent to xSTP networks, like underutilized links, long convergence times, and layer 2 loops. It became a common design pattern in many datacenters at the access and aggregate layers.

And as with any other technology, MC-LAG started to show its limitations as the scale of the datacenters network grew. The need for a more scalable, interoperable and simpler solution led to the development of EVPN Multihoming (EVPN-MH) design. This article discusses the migration path from MC-LAG-based to EVPN-MH deployments for small, single-tier datacenters.

<!-- more -->

## With MC-LAG

MC-LAG solutions are based on vendor proprietary control plane. Although they solved many problems with previous designs, they came with their own set of challenges:

* **Split-Brain Situations:** This occurs when the two chassis lose connectivity with each other. This leads to inconsistencies, traffic loops and potential downtimes.

* **Complexity:** The MC-LAG solution can be quite complex in configuration and in management. It requires a lot of careful planning and monitoring to ensure smooth operations.

* **Race conditions:** Synchronization of MAC, ARP and Route tables across the two chassis is absolutely critical to the functioning of MC-LAG. But this synchronization invariably has some latency leaving room for highly error-prone race conditions following various changes in the network.

* **Reliance on Inter-chassis Link (ICL):** MC-LAG designs rely heavily on a LAG interface between the two chassis. These links can’t be disabled or modified easily. Also, network events can easily result in traffic flows to use ICLs and overwhelm them.

* **Interoperability:** The synchronization of various data path tables is achieved between two chassis via vendor-proprietary control plane mechanisms that have no interoperability with other vendor solutions.

* **Scalability:** As the scale of MAC, ARP and Route tables grow, the synchronization latencies can significantly impact convergence times.

* **Resiliency:** Multi-tiered MC-LAG can extend L2 network and resiliency all the way to aggregation layer. However, MC-LAG typically provides multi-homing to only two devices. This limits the amount of resiliency that the network can provide. Compare it with network designs that use L3 underlay at the ToR switches and use ECMP between ToR and Aggregation. These solutions can provide (depending on the ToR device) 2 to as much as 128 uplinks to the Aggregation.

## EVPN Multihoming

[EVPN Multihoming](https://documentation.nokia.com/srlinux/23-3/books/advanced-solutions/evpn-vxlan-layer-2-multi-hom.html#multi-hom-configuration-evpn-broadcast-domains) ([RFC7432](https://datatracker.ietf.org/doc/html/rfc7432) and [RFC8365](https://datatracker.ietf.org/doc/html/rfc8365#autoid-19) for its applicability to VXLAN) replaces the vendor-proprietary MC-LAG mechanisms with an IETF standard based solution. EVPN-MH solves the challenges mentioned above by introducing new route types in BGP EVPN family specification. It still needs L3 connectivity to the peer but doesn’t need a dedicated ICL.

EVPN-MH takes a holistic view of the end-to-end challenges and provides a comprehensive multihoming solution to L2 and L3 services running locally, and/or across an underlay L3 network. It provides various mechanism to handle scenarios like MAC Learning, avoid MAC duplication, loop detection, limit broadcast domain, mass withdrawal of MAC/IP routes, L2/L3 load balancing etc.

### Replace MC-LAG with EVPN-MH

Network Operators with MC-LAG deployments can consider migrating to EVPN-MH on single rack as a first step to simplify and scale their solution. This solution is ideal for those looking to deploy or reimagine a small datacenter with just a few servers in a rack. You could be running only a few virtualized workloads or needing a remote datacenter connecting to central on-prem or cloud datacenter via a backbone network.

## The 1-Rack Solution

You can spin a Datacenter with as little as just two Top-of-Rack (ToRs) from [7220 IXR-D](https://www.nokia.com/networks/data-center/data-center-fabric/7220-interconnect-router/) family devices sitting on top of your rack of servers. The ToR switches are connected with their uplinks to an existing core for North-South traffic.

![pic1](https://gitlab.com/rdodin/pics/-/wikis/uploads/3efa581a5c39d721a1a8d79e48ca26b2/image__1_.webp){.img-shadow}

### Components

**Servers**

* Multi-home the servers to the two ToRs.

* Create LACP (or static) LAG interfaces with different links ending on different ToRs to act as uplink from each server.

**ToRs**

We use Top-of-Rack and Leaf terms interchangeably in this post, both terms indicate a switch that servers in a rack are connected.

* Provision one or two IP interfaces between the ToRs.

* Use these interfaces as underlay for iBGP peering needed for EVPN-MH. Connectivity to the core provides backup underlay reachability to iBGP peer. This underlay can be established via eBGP or IGP.

* [Enable All-Active EVPN-MH](https://documentation.nokia.com/srlinux/23-3/books/advanced-solutions/evpn-vxlan-layer-2-multi-hom.html#all-active-multi-hom-configurations) on the Leaf.

* Enable Integrated Routing and Bridging (IRB) with anycast functionality on ToRs if L3 services are needed.

EVPN-MH procedures will set up the data path to ensure a loop-free, fully redundant and load balanced layer 2 and layer 3 topology.

The various failure scenarios that pose big challenges to traditional MC-LAG setups are seamlessly handled as explained in the next section.

### Handling Network Failure

#### Leaf-Server Link Failure

When the link connecting Leaf to one of the servers fails, LACP detects this event at the server. This allows the server to react locally by dropping the failed link from its LAG membership and utilizing the alternate uplink.

<figure markdown>
  ![pic2](https://gitlab.com/rdodin/pics/-/wikis/uploads/85181b3dfcc942b5a28f2782baae874c/image__2_.webp){ .img-shadow width="400" }
</figure>

For datacenters requiring more levels of resiliency, there are two options:

* Provision two links between the server and each Leaf: This provides link level resiliency in addition to node (Leaf) level resiliency.

* Connect each server to up to 4 Leaf switches.

#### Inter-Chassis Link Failure

<figure markdown>
  ![pic2](https://gitlab.com/rdodin/pics/-/wikis/uploads/e866147daba870b0db2c24bef27d82c6/image__3_.webp){ .img-shadow width="400" }
</figure>

The inter-chassis link should be formed using multiple IP interfaces. This allows one level of failure protection. However, if this all these links fail (say due to a fiber cut), a Leaf still has two alternate paths to reach its iBGP peer via Core. This provides multiple levels of protection against what is called Split-Brain situation.

#### Leaf-Core Link Failure

<figure markdown>
  ![pic2](https://gitlab.com/rdodin/pics/-/wikis/uploads/b81ca28b7461d03ed6aea1a21391dcfe/image__4_.webp){ .img-shadow width="400" }
</figure>

The North-South traffic is protected via ECMP between Leaf and Core routers. In the unlikely event where a Leaf loses connectivity to both Core Routers via its uplink, it can still reach the Core Routers via the less-than-optimal Inter-Chassis Links. The link cost configuration should make sure that ICLs are used only as a last resort for data traffic, as those links will be oversubscribed.

However, to avoid ICLs from being used in the data path, it is desired if Leaf can signal the server to stop sending it any north bound traffic. SR Linux’s highly versatile Event Handler can be employed to achieve this by configuring it for Operational Groups.

!!!tip
    Check out [Opergroups with Event Handler tutorial](../../../tutorials/programmability/event-handler/oper-group/oper-group-intro.md) for a complete deep dive on this topic.

#### Split-Brain Situation

In rare cases, a Leaf can lose complete connectivity to its peer Leaf despite multiple levels of redundant paths. Without proper configuration, this can lead to inconsistencies, traffic loops and potential downtimes.

<figure markdown>
  ![pic2](https://gitlab.com/rdodin/pics/-/wikis/uploads/b4af49b42747cd6d9cc07dffe85b1137/image__5_.webp){ .img-shadow width="400" }
</figure>

If the server continues to send traffic to this leaf switch, traffic can get blackholed. To protect against this scenario, we can designate the Leaf switches as primary and secondary.

While downlinks on both Leaf switches remain in active-active state under normal working conditions, we can program the downlink on secondary device to get disabled when a Split-Brain situation is detected. This is achieved by:

* tracking availability of peer Leaf node (via management network-instance) and iBGP peering (via BFD).

* if iBGP peering is lost, but peer Leaf node is still available, this indicates a Split-Brain situation.

When this happens, Event Handler is used to disable downlink on secondary Leaf. The downlink on primary Leaf continues to receive and forward traffic.

## Scaling Up the Datacenter

Thanks to EVPN fabric architecture and features like Maintenance mode, SR Linux datacenter solution easily scales horizontally. This involves migrating from EVPN-MH based MC-LAG solution to EVPN based Leaf-Spine architecture.

<figure markdown>
  ![pic2](https://gitlab.com/rdodin/pics/-/wikis/uploads/8c449e99d484f5e65a0b847071ad2264/image__6_.webp){ .img-shadow}
</figure>

Take for instance scaling 1-rack solution to 2-rack solution described below:

### Network Modifications

The change of network from 1-rack solution of Figure 1 to 2-rack solution of Figure 2 involves these steps:

1. Add a new rack and connect Spine switches to all Leaf switches.

2. Configure the underlay eBGP peering between Leaf and Spine nodes. iBGP peering between the Leafs of existing rack will continue to use ICL links due to lesser cost. At the same time, North-South traffic of existing rack will also continue using direct Leaf-Core Router links.

3. Put ICL and direct Leaf-Core links on existing rack in maintenance mode. The north-south traffic and BGP peering between ToRs will start going via spine switches.

4. Remove these links and you have successfully moved to the new Leaf-Spine architecture without disruption to existing services.
