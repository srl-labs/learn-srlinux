---
date: 2023-06-29
tags:
  - evpn
  - mc-lag
  - multihoming
  - evpn-mh
authors:
  - amitk
---

# Single Tier Datacenters - Evolving Away From Multi-chassis LAG

Multi-Chassis LAG (MC-LAG) was a welcome technology that helped enterprises move away from xSTP based L2 networks. It solved many of the issues inherent to xSTP networks, like underutilized links, long convergence times, and layer 2 loops. It became a common design pattern in many datacenters at the access and aggregate layers.

And as with any other technology, MC-LAG started to show its deficiencies as the datacenter networks continued to evolve. The need for a more scalable, interoperable and simpler solution led to the development of EVPN Multihoming (EVPN-MH) design. In this blog post we will discuss how a small-scale, single-rack datacenter deployment can benefit from EVPN-Multihoming-based design.  
We finish the post by introducing a path to scale up from a single-rack deployment to a multi-rack deployment.

<!-- more -->

## With MC-LAG

MC-LAG solutions are based on vendor proprietary control plane. Although they solved many problems with previous designs, they came with their own set of challenges:

* **Split-Brain Situations:** This occurs when the two chassis lose connectivity with each other. This leads to inconsistencies, traffic loops and potential downtimes.

* **Race conditions:** Synchronization of MAC, ARP and Route tables across the two chassis is absolutely critical to the functioning of MC-LAG. But this synchronization invariably has some latency leaving room for highly error-prone race conditions following various changes in the network.

* **Reliance on Inter-chassis Link (ICL):** MC-LAG designs rely heavily on a LAG interface between the two chassis. These links can’t be disabled or modified easily. Also, network events can easily result in traffic flows to use ICLs and overwhelm them.

* **Interoperability:** The synchronization of various data path tables is achieved between two chassis via vendor-proprietary control plane mechanisms that have no interoperability with other vendor solutions.

* **Scalability:** As the scale of MAC, ARP and Route tables grow, the synchronization latencies can significantly impact convergence times.

* **Resiliency:** Multi-tiered MC-LAG can extend L2 network and resiliency all the way to aggregation layer. However, MC-LAG typically provides multi-homing to only two devices. This limits the amount of resiliency that the network can provide. Compare it with network designs that use L3 underlay at the ToR switches and use ECMP between ToR and Aggregation. These solutions can provide (depending on the ToR device) 2 to as much as 128 uplinks to the Aggregation.

## EVPN Multihoming

[EVPN Multihoming](https://documentation.nokia.com/srlinux/23-3/books/advanced-solutions/evpn-vxlan-layer-2-multi-hom.html#multi-hom-configuration-evpn-broadcast-domains) ([RFC7432](https://datatracker.ietf.org/doc/html/rfc7432) and [RFC8365](https://datatracker.ietf.org/doc/html/rfc8365#autoid-19) for its applicability to VXLAN) replaces the vendor-proprietary MC-LAG mechanisms with an IETF standard based solution. EVPN-MH solves the challenges mentioned above by introducing new route types in BGP EVPN family specification. It still needs L3 connectivity to the peer but doesn’t need a dedicated ICL[^1].

EVPN-MH takes a holistic view of the end-to-end challenges and provides a comprehensive multihoming solution to L2 and L3 services running locally, and/or across an underlay L3 network. It provides various mechanisms to handle scenarios like MAC Learning, avoid MAC duplication, loop detection, limit broadcast domain, mass withdrawal of MAC/IP routes, L2/L3 load balancing etc.

### Replace MC-LAG with EVPN-MH

Network Operators with MC-LAG deployments can consider migrating to EVPN-MH on a single rack as a first step to simplify and scale their solution. This solution is ideal for those looking to deploy or reimagine a small datacenter with just a few servers in a rack. You could be running only a few virtualized workloads or needing a remote datacenter connecting to a central on-prem or cloud datacenter via a backbone network.

The following table summarizes the differences between MC-LAG and EVPN-MH:

| Consideration                                          | MC-LAG                                                                                                                                        | EVPN-MH                                                                                               |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Standards-based                                        | No                                                                                                                                            | IETF based                                                                                            |
| Industry acceptance                                    | Vendors moving to EVPN MH                                                                                                                     | Supported by major vendors in DC space (tested at EANTC)                                              |
| All-active and port-based active-standby               | Partial support for Port-based                                                                                                                | Yes                                                                                                   |
| Single-active (per-service load-balancing)             | Not supported                                                                                                                                 | Yes                                                                                                   |
| Supports more than 2 multi-homing nodes                | Limited to 2                                                                                                                                  | Unlimited (HW vendors often support up to 4)                                                          |
| Supports more than 2 protocol peers                    | Limited to 2 peers                                                                                                                            | Unlimited                                                                                             |
| When used for overlays, works with IP and MPLS tunnels | No ECMP overlay for MPLS MC-LAG relies on an anycast VTEP for load-balancing from network to access. Anycast VTEPs only work with IP tunnels. | Agnostic of the tunnel Supports overlay ECMP (aliasing) based on ESI                                  |
| Requires Inter-chassis dedicated LAG                   | Yes                                                                                                                                           | No                                                                                                    |
| Other merits                                           |                                                                                                                                               | virtual ES control over the DF Election works with any logical interface, and not only lag interfaces |

<center><small>MC-LAG vs EVPN-MH</small></center>

## The 1-Rack Solution

You can spin a Datacenter with as little as just two Top-of-Rack (ToRs) from [7220 IXR-D](https://www.nokia.com/networks/data-center/data-center-fabric/7220-interconnect-router/) family devices sitting on top of your rack of servers. The ToR switches are connected with their uplinks to an existing core for North-South traffic.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:0,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/mclag-to-evpn-mh.drawio&quot;}"></div>

### Components

#### Servers

* Multi-home the servers to the two ToRs.

* Create LACP (or static) LAG interfaces with different links ending on different ToRs to act as uplinks from each server.

#### ToRs

We use Top-of-Rack and Leaf terms interchangeably in this post; both terms indicate a switch that servers in a rack are connected.

* Provision loopback IP interfaces on the ToRs.

* Use these interfaces for iBGP peering needed for EVPN-MH. The Inter-switch link (ISL, or ICL) is used here for plain IP connectivity between the ToRs, as the existing Core switches are only used for BGP v4/v6 peering.  
  Alternatively, the Core switches might provide connectivity between leaf's loopbacks; in this case, ISL/ICL is not required.

* [Enable All-Active EVPN-MH](https://documentation.nokia.com/srlinux/23-3/books/advanced-solutions/evpn-vxlan-layer-2-multi-hom.html#all-active-multi-hom-configurations) on the Leaf.

* Enable Integrated Routing and Bridging (IRB) with anycast functionality on ToRs if L3 services are needed.

EVPN-MH procedures will set up the data path to ensure a loop-free, fully redundant and load balanced layer 2 and layer 3 topology.

The various failure scenarios that pose big challenges to traditional MC-LAG setups are seamlessly handled as explained in the next section.

### Handling Network Failure

#### Leaf-Server Link Failure

When the link connecting Leaf to one of the servers fails, LACP detects this event at the server. This allows the server to react locally by dropping the failed link from its LAG membership and utilizing the alternate uplink.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:1,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/mclag-to-evpn-mh.drawio&quot;}"></div>

For datacenters requiring more levels of resiliency, there are two options:

* Provision two links between the server and each Leaf: This provides link level resiliency in addition to node (Leaf) level resiliency.

* Connect each server to up to 4 Leaf switches.

#### Inter-Chassis Link Failure

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:3,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/mclag-to-evpn-mh.drawio&quot;}"></div>

The inter-chassis link should be formed using multiple IP interfaces that protects the link from a failure of a 1st degree. It is implausible that all the links between the ToRs will fail simultaneously as both endpoints are in the same rack.

#### Leaf-Core Link Failure

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:2,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/mclag-to-evpn-mh.drawio&quot;}"></div>

The North-South traffic is protected via ECMP between Leaf and Core routers. In the unlikely event where a Leaf loses connectivity to both Core Routers via its uplink, it can still reach the Core Routers via the less-than-optimal Inter-Chassis Links. The link cost configuration should make sure that ICLs are used only as a last resort for data traffic, as those links will be oversubscribed.

However, to avoid ICLs from being used in the data path, it is desired if Leaf can signal the server to stop sending it any north bound traffic. SR Linux’s highly versatile Event Handler can be employed to achieve this by configuring it for Operational Groups.

!!!tip
    Check out [Opergroups with Event Handler tutorial](../../../tutorials/programmability/event-handler/oper-group/oper-group-intro.md) for a complete deep dive on this topic.

Opergroups can also be used to shutdown the server-facing interfaces on the Leaf to avoid any traffic loss in the case when both uplinks and the ICL is down.

## Scaling Up the Datacenter

Thanks to EVPN fabric architecture and features like Maintenance mode, SR Linux datacenter solution easily scales horizontally. This involves migrating from EVPN-MH with inter-chassis link solution to an EVPN-based Leaf-Spine architecture.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:4,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/mclag-to-evpn-mh.drawio&quot;}"></div>

For example, scaling a 1-rack solution to 2-rack solution described involves these steps:

1. Add a new rack and connect Spine switches to all Leaf switches.

2. Configure the underlay eBGP peering between Leaf and Spine nodes. iBGP peering between the Leafs of existing rack will continue to use ICL links due to lesser cost. At the same time, North-South traffic of existing rack will also continue using direct Leaf-Core Router links.

3. Put ICL and direct Leaf-Core links on existing rack in [maintenance mode][maint-mode]. The north-south traffic and BGP peering between ToRs will start going via spine switches.

4. Remove these links and you have successfully moved to the new Leaf-Spine architecture without disruption to existing services.

As you can see, adding new racks and scaling the datacenter horizontally is a non-disruptive process with each rack deployment process being identical to the previous one.

[^1]: In the single-tier/single-rack design that we describe in this post the ICL is still present simply to provide L3 connectivity between the ToRs, while not relying on Core switches that might be not under your control. When the design scales beyond a single rack typically a spine layer is introduced and ICL is removed.

[maint-mode]: https://documentation.nokia.com/srlinux/23-3/books/config-basics/maintenance-mode.html

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
