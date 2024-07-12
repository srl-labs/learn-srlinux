---
comments: true
---

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>

# Underlay Routing

Prior to configuring EVPN-based overlay and services, an underlay routing should be set up. The underlay routing ensures that all leaf VXLAN Termination End Points (VTEP) can reach each other via the IP fabric. This is typically done by leveraging a routing protocol to exchange loopback addresses of the leaf devices.

SR Linux supports the following routing protocols for the underlay network:

* ISIS
* OSPF
* BGP

BGP as a routing protocol for large IP fabrics was well defined in [RFC7938](https://datatracker.ietf.org/doc/html/rfc7938) and can offer the following:

* **Scalability:** BGP announces only the best paths, unlike IGPs that share the entire link state database. This may be important for very large fabrics and less so for smaller ones.
* **Flexible Policy Engine:** BGP provides numerous attributes for policy matching, offering extensive options for traffic steering.
* **Smaller Failure Impact Radius with BGP compared to IGP:**
    * In case of a link failure in an ISIS/OSPF network, all devices need to run SPF on the entire link state database. The blast radius is effectively the whole network.
    * In case of a link failure in an eBGP network, only devices one hop away need to recalculate the best path, this is because eBGP announces all routes with next-hop self and the next hop remains unchanged. The failure impact radius is only 1 hop.

Utilizing eBGP as an underlay routing protocol for our lab would be depicted as follows:

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":2,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>

Leaf devices will peer with the spine device over eBGP and exchange IPv4 loopback prefixes. The loopback prefixes will be used later on for iBGP peering using EVPN address family, we will get to that in the [overlay section](overlay.md) of this tutorial.

## BGP Unnumbered

One of the infamous BGP disadvantages was that BGP did not have a neighbor discovery feature like IGP protocols have. Without this feature operators had to configure addresses on every BGP link and that was mundane and error prone.

However, the popularity of BGP in the datacenter moved the needle in the right direction and today certain Network OS', SR Linux included, can setup BGP peering sessions with minimal effort using [IPv6 Link Local Address (LLA)](https://en.wikipedia.org/wiki/Link-local_address). And with [RFC 8950][RFC 8950] capability we can exchange IPv4 prefixes over the peering link with IPv6 nexthops.

/// admonition | BGP IPv6 Unnumbered
    type: quote
The dynamic setup of one or more single-hop BGP sessions over a network segment that has no globally-unique IPv4 or IPv6 addresses is often called **BGP IPv6 Unnumbered**.

Read more about it in the [SR Linux documentation][srl-unnumbered-docs].
///

BGP IPv6 Unnumbered utilizes:

* **IPv6 Link-Local Addresses (IPv6 LLA):** Employed for communication on the same network segment, these addresses aren't routed outside their segment. In unnumbered BGP configurations, interfaces use IPv6 link-local addresses to form BGP sessions without requiring a unique global IP address per interface.
* **Router Advertisements (RA):** As part of the Neighbor Discovery Protocol, Router Advertisements enable routers to broadcast their presence and share various information about the link and the Internet Layer on an IPv6 subnet. In BGP unnumbered, RA messages are used to announce/learn the peer’s link-local address.

## Physical Interfaces

The first thing we need to configure is the interfaces between the leaf and spine devices. According to the declarative definition of the lab topology file, our physical connections are as follows:

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":3,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>

The examples will target the highlighted interfaces between leaf1 and spine devices, but at the end of this section, you will find the configuration snippets for all devices.

We begin with connecting to the CLI of our nodes via SSH[^1]:

```bash
ssh l3evpn-leaf1
```

Let's got through a step by step process of an interface configuration on a `leaf1` switch:

1. Enter the `candidate` configuration mode to make edits to the configuration

    ```srl
    Welcome to the srlinux CLI.
    Type 'help' (and press <ENTER>) if you need any help using this.


    --{ running }--[  ]--
    A:leaf1# enter candidate

    --{ candidate shared default }--[  ]--
    A:leaf1#
    ```

    The prompt will indicate we entered the candidate data store. In the following steps we will enter the commands to make changes to the candidate config and at the end we will commit.

2. As a next step, we create a subinterface with index 1 under a physical `ethernet-1/49` interface that connects leaf1 to spine.
    In contrast with the L2 EVPN Tutorial, we will not configure an explicit IP address, but enable IPv6 with Router Advertisement messages on it . An IPv6 Link Local Address will be automatically configured for this interface.

    The enablement of the `router-advertisement` on the IPv6 interface results in a router sending RA messages to directly connected peers, informing them of the interface's IP address. This will facilitate ARP/ND cache population.

    ```srl
    / interface ethernet-1/49
        admin-state enable
        subinterface 1 {
            ipv6 {
                admin-state enable
                router-advertisement {
                    router-role {
                        admin-state enable
                    }
                }
            }
        }
    ```

3. Attach the configured subinterfaces to the default network instance (aka GRT).

    ```srl
    / network-instance default interface ethernet-1/49.1
    ```

4. Apply the configuration changes by issuing a `commit now` command. The changes will be written to the running configuration.

    ```srl
    commit now
    ```

Below you will find the relevant configuration snippets for leafs and spine devices which you can paste in the terminal while being in `running` mode.

/// tab | leaf1 and leaf2

```srl
enter candidate
/ interface ethernet-1/49
    admin-state enable
    subinterface 1 {
        ipv6 {
            admin-state enable
            router-advertisement {
                router-role {
                    admin-state enable
                }
            }
        }
    }

/ network-instance default interface ethernet-1/49.1
commit now
```

///

/// tab | spine

```srl
enter candidate
/ interface ethernet-1/{1..2} #(1)
    admin-state enable
    subinterface 1 {
        ipv6 {
            admin-state enable
            router-advertisement {
                router-role {
                    admin-state enable
                }
            }
        }
    }

/ network-instance default interface ethernet-1/{1..2}.1
commit now
```

1. Cool trick with using [configuration ranges](../../blog/posts/2023/cli-ranges.md), yeah!

///

Once those snippets are committed to the running configuration, we can ensure that the changes have been successfully applied by displaying the interface status.

Below highlighted, you will see that an IPv6 link-layer address is auto assigned to each interface. This address is not routable and is not announced to other peers by default.

/// tab | leaf1

```srl hl_lines="10"
--{ + running }--[ network-instance default interface ethernet-1/49.1 ]--
A:leaf1# show / interface ethernet-1/49
=========================================================================
ethernet-1/49 is up, speed 100G, type None
  ethernet-1/49.1 is up
    Network-instances:
      * Name: default (default)
    Encapsulation   : null
    Type            : routed
    IPv6 addr    : fe80::1835:2ff:feff:31/64 (link-layer, preferred)
```

///

/// tab | leaf2

```srl hl_lines="10"
--{ + running }--[ network-instance default interface ethernet-1/49.1 ]--
A:leaf2# show / interface ethernet-1/49
=========================================================================
ethernet-1/49 is up, speed 100G, type None
  ethernet-1/49.1 is up
    Network-instances:
      * Name: default (default)
    Encapsulation   : null
    Type            : routed
    IPv6 addr    : fe80::18f3:3ff:feff:31/64 (link-layer, preferred)
```

///

/// tab | spine

```srl hl_lines="10 18"
--{ + running }--[ network-instance default interface ethernet-1/{1..2}.1 ]--
A:spine# show / interface ethernet-1/{1..2}
=============================================================================
ethernet-1/1 is up, speed 100G, type None
  ethernet-1/1.1 is up
    Network-instances:
      * Name: default (default)
    Encapsulation   : null
    Type            : routed
    IPv6 addr    : fe80::183d:4ff:feff:1/64 (link-layer, preferred)
-----------------------------------------------------------------------------
ethernet-1/2 is up, speed 100G, type None
  ethernet-1/2.1 is up
    Network-instances:
      * Name: default (default)
    Encapsulation   : null
    Type            : routed
    IPv6 addr    : fe80::183d:4ff:feff:2/64 (link-layer, preferred)
-----------------------------------------------------------------------------
=============================================================================
Summary
  0 loopback interfaces configured
  2 ethernet interfaces are up
  0 management interfaces are up
  2 subinterfaces are up
```

///

If we have a look in the ARP/ND neighbors list constructed from the received Router Advertisement messages we can see IPv6 LLA address of a neighboring node detected using ARP/ND protocol. For example, on `leaf1` and `spine` devices:

/// tab | leaf1

```srl
--{ + running }--[ network-instance default interface ethernet-1/49.1 ]--
A:leaf1# show / arpnd neighbors interface ethernet-1/49
+-----------+-----------+--------------------------------------+-----------+---------------------+-----------+---------------------+-----------+
| Interface | Subinterf |               Neighbor               |  Origin   | Link layer address  |  Current  |  Next state change  | Is Router |
|           |    ace    |                                      |           |                     |   state   |                     |           |
+===========+===========+======================================+===========+=====================+===========+=====================+===========+
| ethernet- |         1 |                fe80::183d:4ff:feff:1 |   dynamic | 1A:3D:04:FF:00:01   | stale     | 3 hours from now    | false     |
| 1/49      |           |                                      |           |                     |           |                     |           |
+-----------+-----------+--------------------------------------+-----------+---------------------+-----------+---------------------+-----------+
------------------------------------------------------------------------------------------------------------------------------------------------
  Total entries : 1 (0 static, 1 dynamic)
------------------------------------------------------------------------------------------------------------------------------------------------
```

///

/// tab | spine

```srl
--{ + running }--[  ]--
A:spine# show / arpnd neighbors interface ethernet-1/{1..2}
+-----------+-----------+--------------------------------------+-----------+---------------------+-----------+---------------------+-----------+
| Interface | Subinterf |               Neighbor               |  Origin   | Link layer address  |  Current  |  Next state change  | Is Router |
|           |    ace    |                                      |           |                     |   state   |                     |           |
+===========+===========+======================================+===========+=====================+===========+=====================+===========+
| ethernet- |         1 |               fe80::1835:2ff:feff:31 |   dynamic | 1A:35:02:FF:00:31   | stale     | 3 hours from now    | false     |
| 1/1       |           |                                      |           |                     |           |                     |           |
| ethernet- |         1 |               fe80::18f3:3ff:feff:31 |   dynamic | 1A:F3:03:FF:00:31   | stale     | 3 hours from now    | false     |
| 1/2       |           |                                      |           |                     |           |                     |           |
+-----------+-----------+--------------------------------------+-----------+---------------------+-----------+---------------------+-----------+
------------------------------------------------------------------------------------------------------------------------------------------------
  Total entries : 2 (0 static, 2 dynamic)
------------------------------------------------------------------------------------------------------------------------------------------------
```

///

As the table above shows, the IPv6 link-local addresses of the neighboring nodes are detected using the ARP/ND protocol which is a precursor to the BGP peering establishment.

## Loopback Interfaces

In addition to the physical interfaces in our fabric we need to configure the loopback interfaces on our leaf devices so that they can build an iBGP peering over those interfaces with EVPN address family. This will be covered in the [Overlay Routing section](overlay.md) of this tutorial.

Besides iBGP peering, the loopback interfaces will be used to originate and terminate VXLAN packets. And in the context of the VXLAN data plane, a special kind of a loopback needs to be created - `system0` interface.

/// note
The `system0.0` interface hosts the loopback address used to originate and typically
terminate VXLAN packets. This address is also used by default as the next-hop of all
EVPN routes.
///

Configuration of the `system0` interface/subinterface is exactly the same as for the regular interfaces, with the exception that the `system0` interface name bears a special meaning and can only have one subinterface with index `0`. Assiming you are in the running configuration mode, paste the following snippets on each device:

/// tab | leaf1

```srl
enter candidate
/ interface system0 {
    subinterface 0 {
        ipv4 {
            admin-state enable
            address 10.0.0.1/32
        }
    }
}

/ network-instance default interface system0.0

commit now
```

///

/// tab | leaf2

```srl
enter candidate
/ interface system0 {
    subinterface 0 {
        ipv4 {
            admin-state enable
            address 10.0.0.2/32
        }
    }
}

/ network-instance default interface system0.0

commit now

```

///

/// tab | spine

```srl
enter candidate
/ interface system0 {
    subinterface 0 {
        ipv4 {
            admin-state enable
            address 10.10.10.10/32
        }
    }
}

/ network-instance default interface system0.0

commit now
```

///

## eBGP Unnumbered for Underlay Routing

Now we will set up the eBGP routing protocol that will be used for exchang loopback addresses throughout the fabric. These loopbacks will be used to set up iBGP EVPN peerings, which we will cover in the following chapter.

The eBGP setup is done according to the following diagram:

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":4,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>

The private 32bit AS Numbers are used on all devices and Router ID is set to match the IPv4 address of the `system0` loopback interface.

Here is a breakdown of the configuration steps done on `leaf1` and you will find configuration for other devices at the end of this section:

<small>In this case we show the `set`-based configuration syntax</small>

1. **Assign Autonomous System Number**  
    Since we are using eBGP we have to configure AS number for every BGP speaker.

    Most commonly datacenter designs would have a shared ASN between the spines to prevent traffic transiting via spines (valley-free routing). And an unique ASN per leaf to simplify BGP configuration and troubleshooting.

    ```{.srl .no-select}
    set / network-instance default protocols bgp autonomous-system 4200000001
    ```

2. **Assign a unique Router ID**  
    This is the BGP identifier reported to peers when a BGP session undergoes the establishment process.  
    As a best practice, we will configure Router ID to match the IPv4 address of the loopback (`system0`) interface.

    ```srl
    set / network-instance default protocols bgp router-id 10.0.0.1
    ```

3. **Enable Address Family**  
    In order to exchange IPv4 loopback IPs we need to enable `ipv4-unicast` address family under the global BGP protocols configuration block.

    ```{.srl .no-select}
    set / network-instance default protocols bgp afi-safi ipv4-unicast admin-state enable
    ```

4. **Create Routing Policy**

    Recall, that our goal is to announce via eBGP the loopback addresses of the leaf devices so that we can establish iBGP peering over them later on.  
    In accordance with best security practices, and [RFC 8212](https://datatracker.ietf.org/doc/html/rfc8212), SR Linux does not announce anything via eBGP unless an explicit export policy is configured. Let's configure one.

    The policy below will permit announcement of all locally prefixes of the locally configured interfaces in the network instance, but since link-local addresses are not announced and that is all we have, only the system0 prefixes (loopback) will be announced to the peers.

    <small>If you wish to, you can configure a more specific export policy matching a prefix list.</small>

    ```srl
    set / routing-policy policy announce_system_IP statement 1 match protocol local
    set / routing-policy policy announce_system_IP statement 1 action policy-result accept

    set / network-instance default protocols bgp afi-safi ipv4-unicast export-policy announce_system_IP
    ```

    After committing the configs above, a System Interface will be configured with a unique IP address (identical to the BGP Router ID as best practice) and that IP will be exported to the eBGP and announced to the neighbors.

5. **Allow Route Advertisement for eBGP**  
   eBGP assumes that peers are external systems and by default all incoming and outgoing routes are blocked. We will disable this behavior and permit all incoming and outgoing routes.

    ```srl
    set / network-instance default protocols bgp eBGP-default-policy import-reject-all false
    set / network-instance default protocols bgp eBGP-default-policy export-reject-all false
    ```

6. **Create BGP peer-group**  
    A BGP peer group simplifies configuring multiple BGP peers with similar requirements by grouping them together, allowing the same policies and attributes to be applied to all peers in the group simultaneously. Here we create a group named underlay to be used for the eBGP peerings.
  
    ```srl
    set / network-instance default protocols bgp group underlay
    ```

7. **Configure dynamic neighbor**  
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

8. **Allow IPv4 packets on IPv6-only Interfaces**

    The fabric will use IPv6 interfaces to route IPv4 packets. By default, SRLinux drops IPv4 packets if the receiving interface lacks an operational IPv4 subinterface. To change this and allow IPv4 packets on IPv6-only interfaces, use the following system-wide config knob.

    ```srl
    set / network-instance default ip-forwarding receive-ipv4-check false
    ```

9. **Commit configuration**  

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

## Verification

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

## Resulting configs

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

[RFC 8950]: https://datatracker.ietf.org/doc/html/rfc8950
[srl-unnumbered-docs]: https://documentation.nokia.com/srlinux/24-3/books/routing-protocols/bgp.html#bgp-unnumbered-peer

[^1]: default SR Linux credentials are `admin:NokiaSrl1!`.
