---
comments: true
---

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>

# Routing for Underlay & Overlay

Underlay routing is used for the physical network's connectivity, while overlay routing is used to create virtual networks on top of the physical infrastructure.

## Underlay Routing

Before setting up an EVPN overlay, it's necessary to implement a routing protocol to ensure all leaf VxLAN Termination End Points (VTEPs) are reachable across the IP fabric.

SR Linux supports the following routing protocols for the underlay network:

* ISIS

* OSPF

* BGP

BGP is strongly recommended for data center fabrics as described in [RFC7938](https://datatracker.ietf.org/doc/html/rfc7938), offering several advantages, here are few of them that I think are the most important:

* **Scalability:** BGP announces only the best paths, unlike IGPs that share the entire link state database. This results in lower hardware resource consumption for BGP compared to IGP.

* **Flexible Policy:** BGP provides numerous attributes for policy matching, offering extensive options for traffic steering.

* **Smaller Failure Impact Radius with BGP compared to IGP:**
    * In case of link failure in an ISIS/OSPF network, all devices need to run SPF on the entire link state database. The failure impact radius is the whole network.

    * In case of link failure in an eBGP network, only devices one hop away need to recalculate the best path, this is because eBGP announces all routes with next-hop self and the next hop remains unchanged. The failure impact radius is only 1 hop.

One of the disadvantage of BGP was that BGP did not have neighbor discovery like IGP protocols have. However SR Linux can automatically establish BGP peers using the BGP Unnumbered feature. BGP unnumbered involves setting up BGP sessions without allocating a specific, unique IP address for each interface engaging in a BGP session.

BGP IPv6 Unnumbered utilizes:

* **IPv6 Link-Local Addresses:** Employed for communication on the same network segment, these addresses aren't routed outside their segment. In unnumbered BGP configurations, interfaces use IPv6 link-local addresses to form BGP sessions without needing a unique global IP address per interface.

* **Router Advertisements:** As part of the Neighbor Discovery Protocol, Router Advertisements enable routers to broadcast their presence and share various information about the link and the Internet Layer on an IPv6 subnet. In BGP unnumbered, RA messages are used to announce/learn the peer’s link-local address.

In the diagram below, a Spine is dynamically peering eBGP with each Leaf using IPv6 unnumbered. This is what we will achieve at the end of this chapter.

<p align="center">
  <img src="https://github.com/srl-labs/srl-l3evpn-tutorial-lab/blob/main/images/fabric.png?raw=true" alt="Fabric Diagram" width="600">
</p>

### Physical Interface Configuration

The initial step involves setting up the physical interfaces for SRLinux to connect and initiate BGP peerings with other routers in the DC fabric.

On each leaf and spine we will bring up the relevant [interface](../../kb/ifaces.md) and configure a routed [subinterface](../../kb/ifaces.md#subinterfaces) to achieve L3 connectivity.

We begin with connecting to the CLI of our nodes via SSH[^1]:

```bash
# connecting to leaf1
ssh clab-l3evpn-leaf1
```

Then on each node we enter into [candidate configuration mode](../../kb/cfgmgmt.md#configuration-modes) and proceed with the relevant interfaces' configuration.

Let's witness the step by step process of an interface configuration on a `leaf1` switch with providing the paste-able snippets for the rest of the nodes

1. Enter the `candidate` configuration mode to make edits to the configuration

    ```srl
    Welcome to the srlinux CLI.
    Type 'help' (and press <ENTER>) if you need any help using this.


    --{ running }--[  ]--
    A:leaf1# enter candidate
    ```

2. The prompt will indicate we entered the candidate data store. In the following steps we will enter the commands to make changes to the candidate config and at the end we will commit.

    ```srl
    --{ candidate shared default }--[  ]--
    A:leaf1#                              
    ```

4. Create a subinterface under a physical interface and enable IPv6. We will not configure an IP address but a link-local address will be automatically configured for this interface.

    ```srl
    set / interface ethernet-1/49 subinterface 1 ipv6 admin-state enable
    ```

5. Configure the interface to send router advertisement messages to directly connected peers, informing them of the interface's IP address.

    ```srl
    set / interface ethernet-1/49 subinterface 1 ipv6 router-advertisement router-role admin-state enable
    ```

6. Attach the configured subinterfaces to the default network instance (aka GRT).

    ```srl
    set / network-instance default interface ethernet-1/49.1
    ```

7. Apply the configuration changes by issuing a `commit now` command. The changes will be written to the running configuration.

    ```srl
    commit now                                                                                        
    ```

Below you will find the relevant configuration snippets[^2] for leafs and spine of our fabric which you can paste in the terminal while being in candidate mode.

/// tab | leaf1

```srl
set / interface ethernet-1/49 admin-state enable
set / interface ethernet-1/49 subinterface 1 ipv6 admin-state enable
set / interface ethernet-1/49 subinterface 1 ipv6 router-advertisement router-role admin-state enable

set / network-instance default interface ethernet-1/49.1
```

///

/// tab | leaf2

```srl
set / interface ethernet-1/49 admin-state enable
set / interface ethernet-1/49 subinterface 1 ipv6 admin-state enable
set / interface ethernet-1/49 subinterface 1 ipv6 router-advertisement router-role admin-state enable

set / network-instance default interface ethernet-1/49.1
```

///

/// tab | spine

```srl
set / interface ethernet-1/1 admin-state enable
set / interface ethernet-1/1 subinterface 1 ipv6 admin-state enable
set / interface ethernet-1/1 subinterface 1 ipv6 router-advertisement router-role admin-state enable

set / interface ethernet-1/2 admin-state enable
set / interface ethernet-1/2 subinterface 1 ipv6 admin-state enable
set / interface ethernet-1/2 subinterface 1 ipv6 router-advertisement router-role admin-state enable

set / network-instance default interface ethernet-1/1.1
set / network-instance default interface ethernet-1/2.1
```

///

Once those snippets are committed to the running configuration with `commit now` command, we can ensure that the changes have been applied by showing the interface status.

Below highlighted, you will see that an IPv6 link-layer address is auto assigned to each interface. This address is not routable and is not announced to other peers by default.

/// tab | leaf1

```srl hl_lines="10"
--{ running }--[  ]--
A:leaf1# show interface ethernet-1/49
====================================================================
ethernet-1/49 is up, speed 100G, type None
  ethernet-1/49.1 is up
    Network-instances:
      * Name: default (default)
    Encapsulation   : null
    Type            : routed
    IPv6 addr    : fe80::1805:2ff:feff:31/64 (link-layer, preferred)
--------------------------------------------------------------------
====================================================================

--{ running }--[  ]--

```

///

/// tab | leaf2

```srl hl_lines="10"
--{ running }--[  ]--
A:leaf2# show interface ethernet-1/49
====================================================================
ethernet-1/49 is up, speed 100G, type None
  ethernet-1/49.1 is up
    Network-instances:
      * Name: default (default)
    Encapsulation   : null
    Type            : routed
    IPv6 addr    : fe80::18d9:3ff:feff:31/64 (link-layer, preferred)
--------------------------------------------------------------------
====================================================================

--{ running }--[  ]--
```

///

/// tab | spine

```srl hl_lines="10 18"

--{ running }--[  ]--
A:spine# show interface ethernet-1/{1..2}
====================================================================
ethernet-1/1 is up, speed 100G, type None
  ethernet-1/1.1 is up
    Network-instances:
      * Name: default (default)
    Encapsulation   : null
    Type            : routed
    IPv6 addr    : fe80::181d:4ff:feff:1/64 (link-layer, preferred)
--------------------------------------------------------------------
ethernet-1/2 is up, speed 100G, type None
  ethernet-1/2.1 is up
    Network-instances:
      * Name: default (default)
    Encapsulation   : null
    Type            : routed
    IPv6 addr    : fe80::181d:4ff:feff:2/64 (link-layer, preferred)
--------------------------------------------------------------------
====================================================================

--{ running }--[  ]--
```

///

Below is the ARP/ND neighbors list, constructed from the received Router Advertisement messages from the link. The critical information is the neighbor IP address.

/// tab | leaf1

```srl
--{ running }--[  ]--
A:leaf1# show arpnd neighbors interface ethernet-1/49
+-------------------+-------------------+----------------------------------------+-------------------+--------------------------------------+-------------------+--------------------------------------+-------------------+
|     Interface     |   Subinterface    |                Neighbor                |      Origin       |          Link layer address          |   Current state   |          Next state change           |     Is Router     |
+===================+===================+========================================+===================+======================================+===================+======================================+===================+
| ethernet-1/49     |                 1 |                  fe80::181d:4ff:feff:1 |           dynamic | 1A:1D:04:FF:00:01                    | stale             | 3 hours from now                     | true              |
+-------------------+-------------------+----------------------------------------+-------------------+--------------------------------------+-------------------+--------------------------------------+-------------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Total entries : 1 (0 static, 1 dynamic)
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--{ running }--[  ]--
```

///

/// tab | leaf2

```srl
--{ running }--[  ]--
A:leaf2# show arpnd neighbors interface ethernet-1/49
+-------------------+-------------------+----------------------------------------+-------------------+--------------------------------------+-------------------+--------------------------------------+-------------------+
|     Interface     |   Subinterface    |                Neighbor                |      Origin       |          Link layer address          |   Current state   |          Next state change           |     Is Router     |
+===================+===================+========================================+===================+======================================+===================+======================================+===================+
| ethernet-1/49     |                 1 |                  fe80::181d:4ff:feff:2 |           dynamic | 1A:1D:04:FF:00:02                    | stale             | 3 hours from now                     | false             |
+-------------------+-------------------+----------------------------------------+-------------------+--------------------------------------+-------------------+--------------------------------------+-------------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Total entries : 1 (0 static, 1 dynamic)
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--{ running }--[  ]--
```

///

/// tab | spine

```srl
--{ running }--[  ]--
A:spine# show arpnd neighbors interface ethernet-1/{1..2}
+-------------------+-------------------+----------------------------------------+-------------------+--------------------------------------+-------------------+--------------------------------------+-------------------+
|     Interface     |   Subinterface    |                Neighbor                |      Origin       |          Link layer address          |   Current state   |          Next state change           |     Is Router     |
+===================+===================+========================================+===================+======================================+===================+======================================+===================+
| ethernet-1/1      |                 1 |                 fe80::1805:2ff:feff:31 |           dynamic | 1A:05:02:FF:00:31                    | stale             | 3 hours from now                     | true              |
| ethernet-1/2      |                 1 |                 fe80::18d9:3ff:feff:31 |           dynamic | 1A:D9:03:FF:00:31                    | stale             | 3 hours from now                     | false             |
+-------------------+-------------------+----------------------------------------+-------------------+--------------------------------------+-------------------+--------------------------------------+-------------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Total entries : 2 (0 static, 2 dynamic)
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--{ running }--[  ]--
```

///

### eBGP Unnumbered for Underlay Routing

Now we will set up the routing protocol that will be used for exchang loopback addresses throughout the fabric. These loopbacks will be used to set up iBGP EVPN peerings, which we will cover in the following chapter.

Here is a breakdown of the steps that are needed to configure eBGP on `leaf1` towards `spine`:

1. **Assign Autonomous System Number**  
    We will use eBGP, so each router needs a unique base AS number. Typically, leaf pairs share the same unique AS number, as do spine routers. This configuration prevents routing loops, as routes announced between leaf pairs or between spines are ignored.

    ```srl
    set / network-instance default protocols bgp autonomous-system 4200000001
    ```

1. **Assign a unique Router ID**  
    This is the BGP identifier reported to peers when this network-instance opens a BGP session towards another router.  

    ```srl
    set / network-instance default protocols bgp router-id 100.0.0.1
    ```

1. **Enable Address Family**  
    Currently only VxLAN v4 is supported and therefore we need the BGP IPv4 family to exchange the IPv4 loopback IPs that are needed for VxLAN termination.

    ```srl
    set / network-instance default protocols bgp afi-safi ipv4-unicast admin-state enable
    ```

1. **Allow Route Advertisement for eBGP**  
   eBGP assumes that peers are external systems and by default all incoming and outgoing routes are blocked. We will disable this behavior and permit all incoming and outgoing routes.

    ```srl
    set / network-instance default protocols bgp eBGP-default-policy import-reject-all false
    set / network-instance default protocols bgp eBGP-default-policy export-reject-all false
    ```

1. **Create BGP peer-group**  
    A BGP peer group simplifies configuring multiple BGP peers with similar requirements by grouping them together, allowing the same policies and attributes to be applied to all peers in the group simultaneously. Here we create a group named underlay to be used for the eBGP peerings.
  
    ```srl
    set / network-instance default protocols bgp group underlay
    ```

1. **Configure dynamic neighbor**  
    We will configure the dynamic neighbor feature to establish eBGP over leaf-spine links.

    ```srl
    set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/49.1
    ```

    Then we assign this interface to the BGP group

    ```srl
    set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/49.1 peer-group underlay
    ```

    And we define the AS range for this router should accept dynamic peering from, in this case we defined the whole range.

    ```srl
    set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/49.1 allowed-peer-as [ 1..4294967295 ]
    ```

    **{Optional}** It is also possible to only allow peers that match a certain prefix.

    ```srl
    set / network-instance default protocols bgp dynamic-neighbors accept match fe80::/10 peer-group underlay
    ```

2. **Commit configuration**  

    Once we apply the config above (whole snippet below), we should have BGP peerings automatically established.

    ```srl
    --{ +* candidate shared default }--[ network-instance default protocols bgp ]--
    A:leaf1# commit now
    ```

Here are the config snippets per device for easy copy paste:

/// tab | leaf1

```srl
set / network-instance default protocols bgp autonomous-system 4200000001
set / network-instance default protocols bgp router-id 100.0.0.1

set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/49.1 peer-group underlay
set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/49.1 allowed-peer-as [ 1..4294967295 ]

set / network-instance default protocols bgp eBGP-default-policy import-reject-all false
set / network-instance default protocols bgp eBGP-default-policy export-reject-all false

set / network-instance default protocols bgp afi-safi ipv4-unicast admin-state enable

set / network-instance default protocols bgp group underlay
```

///

/// tab | leaf2

```srl
set / network-instance default protocols bgp autonomous-system 4200000002
set / network-instance default protocols bgp router-id 100.0.0.2

set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/49.1 peer-group underlay
set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/49.1 allowed-peer-as [ 1..4294967295 ]

set / network-instance default protocols bgp eBGP-default-policy import-reject-all false
set / network-instance default protocols bgp eBGP-default-policy export-reject-all false

set / network-instance default protocols bgp afi-safi ipv4-unicast admin-state enable

set / network-instance default protocols bgp group underlay
```

///

/// tab | spine

```srl
set / network-instance default protocols bgp autonomous-system 65000
set / network-instance default protocols bgp router-id 100.100.100.100

set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/1.1 peer-group underlay
set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/1.1 allowed-peer-as [ 1..4294967295 ]
set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/2.1 peer-group underlay
set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/2.1 allowed-peer-as [ 1..4294967295 ]

set / network-instance default protocols bgp eBGP-default-policy import-reject-all false
set / network-instance default protocols bgp eBGP-default-policy export-reject-all false

set / network-instance default protocols bgp afi-safi ipv4-unicast admin-state enable
set / network-instance default protocols bgp afi-safi ipv4-unicast export-policy announce_system_IP

set / network-instance default protocols bgp group underlay
```

///

### Loopback Interface for EVPN peering and VxLAN Termination

As we will create an iBGP based EVPN control plane at a later stage, we need to configure loopback addresses for our leaf devices so that they can build an iBGP peering over those interfaces.

In the context of the VXLAN data plane, a special kind of a loopback needs to be created - [`system0`](../../kb/ifaces.md#system) interface.

/// note
The `system0.0` interface hosts the loopback address used to originate and typically
terminate VXLAN packets. This address is also used by default as the next-hop of all
EVPN routes.
///

Configuration of the `system0` interface is exactly the same as for the regular interfaces.  As a best practice, the IPv4 addresses assigned to `system0` interfaces will be identical to the Router-ID.

/// tab | leaf1

```srl
set / interface system0 subinterface 0 ipv4 admin-state enable
set / interface system0 subinterface 0 ipv4 address 100.0.0.1/32

```

///

/// tab | leaf2

```srl
set / interface system0 subinterface 0 ipv4 admin-state enable
set / interface system0 subinterface 0 ipv4 address 100.0.0.2/32

```

///

/// tab | spine

```srl
set / interface system0 subinterface 0 ipv4 admin-state enable
set / interface system0 subinterface 0 ipv4 address 100.100.100.100/32
```

///

Then we will need to add the loopback/system interface to the default network instance

```srl
set / network-instance default interface system0.0
```

By default, BGP does not announce the local interface IPs, therefore we need an export policy. The policy below will announce all locally configured interfaces on the network instance but since link-local addresses are not announced and that is all we have, only the system IP (loopback) will be announced to the peers. If you wish to, you can configure a more specific export policy matching a prefix list.

```srl
set / routing-policy policy announce_system_IP statement 1 match protocol local
set / routing-policy policy announce_system_IP statement 1 action policy-result accept

set / network-instance default protocols bgp afi-safi ipv4-unicast export-policy announce_system_IP
```

After committing the configs above, a System Interface will be configured with a unique IP address (identical to the BGP Router ID as best practice) and that IP will be exported to the eBGP and announced to the neighbors.

**Allow IPv4 packets on IPv6-only Interfaces**

The fabric will use IPv6 interfaces to route IPv4 packets. By default, SRLinux drops IPv4 packets if the receiving interface lacks an operational IPv4 subinterface. To change this and allow IPv4 packets on IPv6-only interfaces, use the following system-wide config knob.

```srl
set / network-instance default ip-forwarding receive-ipv4-check false
```

### Verification

As stated in the beginning of this section, the VxLAN VTEPs need to be advertised throughout the DC fabric. The `system0` interfaces we just configured are the VTEPs and they should be advertised via eBGP peering established before. The following verification commands can help ensure that.

**BGP neighbor status**

First, verify that the eBGP peerings are in the established state using BGP Family IPv4-Unicast. Note that all peerings are dynamic, automatically configured using the dynamic-peering feature.

/// tab | leaf1

```srl
A:leaf1# show network-instance default protocols bgp neighbor
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+------------------------+-----------------------------------+------------------------+--------+-------------+-------------------+-------------------+-----------------+-----------------------------------+
|        Net-Inst        |               Peer                |         Group          | Flags  |   Peer-AS   |       State       |      Uptime       |    AFI/SAFI     |          [Rx/Active/Tx]           |
+========================+===================================+========================+========+=============+===================+===================+=================+===================================+
| default                | fe80::181d:4ff:feff:1%ethernet-   | underlay               | D      | 65000       | established       | 0d:0h:5m:3s       | ipv4-unicast    | [2/2/1]                           |
|                        | 1/49.1                            |                        |        |             |                   |                   |                 |                                   |
+------------------------+-----------------------------------+------------------------+--------+-------------+-------------------+-------------------+-----------------+-----------------------------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Summary:
0 configured neighbors, 0 configured sessions are established,0 disabled peers
1 dynamic peers
```

///

/// tab | leaf2

```srl
A:leaf2# show network-instance default protocols bgp neighbor
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+------------------------+-----------------------------------+------------------------+--------+-------------+-------------------+-------------------+-----------------+-----------------------------------+
|        Net-Inst        |               Peer                |         Group          | Flags  |   Peer-AS   |       State       |      Uptime       |    AFI/SAFI     |          [Rx/Active/Tx]           |
+========================+===================================+========================+========+=============+===================+===================+=================+===================================+
| default                | fe80::181d:4ff:feff:2%ethernet-   | underlay               | D      | 65000       | established       | 0d:0h:7m:59s      | ipv4-unicast    | [2/2/1]                           |
|                        | 1/49.1                            |                        |        |             |                   |                   |                 |                                   |
+------------------------+-----------------------------------+------------------------+--------+-------------+-------------------+-------------------+-----------------+-----------------------------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Summary:
0 configured neighbors, 0 configured sessions are established,0 disabled peers
1 dynamic peers
```

///

/// tab | spine

```srl
A:spine# show network-instance default protocols bgp neighbor
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+------------------------+-----------------------------------+------------------------+--------+-------------+-------------------+-------------------+-----------------+-----------------------------------+
|        Net-Inst        |               Peer                |         Group          | Flags  |   Peer-AS   |       State       |      Uptime       |    AFI/SAFI     |          [Rx/Active/Tx]           |
+========================+===================================+========================+========+=============+===================+===================+=================+===================================+
| default                | fe80::1805:2ff:feff:31%ethernet-  | underlay               | D      | 4200000001  | established       | 0d:0h:6m:28s      | ipv4-unicast    | [1/1/2]                           |
|                        | 1/1.1                             |                        |        |             |                   |                   |                 |                                   |
| default                | fe80::18d9:3ff:feff:31%ethernet-  | underlay               | D      | 4200000002  | established       | 0d:0h:8m:27s      | ipv4-unicast    | [1/1/2]                           |
|                        | 1/2.1                             |                        |        |             |                   |                   |                 |                                   |
+------------------------+-----------------------------------+------------------------+--------+-------------+-------------------+-------------------+-----------------+-----------------------------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Summary:
0 configured neighbors, 0 configured sessions are established,0 disabled peers
2 dynamic peers
```

///

**Advertised routes**

We configured eBGP in the fabric's underlay to advertise the VxLAN tunnel endpoints. The output below verifies that the routers are advertising the prefix of the `system0` interface to their eBGP peers:

/// tab | leaf1

```srl hl_lines="12"
A:leaf1# show network-instance default protocols bgp neighbor fe80::181d:4ff:feff:1%ethernet-1/49.1 advertised-routes ipv4
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Peer        : fe80::181d:4ff:feff:1%ethernet-1/49.1, remote AS: 65000, local AS: 4200000001
Type        : static
Description : None
Group       : underlay
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Origin codes: i=IGP, e=EGP, ?=incomplete
+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                 Network                              Path-id                   Next Hop                 MED                                     LocPref                                   AsPath               Origin      |
+============================================================================================================================================================================================================================+
| 100.0.0.1/32                              0                               fe80::1805:2ff:feff            -                                        100                               [4200000001]                  i        |
|                                                                           :31                                                                                                                                              |
+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
1 advertised BGP routes
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

///

/// tab | leaf2

```srl hl_lines="12"
A:leaf2# show network-instance default protocols bgp neighbor fe80::181d:4ff:feff:2%ethernet-1/49.1 advertised-routes ipv4
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Peer        : fe80::181d:4ff:feff:2%ethernet-1/49.1, remote AS: 65000, local AS: 4200000002
Type        : static
Description : None
Group       : underlay
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Origin codes: i=IGP, e=EGP, ?=incomplete
+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                 Network                              Path-id                   Next Hop                 MED                                     LocPref                                   AsPath               Origin      |
+============================================================================================================================================================================================================================+
| 100.0.0.2/32                              0                               fe80::18d9:3ff:feff            -                                        100                               [4200000002]                  i        |
|                                                                           :31                                                                                                                                              |
+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
1 advertised BGP routes
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

///

/// tab | spine

```srl hl_lines="12 14 33 35"
A:spine# show network-instance default protocols bgp neighbor  fe80::1805:2ff:feff:31%ethernet-1/1.1 advertised-routes ipv4
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Peer        : fe80::1805:2ff:feff:31%ethernet-1/1.1, remote AS: 4200000001, local AS: 65000
Type        : static
Description : None
Group       : underlay
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Origin codes: i=IGP, e=EGP, ?=incomplete
+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                 Network                              Path-id                   Next Hop                 MED                                     LocPref                                   AsPath               Origin      |
+============================================================================================================================================================================================================================+
| 100.0.0.2/32                              0                               fe80::181d:4ff:feff            -                                        100                               [65000, 4200000002]           i        |
|                                                                           :1                                                                                                                                               |
| 100.100.100.100/32                        0                               fe80::181d:4ff:feff            -                                        100                               [65000]                       i        |
|                                                                           :1                                                                                                                                               |
+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
2 advertised BGP routes
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


A:spine# show network-instance default protocols bgp neighbor fe80::18d9:3ff:feff:31%ethernet-1/2.1 advertised-routes ipv4
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Peer        : fe80::18d9:3ff:feff:31%ethernet-1/2.1, remote AS: 4200000002, local AS: 65000
Type        : static
Description : None
Group       : underlay
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Origin codes: i=IGP, e=EGP, ?=incomplete
+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                 Network                              Path-id                   Next Hop                 MED                                     LocPref                                   AsPath               Origin      |
+============================================================================================================================================================================================================================+
| 100.0.0.1/32                              0                               fe80::181d:4ff:feff            -                                        100                               [65000, 4200000001]           i        |
|                                                                           :2                                                                                                                                               |
| 100.100.100.100/32                        0                               fe80::181d:4ff:feff            -                                        100                               [65000]                       i        |
|                                                                           :2                                                                                                                                               |
+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
2 advertised BGP routes
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

///

**Route table**

The last stop in the control plane verification would be to check if the remote loopback prefixes were installed in the `default` network-instance where we expect them to be:

/// tab | leaf1

```srl hl_lines="11 13"
A:leaf1# show network-instance default route-table
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance default
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+---------------------------------+-------+------------+----------------------+----------+----------+---------+------------+--------------------+--------------------+--------------------+------------------------------------+
|             Prefix              |  ID   | Route Type |     Route Owner      |  Active  |  Origin  | Metric  |    Pref    |  Next-hop (Type)   | Next-hop Interface |  Backup Next-hop   |     Backup Next-hop Interface      |
|                                 |       |            |                      |          | Network  |         |            |                    |                    |       (Type)       |                                    |
|                                 |       |            |                      |          | Instance |         |            |                    |                    |                    |                                    |
+=================================+=======+============+======================+==========+==========+=========+============+====================+====================+====================+====================================+
| 100.0.0.1/32                    | 4     | host       | net_inst_mgr         | True     | default  | 0       | 0          | None (extract)     | None               |                    |                                    |
| 100.0.0.2/32                    | 0     | bgp        | bgp_mgr              | True     | default  | 0       | 170        | fe80::181d:4ff:fef | ethernet-1/49.1    |                    |                                    |
|                                 |       |            |                      |          |          |         |            | f:1 (direct)       |                    |                    |                                    |
| 100.100.100.100/32              | 0     | bgp        | bgp_mgr              | True     | default  | 0       | 170        | fe80::181d:4ff:fef | ethernet-1/49.1    |                    |                                    |
|                                 |       |            |                      |          |          |         |            | f:1 (direct)       |                    |                    |                                    |
+---------------------------------+-------+------------+----------------------+----------+----------+---------+------------+--------------------+--------------------+--------------------+------------------------------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 routes total                    : 3
IPv4 prefixes with active routes     : 3
IPv4 prefixes with active ECMP routes: 0
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

///

/// tab | leaf2

```srl hl_lines="10 13"
A:leaf2# show network-instance default route-table
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance default
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+---------------------------------+-------+------------+----------------------+----------+----------+---------+------------+--------------------+--------------------+--------------------+------------------------------------+
|             Prefix              |  ID   | Route Type |     Route Owner      |  Active  |  Origin  | Metric  |    Pref    |  Next-hop (Type)   | Next-hop Interface |  Backup Next-hop   |     Backup Next-hop Interface      |
|                                 |       |            |                      |          | Network  |         |            |                    |                    |       (Type)       |                                    |
|                                 |       |            |                      |          | Instance |         |            |                    |                    |                    |                                    |
+=================================+=======+============+======================+==========+==========+=========+============+====================+====================+====================+====================================+
| 100.0.0.1/32                    | 0     | bgp        | bgp_mgr              | True     | default  | 0       | 170        | fe80::181d:4ff:fef | ethernet-1/49.1    |                    |                                    |
|                                 |       |            |                      |          |          |         |            | f:2 (direct)       |                    |                    |                                    |
| 100.0.0.2/32                    | 4     | host       | net_inst_mgr         | True     | default  | 0       | 0          | None (extract)     | None               |                    |                                    |
| 100.100.100.100/32              | 0     | bgp        | bgp_mgr              | True     | default  | 0       | 170        | fe80::181d:4ff:fef | ethernet-1/49.1    |                    |                                    |
|                                 |       |            |                      |          |          |         |            | f:2 (direct)       |                    |                    |                                    |
+---------------------------------+-------+------------+----------------------+----------+----------+---------+------------+--------------------+--------------------+--------------------+------------------------------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 routes total                    : 3
IPv4 prefixes with active routes     : 3
IPv4 prefixes with active ECMP routes: 0
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

///

/// tab | spine

```srl hl_lines="10 12"
A:spine# show network-instance default route-table
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance default
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+---------------------------------+-------+------------+----------------------+----------+----------+---------+------------+--------------------+--------------------+--------------------+------------------------------------+
|             Prefix              |  ID   | Route Type |     Route Owner      |  Active  |  Origin  | Metric  |    Pref    |  Next-hop (Type)   | Next-hop Interface |  Backup Next-hop   |     Backup Next-hop Interface      |
|                                 |       |            |                      |          | Network  |         |            |                    |                    |       (Type)       |                                    |
|                                 |       |            |                      |          | Instance |         |            |                    |                    |                    |                                    |
+=================================+=======+============+======================+==========+==========+=========+============+====================+====================+====================+====================================+
| 100.0.0.1/32                    | 0     | bgp        | bgp_mgr              | True     | default  | 0       | 170        | fe80::1805:2ff:fef | ethernet-1/1.1     |                    |                                    |
|                                 |       |            |                      |          |          |         |            | f:31 (direct)      |                    |                    |                                    |
| 100.0.0.2/32                    | 0     | bgp        | bgp_mgr              | True     | default  | 0       | 170        | fe80::18d9:3ff:fef | ethernet-1/2.1     |                    |                                    |
|                                 |       |            |                      |          |          |         |            | f:31 (direct)      |                    |                    |                                    |
| 100.100.100.100/32              | 4     | host       | net_inst_mgr         | True     | default  | 0       | 0          | None (extract)     | None               |                    |                                    |
+---------------------------------+-------+------------+----------------------+----------+----------+---------+------------+--------------------+--------------------+--------------------+------------------------------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 routes total                    : 3
IPv4 prefixes with active routes     : 3
IPv4 prefixes with active ECMP routes: 0
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

///

Both learned prefixes appear in the route table of the default network instance, with bgp_mgr as their owner, indicating they were added by the BGP process. The system0 interface prefix owner is the network instance manager, signifying it is a local prefix.

**Dataplane**

To finish the verification process let's ensure that the datapath is indeed working, and the VTEPs on both leafs can reach each other via the routed fabric underlay.

For that we will use the `ping` command with src/dst set to loopback addresses:

```
A:leaf1# ping network-instance default 100.0.0.2 -I 100.0.0.1 -c 3
Using network instance default
PING 100.0.0.2 (100.0.0.2) from 100.0.0.1 : 56(84) bytes of data.
64 bytes from 100.0.0.2: icmp_seq=1 ttl=63 time=4.72 ms
64 bytes from 100.0.0.2: icmp_seq=2 ttl=63 time=5.71 ms
64 bytes from 100.0.0.2: icmp_seq=3 ttl=63 time=5.64 ms

--- 100.0.0.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2004ms
rtt min/avg/max/mdev = 4.722/5.355/5.707/0.448 ms

```

Perfect, the VTEPs are reachable and the fabric underlay is properly configured. We can proceed with EVPN service configuration!

### Resulting configs

Below you will find aggregated configuration snippets which contain the entire fabric configuration we did in the steps above. Those snippets are in the _flat_ format and were extracted with `info flat` command.

/// note
`enter candidate` and `commit now` commands are part of the snippets, so it is possible to paste them right after you logged into the devices as well as the changes will get committed to running config.
///

/// tab | leaf1

```srl
enter candidate

# Allow IPv4 packets on an IPv6 interface
set / network-instance default ip-forwarding receive-ipv4-check false

# Configure the link and enable the IPv6 subinterface
set / interface ethernet-1/49 admin-state enable
set / interface ethernet-1/49 subinterface 1 ipv6 admin-state enable
set / interface ethernet-1/49 subinterface 1 ipv6 router-advertisement router-role admin-state enable

# Configure the system interface
set / interface system0 subinterface 0 ipv4 admin-state enable
set / interface system0 subinterface 0 ipv4 address 100.0.0.1/32

# Add interfaces to default routing instance
set / network-instance default interface ethernet-1/49.1
set / network-instance default interface system0.0

# Policy to export local routes (system) to BGP neighbors
set / routing-policy policy announce_system_IP statement 1 match protocol local
set / routing-policy policy announce_system_IP statement 1 action policy-result accept

# BGP Configuration
set / network-instance default protocols bgp autonomous-system 4200000001
set / network-instance default protocols bgp router-id 100.0.0.1
set / network-instance default protocols bgp group underlay

set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/49.1 peer-group underlay
set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/49.1 allowed-peer-as [ 1..4294967295 ]

set / network-instance default protocols bgp ebgp-default-policy import-reject-all false
set / network-instance default protocols bgp ebgp-default-policy export-reject-all false

set / network-instance default protocols bgp afi-safi ipv4-unicast admin-state enable
set / network-instance default protocols bgp afi-safi ipv4-unicast export-policy announce_system_IP

commit now
```

///

/// tab | leaf2

```srl
enter candidate

# Allow IPv4 packets on an IPv6 interface
set / network-instance default ip-forwarding receive-ipv4-check false

# Configure the link and enable the IPv6 subinterface
set / interface ethernet-1/49 admin-state enable
set / interface ethernet-1/49 subinterface 1 ipv6 admin-state enable
set / interface ethernet-1/49 subinterface 1 ipv6 router-advertisement router-role admin-state enable

# Configure the system interface
set / interface system0 subinterface 0 ipv4 admin-state enable
set / interface system0 subinterface 0 ipv4 address 100.0.0.2/32

# Add interfaces to default routing instance
set / network-instance default interface ethernet-1/49.1
set / network-instance default interface system0.0

# Policy to export local routes (system) to BGP neighbors
set / routing-policy policy announce_system_IP statement 1 match protocol local
set / routing-policy policy announce_system_IP statement 1 action policy-result accept

# BGP Configuration
set / network-instance default protocols bgp autonomous-system 4200000002
set / network-instance default protocols bgp router-id 100.0.0.2
set / network-instance default protocols bgp group underlay

set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/49.1 peer-group underlay
set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/49.1 allowed-peer-as [ 1..4294967295 ]

set / network-instance default protocols bgp ebgp-default-policy import-reject-all false
set / network-instance default protocols bgp ebgp-default-policy export-reject-all false

set / network-instance default protocols bgp afi-safi ipv4-unicast admin-state enable
set / network-instance default protocols bgp afi-safi ipv4-unicast export-policy announce_system_IP

commit now
```

///

/// tab | spine

```srl
enter candidate

# Allow IPv4 packets on an IPv6 interface
set / network-instance default ip-forwarding receive-ipv4-check false

# Configure the link and enable the IPv6 subinterface
set / interface ethernet-1/1 admin-state enable
set / interface ethernet-1/1 subinterface 1 ipv6 admin-state enable
set / interface ethernet-1/1 subinterface 1 ipv6 router-advertisement router-role admin-state enable
set / interface ethernet-1/2 admin-state enable
set / interface ethernet-1/2 subinterface 1 ipv6 admin-state enable
set / interface ethernet-1/2 subinterface 1 ipv6 router-advertisement router-role admin-state enable


# Configure the system interface
set / interface system0 subinterface 0 ipv4 admin-state enable
set / interface system0 subinterface 0 ipv4 address 100.100.100.100/32

# Add interfaces to default routing instance
set / network-instance default interface ethernet-1/1.1
set / network-instance default interface ethernet-1/2.1
set / network-instance default interface system0.0

# Policy to export local routes (system) to BGP neighbors
set / routing-policy policy announce_system_IP statement 1 match protocol local
set / routing-policy policy announce_system_IP statement 1 action policy-result accept

# BGP Configuration
set / network-instance default protocols bgp autonomous-system 65000
set / network-instance default protocols bgp router-id 100.100.100.100

set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/1.1 peer-group underlay
set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/1.1 allowed-peer-as [ 1..4294967295 ]

set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/2.1 peer-group underlay
set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/2.1 allowed-peer-as [ 1..4294967295 ]

set / network-instance default protocols bgp ebgp-default-policy import-reject-all false
set / network-instance default protocols bgp ebgp-default-policy export-reject-all false

set / network-instance default protocols bgp afi-safi ipv4-unicast admin-state enable
set / network-instance default protocols bgp afi-safi ipv4-unicast export-policy announce_system_IP

set / network-instance default protocols bgp group underlay

commit now
```

///

## Overlay Routing

The BGP EVPN family facilitates the exchange of overlay routes. Further details on EVPN and its mechanisms will be discussed in subsequent chapter. In this section we will focus on how BGP EVPN is configured.

Typically, Route Reflectors (RRs) are used for iBGP peering instead of configuring a full mesh. Utilizing RRs reduces the number of BGP sessions, requiring only peering with RRs. This approach minimizes configuration efforts and allows for centralized application of routing policies.

In our case Spine will be the EVPN RR and Leaves will be the client.

1. **Create BGP peer-group**  
    A BGP peer group simplifies configuring multiple BGP peers with similar requirements by grouping them together.
  
    ```srl
    set / network-instance default protocols bgp group overlay
    ```

1. **Assign Autonomous System Number**  
    We'll use iBGP with the EVPN family, meaning all routers in this data center will share the same AS number for overlay route exchange.

    ```srl
    set / network-instance default protocols bgp group overlay peer-as 55555
    set / network-instance default protocols bgp group overlay local-as as-number 55555
    ```

1. **Enable Address Family**  
    Here we are enabling the EVPN address family and disabling the IPv4 family for the overlay BGP group.

    ```srl
    set / network-instance default protocols bgp group evpn afi-safi evpn admin-state enable
    set / network-instance default protocols bgp group evpn afi-safi ipv4-unicast admin-state disable
    ```

1. **Configure the neighbor**  

    /// tab | leaf1 & leaf2
    Leaf devices uses Spine's System IP for BGP EVPN peering.

    ```srl
    set / network-instance default protocols bgp neighbor 100.100.100.100 admin-state enable
    set / network-instance default protocols bgp neighbor 100.100.100.100 peer-group overlay
    ```

    ///

    /// tab | spine ( RR )
    Spine is configured to establish dynamic peering with any IP address.

    ```srl
    set / network-instance default protocols bgp dynamic-neighbors accept match 0.0.0.0/0 peer-group overlay
    ```

    ///

1. **Configure EVPN Route Reflector (only on spine)**  

    The command below will enable the route reflector functionality and only needs to be enabled on the Spine.
    /// tab | spine

    ```srl
    set / network-instance default protocols bgp group overlay route-reflector client true
    ```

    ///

### Verification

The eBGP IPv4 sessions between Leaves and the spine is now active using IPv6 link-local addresses for peering. Through this eBGP peering, the IPv4 address family is distributing the loopback IPs across the DC.

Simultaneously, the iBGP EVPN address family, set up through the loopback addresses, supports the sharing of overlay routes, which will be covered in detail in the following chapter.

/// tab | leaf1

```srl
A:leaf1# show network-instance default protocols bgp neighbor
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
+------------------+--------------------------+------------------+------+----------+---------------+---------------+-------------+--------------------------+
|     Net-Inst     |           Peer           |      Group       | Flag | Peer-AS  |     State     |    Uptime     |  AFI/SAFI   |      [Rx/Active/Tx]      |
|                  |                          |                  |  s   |          |               |               |             |                          |
+==================+==========================+==================+======+==========+===============+===============+=============+==========================+
| default          | 100.100.100.100          | overlay          | S    | 55555    | established   | 0d:1h:13m:3s  | evpn        | [2/2/2]                  |
| default          | fe80::181d:4ff:feff:1%et | underlay         | D    | 65000    | established   | 0d:1h:13m:9s  | ipv4-       | [2/2/1]                  |
|                  | hernet-1/49.1            |                  |      |          |               |               | unicast     |                          |
+------------------+--------------------------+------------------+------+----------+---------------+---------------+-------------+--------------------------+
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
Summary:
1 configured neighbors, 1 configured sessions are established,0 disabled peers
1 dynamic peers
```

///

/// tab | leaf2

```srl
A:leaf2# show network-instance default protocols bgp neighbor
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
+------------------+--------------------------+------------------+------+----------+---------------+---------------+-------------+--------------------------+
|     Net-Inst     |           Peer           |      Group       | Flag | Peer-AS  |     State     |    Uptime     |  AFI/SAFI   |      [Rx/Active/Tx]      |
|                  |                          |                  |  s   |          |               |               |             |                          |
+==================+==========================+==================+======+==========+===============+===============+=============+==========================+
| default          | 100.100.100.100          | overlay          | S    | 55555    | established   | 0d:1h:13m:29s | evpn        | [2/2/2]                  |
| default          | fe80::181d:4ff:feff:2%et | underlay         | D    | 65000    | established   | 0d:1h:13m:35s | ipv4-       | [2/2/1]                  |
|                  | hernet-1/49.1            |                  |      |          |               |               | unicast     |                          |
+------------------+--------------------------+------------------+------+----------+---------------+---------------+-------------+--------------------------+
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
Summary:
1 configured neighbors, 1 configured sessions are established,0 disabled peers
1 dynamic peers
```

///

/// tab | spine

```srl
A:spine# show network-instance default protocols bgp neighbor
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
+------------------+--------------------------+------------------+------+----------+---------------+---------------+-------------+--------------------------+
|     Net-Inst     |           Peer           |      Group       | Flag | Peer-AS  |     State     |    Uptime     |  AFI/SAFI   |      [Rx/Active/Tx]      |
|                  |                          |                  |  s   |          |               |               |             |                          |
+==================+==========================+==================+======+==========+===============+===============+=============+==========================+
| default          | 100.0.0.1                | overlay          | D    | 55555    | established   | 0d:1h:12m:24s | evpn        | [2/0/2]                  |
| default          | 100.0.0.2                | overlay          | D    | 55555    | established   | 0d:1h:12m:29s | evpn        | [2/0/2]                  |
| default          | fe80::1805:2ff:feff:31%e | underlay         | D    | 42000000 | established   | 0d:1h:12m:36s | ipv4-       | [1/1/2]                  |
|                  | thernet-1/1.1            |                  |      | 01       |               |               | unicast     |                          |
| default          | fe80::18d9:3ff:feff:31%e | underlay         | D    | 42000000 | established   | 0d:1h:12m:31s | ipv4-       | [1/1/2]                  |
|                  | thernet-1/2.1            |                  |      | 02       |               |               | unicast     |                          |
+------------------+--------------------------+------------------+------+----------+---------------+---------------+-------------+--------------------------+
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
Summary:
0 configured neighbors, 0 configured sessions are established,0 disabled peers
4 dynamic peers
```

///

[^1]: default SR Linux credentials are `admin:NokiaSrl1!`.
[^2]: the snippets were extracted with `info flat` command issued in running mode.
