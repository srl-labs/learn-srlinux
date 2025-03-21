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

* **Scalability:** BGP is known to scale well in very large networks, making it a good choice for scaled-out data center fabrics.
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

The examples will target the highlighted interfaces between `leaf1` and spine devices, but at the end of this section, you will find the configuration snippets for all devices.

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

    The prompt will indicate we entered the candidate configuration mode. In the following steps we will enter the commands to make changes to the candidate config and at the end we will commit.

2. As a next step, we create a subinterface with index 1 under a physical `ethernet-1/49` interface that connects leaf1 to spine.
    In contrast with the L2 EVPN Tutorial, we will not configure an explicit IP address, but enable IPv6 with Router Advertisement messages for it. An IPv6 Link Local Address will be automatically configured for this interface.

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
                        max-advertisement-interval 10
                        min-advertisement-interval 4
                    }
                }
            }
        }
    ```

    Note, that the default, RFC-based values for min and max advertisement interval are quite high, so we lower them to 4 and 10 seconds respectively to have a faster unnumbered discovery.

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

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf1.conf:physical-interfaces"

commit now
```

///

/// tab | spine

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/spine.conf:physical-interfaces"

commit now
```

1. Cool trick with using [configuration ranges](../../../blog/posts/2023/cli-ranges.md), yeah!

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

/// note | `system0`
The `system0.0` interface hosts the loopback address used to originate and typically
terminate VXLAN packets. This address is also used by default as the next-hop of all
EVPN routes.
///

Configuration of the `system0` interface/subinterface is exactly the same as for the regular interfaces, with the exception that the `system0` interface name bears a special meaning and can only have one subinterface with index `0`. Assiming you are in the running configuration mode, paste the following snippets on each device:

/// tab | leaf1

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf1.conf:loopback-interfaces"

commit now
```

///

/// tab | leaf2

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf2.conf:loopback-interfaces"

commit now

```

///

/// tab | spine

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/spine.conf:loopback-interfaces"

commit now
```

///

## eBGP Unnumbered for Underlay Routing

Now we will set up the eBGP routing protocol that will be used for exchang loopback addresses throughout the fabric. These loopbacks will be used to set up iBGP EVPN peerings, which we will cover in the following chapter.

The eBGP setup is done according to the following diagram:

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":4,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>

The private 32bit AS Numbers are used on all devices and Router ID is set to match the IPv4 address of the `system0` loopback interface.

/// admonition | SR Linux and BGP Unnumbered for EVPN
    type: warning
SR Linux supports EVPN-VXLAN with BGP Unnumbered starting with 24.3.1 release.
///

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

3. **Create Routing Policy**

    Recall, that our goal is to announce the loopback addresses of the leaf devices via eBGP so that we can establish iBGP peering over them later on.  
    In accordance with best security practices, and [RFC 8212](https://datatracker.ietf.org/doc/html/rfc8212), SR Linux does not announce anything via eBGP unless an explicit export policy exists. Let's configure one.

    First, we will create a prefix set that matches the range of loopback addresses we want to send and receive.

    ```{.srl .no-select}
    set / routing-policy prefix-set system-loopbacks prefix 10.0.0.0/8 mask-length-range 32..32
    ```

    Next, we will create a routing policy that matches on the prefix set we just created and accepts them.

    ```{.srl .no-select}
    set / routing-policy policy system-loopbacks-policy statement 1 match prefix-set system-loopbacks
    set / routing-policy policy system-loopbacks-policy statement 1 action policy-result accept
    ```

4. **Create BGP peer-group**  
    A BGP peer group simplifies configuring multiple BGP peers with similar requirements by grouping them together, allowing the same policies and attributes to be applied to all peers in the group. Here we create a group named `underlay` to be used for the eBGP peerings and set the created import/export policies to it.
  
    ```{.srl .no-select}
    set / network-instance default protocols bgp group underlay
    set / network-instance default protocols bgp group underlay export-policy system-loopbacks-policy
    set / network-instance default protocols bgp group underlay import-policy system-loopbacks-policy
    ```

5. **Enable `ipv4-unicast` Address Family**  
    In order to exchange IPv4 loopback IPs we need to enable `ipv4-unicast` address family; we put this under the global bgp region, since at least one address family must be enabled for the BGP process.

    ```{.srl .no-select}
    set / network-instance default protocols bgp afi-safi ipv4-unicast admin-state enable
    ```

6. **Configure dynamic BGP neighbors**  
    Here is the beauty of BGP IPv6 Unnumbered. We can configure dynamic BGP neighbors on the interfaces without specifying the neighbor's IP address. The BGP session will be established using the link-local address of the interface.

    ```srl
    set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/49.1 peer-group underlay
    ```

    To control which peers would be able allowed to form a BGP session with the `leaf1` device we can use the `allowed-peer-as` knob. This will limit the allowed AS numbers of the peers that can establish a BGP session with the device.

    ```srl
    set / network-instance default protocols bgp dynamic-neighbors interface ethernet-1/49.1 allowed-peer-as [ 4200000001..4200000010 ]
    ```

    /// details | want to have more control over the allowed peers?
    It is also possible to only allow peers that match a certain prefix.</small>

    ```srl
    set / network-instance default protocols bgp dynamic-neighbors accept match fe80::/10 peer-group underlay
    ```

    ///

7. **Allow IPv4 Packets on IPv6-only Interfaces**

    You may have noticed that our fabric now has a peculiar configuration of interfaces. The physical interfaces between leaf and spine devices are IPv6-only, whereas our `system0` loopback interfaces are addressed with IPv4.

    Essentially we will have VXLANv4 packets traversing the IPv6-only interfaces and, by default, SR Linux drops IPv4 packets if the receiving interface lacks an operational IPv4 subinterface. To change this and allow IPv4 packets on IPv6-only interfaces, use the following system-wide config knob.

    ```srl
    set / network-instance default ip-forwarding receive-ipv4-check false
    ```

8. **Commit configuration**  

    Once we apply the config above (whole snippet below), we should have BGP peerings automatically established.

    ```srl
    --{ +* candidate shared default }--[ network-instance default protocols bgp ]--
    A:leaf1# commit now
    ```

Here are the config snippets related to eBGP configuration per device for an easy copy paste experience. Note, that the snippets already include entering the candidate step and commit command at the end.

/// tab | leaf1

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf1.conf:ebgp-underlay"


commit now
```

///

/// tab | leaf2

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf2.conf:ebgp-underlay"

commit now
```

///

/// tab | spine

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/spine.conf:ebgp-underlay"

commit now
```

///

## Verification

Congratulations, we just configured the underlay routing using eBGP with IPv6 Unnumbered. Let's run some verification commands to ensure that we achieved the desired end state, which is to have leaf' loopback prefixes exchanged over the eBGP sessions.

### BGP neighbor status

First, verify that the eBGP peerings are in the established state using BGP Family IPv4-Unicast. Note that all peerings are dynamic, automatically configured using the dynamic-peering feature.

/// tab | leaf1

```srl
--{ + running }--[ network-instance default interface system0.0 ]--
A:leaf1# / show network-instance default protocols bgp neighbor
-------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------
+---------+---------+---------+---------+---------+---------+---------+---------+---------+
|  Net-   |  Peer   |  Group  |  Flags  | Peer-AS |  State  | Uptime  | AFI/SAF | [Rx/Act |
|  Inst   |         |         |         |         |         |         |    I    | ive/Tx] |
+=========+=========+=========+=========+=========+=========+=========+=========+=========+
| default | fe80::1 | underla | D       | 4200000 | establi | 0d:0h:2 | ipv4-   | [2/2/1] |
|         | 83d:4ff | y       |         | 010     | shed    | 8m:42s  | unicast |         |
|         | :feff:1 |         |         |         |         |         |         |         |
|         | %ethern |         |         |         |         |         |         |         |
|         | et-     |         |         |         |         |         |         |         |
|         | 1/49.1  |         |         |         |         |         |         |         |
+---------+---------+---------+---------+---------+---------+---------+---------+---------+
-------------------------------------------------------------------------------------------------
Summary:
0 configured neighbors, 0 configured sessions are established,0 disabled peers
1 dynamic peers
```

///

/// tab | leaf2

```srl
--{ + running }--[  ]--
A:leaf2# / show network-instance default protocols bgp neighbor
-------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------
+---------+---------+---------+---------+---------+---------+---------+---------+---------+
|  Net-   |  Peer   |  Group  |  Flags  | Peer-AS |  State  | Uptime  | AFI/SAF | [Rx/Act |
|  Inst   |         |         |         |         |         |         |    I    | ive/Tx] |
+=========+=========+=========+=========+=========+=========+=========+=========+=========+
| default | fe80::1 | underla | D       | 4200000 | establi | 0d:0h:2 | ipv4-   | [2/2/1] |
|         | 83d:4ff | y       |         | 010     | shed    | 6m:40s  | unicast |         |
|         | :feff:2 |         |         |         |         |         |         |         |
|         | %ethern |         |         |         |         |         |         |         |
|         | et-     |         |         |         |         |         |         |         |
|         | 1/49.1  |         |         |         |         |         |         |         |
+---------+---------+---------+---------+---------+---------+---------+---------+---------+
-------------------------------------------------------------------------------------------------
Summary:
0 configured neighbors, 0 configured sessions are established,0 disabled peers
1 dynamic peers
```

///

/// tab | spine

```srl
A:spine# / show network-instance default protocols bgp neighbor
---------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
+---------+---------+---------+---------+---------+---------+---------+---------+---------+
|  Net-   |  Peer   |  Group  |  Flags  | Peer-AS |  State  | Uptime  | AFI/SAF | [Rx/Act |
|  Inst   |         |         |         |         |         |         |    I    | ive/Tx] |
+=========+=========+=========+=========+=========+=========+=========+=========+=========+
| default | fe80::1 | underla | D       | 4200000 | establi | 0d:0h:3 | ipv4-   | [1/1/1] |
|         | 835:2ff | y       |         | 001     | shed    | 0m:49s  | unicast |         |
|         | :feff:3 |         |         |         |         |         |         |         |
|         | 1%ether |         |         |         |         |         |         |         |
|         | net-    |         |         |         |         |         |         |         |
|         | 1/1.1   |         |         |         |         |         |         |         |
| default | fe80::1 | underla | D       | 4200000 | establi | 0d:0h:2 | ipv4-   | [1/1/1] |
|         | 8f3:3ff | y       |         | 002     | shed    | 7m:20s  | unicast |         |
|         | :feff:3 |         |         |         |         |         |         |         |
|         | 1%ether |         |         |         |         |         |         |         |
|         | net-    |         |         |         |         |         |         |         |
|         | 1/2.1   |         |         |         |         |         |         |         |
+---------+---------+---------+---------+---------+---------+---------+---------+---------+
---------------------------------------------------------------------------------------------
Summary:
0 configured neighbors, 0 configured sessions are established,0 disabled peers
2 dynamic peers
```

///

All good, we see two spines established eBGP session with the spine using ipv4-unicast address family.

### Advertised routes

We configured eBGP in the fabric's underlay to advertise the VXLAN tunnel endpoints (our `system0` interfaces). The output below verifies that the leafs are advertising their `system0` prefixes to the spine and spine advertises them to the respective leafs.

<small> Note, that the neighbor address in the case of IPv6 Unnumbered is composed of a link-local address (`fe80:...`) and the interface name. You can use CLI autosuggestion to complete the interface name.</small>

/// tab | leaf1

```srl hl_lines="13-14"
--{ + running }--[  ]--
A:leaf1# / show network-instance default protocols bgp neighbor fe80::183d:4ff:feff:1%ethernet-1/49.1 advertised-routes ipv4
---------------------------------------------------------------------------------------------------------------
Peer        : fe80::183d:4ff:feff:1%ethernet-1/49.1, remote AS: 4200000010, local AS: 4200000001
Type        : static
Description : None
Group       : underlay
---------------------------------------------------------------------------------------------------------------
Origin codes: i=IGP, e=EGP, ?=incomplete
+--------------------------------------------------------------------------------------------------------+
|   Network        Path-id        Next Hop         MED          LocPref         AsPath         Origin    |
+========================================================================================================+
| 10.0.0.1/32    0              fe80::1835:2        -             100        [4200000001]         i      |
|                               ff:feff:31                                                               |
+--------------------------------------------------------------------------------------------------------+
---------------------------------------------------------------------------------------------------------------
1 advertised BGP routes
---------------------------------------------------------------------------------------------------------------
```

///

/// tab | leaf2

```srl hl_lines="13-14"
--{ + running }--[  ]--
A:leaf2# / show network-instance default protocols bgp neighbor fe80::183d:4ff:feff:2%ethernet-1/49.1 advertised-routes ipv4
--------------------------------------------------------------------------------------------------------------
Peer        : fe80::183d:4ff:feff:2%ethernet-1/49.1, remote AS: 4200000010, local AS: 4200000002
Type        : static
Description : None
Group       : underlay
--------------------------------------------------------------------------------------------------------------
Origin codes: i=IGP, e=EGP, ?=incomplete
+--------------------------------------------------------------------------------------------------------+
|   Network        Path-id        Next Hop         MED          LocPref         AsPath         Origin    |
+========================================================================================================+
| 10.0.0.2/32    0              fe80::18f3:3        -             100        [4200000002]         i      |
|                               ff:feff:31                                                               |
+--------------------------------------------------------------------------------------------------------+
--------------------------------------------------------------------------------------------------------------
1 advertised BGP routes
--------------------------------------------------------------------------------------------------------------
```

///

/// tab | spine

Towards `leaf1`:

```srl hl_lines="13-16"
--{ + running }--[  ]--
A:spine# / show network-instance default protocols bgp neighbor fe80::1835:2ff:feff:31%ethernet-1/1.1 advertised-routes ipv4
-----------------------------------------------------------------------------------------------------------------------------
Peer        : fe80::1835:2ff:feff:31%ethernet-1/1.1, remote AS: 4200000001, local AS: 4200000010
Type        : static
Description : None
Group       : underlay
-----------------------------------------------------------------------------------------------------------------------------
Origin codes: i=IGP, e=EGP, ?=incomplete
+----------------------------------------------------------------------------------------------------------------------+
|    Network          Path-id          Next Hop           MED            LocPref           AsPath           Origin     |
+======================================================================================================================+
| 10.0.0.2/32      0                fe80::183d:4ff         -               100         [4200000010,            i       |
|                                   :feff:1                                            4200000002]                     |
| 10.10.10.10/32   0                fe80::183d:4ff         -               100         [4200000010]            i       |
|                                   :feff:1                                                                            |
+----------------------------------------------------------------------------------------------------------------------+
-----------------------------------------------------------------------------------------------------------------------------
2 advertised BGP routes
-----------------------------------------------------------------------------------------------------------------------------
```

Towards `leaf2`:

```srl hl_lines="13-16"
--{ + running }--[  ]--
A:spine# / show network-instance default protocols bgp neighbor fe80::18f3:3ff:feff:31%ethernet-1/2.1 advertised-routes ipv4
-----------------------------------------------------------------------------------------------------------------------------
Peer        : fe80::18f3:3ff:feff:31%ethernet-1/2.1, remote AS: 4200000002, local AS: 4200000010
Type        : static
Description : None
Group       : underlay
-----------------------------------------------------------------------------------------------------------------------------
Origin codes: i=IGP, e=EGP, ?=incomplete
+----------------------------------------------------------------------------------------------------------------------+
|    Network          Path-id          Next Hop           MED            LocPref           AsPath           Origin     |
+======================================================================================================================+
| 10.0.0.1/32      0                fe80::183d:4ff         -               100         [4200000010,            i       |
|                                   :feff:2                                            4200000001]                     |
| 10.10.10.10/32   0                fe80::183d:4ff         -               100         [4200000010]            i       |
|                                   :feff:2                                                                            |
+----------------------------------------------------------------------------------------------------------------------+
-----------------------------------------------------------------------------------------------------------------------------
2 advertised BGP routes
-----------------------------------------------------------------------------------------------------------------------------
```

///

### Route table

The last stop in the control plane verification process is to check if the remote loopback prefixes were installed in the `default` network-instance where we expect them to be:

/// tab | leaf1

```srl hl_lines="14"
--{ + running }--[  ]--
A:leaf1# / show network-instance default route-table
--------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance default
--------------------------------------------------------------------------------------------------------------------------------------------------------
+----------------+------+-----------+--------------------+---------+---------+--------+-----------+-----------+-----------+-----------+-------------+
|     Prefix     |  ID  |   Route   |    Route Owner     | Active  | Origin  | Metric |   Pref    | Next-hop  | Next-hop  |  Backup   |   Backup    |
|                |      |   Type    |                    |         | Network |        |           |  (Type)   | Interface | Next-hop  |  Next-hop   |
|                |      |           |                    |         | Instanc |        |           |           |           |  (Type)   |  Interface  |
|                |      |           |                    |         |    e    |        |           |           |           |           |             |
+================+======+===========+====================+=========+=========+========+===========+===========+===========+===========+=============+
| 10.0.0.1/32    | 3    | host      | net_inst_mgr       | True    | default | 0      | 0         | None      | None      |           |             |
|                |      |           |                    |         |         |        |           | (extract) |           |           |             |
| 10.0.0.2/32    | 0    | bgp       | bgp_mgr            | True    | default | 0      | 170       | fe80::183 | ethernet- |           |             |
|                |      |           |                    |         |         |        |           | d:4ff:fef | 1/49.1    |           |             |
|                |      |           |                    |         |         |        |           | f:1       |           |           |             |
|                |      |           |                    |         |         |        |           | (direct)  |           |           |             |
| 10.10.10.10/32 | 0    | bgp       | bgp_mgr            | True    | default | 0      | 170       | fe80::183 | ethernet- |           |             |
|                |      |           |                    |         |         |        |           | d:4ff:fef | 1/49.1    |           |             |
|                |      |           |                    |         |         |        |           | f:1       |           |           |             |
|                |      |           |                    |         |         |        |           | (direct)  |           |           |             |
+----------------+------+-----------+--------------------+---------+---------+--------+-----------+-----------+-----------+-----------+-------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 routes total                    : 3
IPv4 prefixes with active routes     : 3
IPv4 prefixes with active ECMP routes: 0
--------------------------------------------------------------------------------------------------------------------------------------------------------
```

///

/// tab | leaf2

```srl hl_lines="12"
--{ + running }--[  ]--
A:leaf2# / show network-instance default route-table
--------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance default
--------------------------------------------------------------------------------------------------------------------------------------------------------
+----------------+------+-----------+--------------------+---------+---------+--------+-----------+-----------+-----------+-----------+-------------+
|     Prefix     |  ID  |   Route   |    Route Owner     | Active  | Origin  | Metric |   Pref    | Next-hop  | Next-hop  |  Backup   |   Backup    |
|                |      |   Type    |                    |         | Network |        |           |  (Type)   | Interface | Next-hop  |  Next-hop   |
|                |      |           |                    |         | Instanc |        |           |           |           |  (Type)   |  Interface  |
|                |      |           |                    |         |    e    |        |           |           |           |           |             |
+================+======+===========+====================+=========+=========+========+===========+===========+===========+===========+=============+
| 10.0.0.1/32    | 0    | bgp       | bgp_mgr            | True    | default | 0      | 170       | fe80::183 | ethernet- |           |             |
|                |      |           |                    |         |         |        |           | d:4ff:fef | 1/49.1    |           |             |
|                |      |           |                    |         |         |        |           | f:2       |           |           |             |
|                |      |           |                    |         |         |        |           | (direct)  |           |           |             |
| 10.0.0.2/32    | 3    | host      | net_inst_mgr       | True    | default | 0      | 0         | None      | None      |           |             |
|                |      |           |                    |         |         |        |           | (extract) |           |           |             |
| 10.10.10.10/32 | 0    | bgp       | bgp_mgr            | True    | default | 0      | 170       | fe80::183 | ethernet- |           |             |
|                |      |           |                    |         |         |        |           | d:4ff:fef | 1/49.1    |           |             |
|                |      |           |                    |         |         |        |           | f:2       |           |           |             |
|                |      |           |                    |         |         |        |           | (direct)  |           |           |             |
+----------------+------+-----------+--------------------+---------+---------+--------+-----------+-----------+-----------+-----------+-------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 routes total                    : 3
IPv4 prefixes with active routes     : 3
IPv4 prefixes with active ECMP routes: 0
--------------------------------------------------------------------------------------------------------------------------------------------------------
```

///

Both leafs have in their routing table a route to the loopback of the other leaf and therefore the underlay routing is working as expected.

### Dataplane

To finish the verification process let's ensure that the datapath is working, and the VTEPs on both leafs can reach each other via the routed underlay.

For that we will use the `ping` command with src/dst set to loopback addresses:

```srl title="leaf1 loopback pings leaf2 loopback"
A:leaf1# ping network-instance default 10.0.0.2 -I 10.0.0.1 -c 3
Using network instance default
PING 10.0.0.2 (10.0.0.2) from 10.0.0.1 : 56(84) bytes of data.
64 bytes from 10.0.0.2: icmp_seq=1 ttl=63 time=9.93 ms
64 bytes from 10.0.0.2: icmp_seq=2 ttl=63 time=16.2 ms
64 bytes from 10.0.0.2: icmp_seq=3 ttl=63 time=15.2 ms

--- 10.0.0.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2002ms
rtt min/avg/max/mdev = 9.926/13.776/16.178/2.750 ms

```

Perfect, the loopbacks are reachable and the fabric underlay is properly configured. We can proceed with EVPN service configuration!

## Resulting configs

Below you will find aggregated configuration snippets that contain the entire fabric configuration we did in the steps above. Those snippets are in the CLI format and were extracted with the `info` command.

/// note
`enter candidate` and `commit now` commands are part of the snippets, so it is possible to paste them right after you logged into the devices.
///

/// tab | leaf1

```{.srl .code-scroll-lg}
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf1.conf:physical-interfaces"

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf1.conf:loopback-interfaces"

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf1.conf:ebgp-underlay"

commit now
```

///

/// tab | leaf2

```{.srl .code-scroll-lg}
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf2.conf:physical-interfaces"

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf2.conf:loopback-interfaces"

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf2.conf:ebgp-underlay"

commit now
```

///

/// tab | spine

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/spine.conf:physical-interfaces"

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/spine.conf:loopback-interfaces"

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/spine.conf:ebgp-underlay"

commit now
```

///

Great stuff, now we are ready to move on to the [Overlay Routing configuration](overlay.md).

[RFC 8950]: https://datatracker.ietf.org/doc/html/rfc8950
[srl-unnumbered-docs]: https://documentation.nokia.com/srlinux/24-3/books/routing-protocols/bgp.html#bgp-unnumbered-peer

[^1]: default SR Linux credentials are `admin:NokiaSrl1!`.
