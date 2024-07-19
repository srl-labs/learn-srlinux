---
comments: true
---

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>

# L3 EVPN Instance

In the prior chapters, we have been busy laying out the infrastructure foundation for the L3 overlay service. First we configured the IP fabric underlay routing, making sure that all leaf devices can reach spines and each other. Then, we established an iBGP peering between the leaf and spine devices with `evpn` address family to exchange overlay routing information.

All this has been leading up to the creation of an L3 EVPN instance that will allow our clients (Tenant Systems in the RFC terms) to have L3 connectivity between them by connecting directly with L3 interfaces to the leaf switches or using BGP PE-CE sessions to exchange routes with the leaf switches.

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":6,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>

The L3 EVPN instance will span across the leaf switches and the transport of EVPN overlays will occur through VXLAN tunnels built over the underlay IP network.  
Spine layer is not present in the logical diagram above as it won't be aware of the any overlay concepts, it will simply route IP packets from one leaf to another.

Let's start with a simple scenario where the clients are directly connected to the leaf switches over L3 interfaces. Our clients are represented by `ce1` and `ce2` lab nodes that run FRR and are connected to the leaf switches. You can imagine, that instead of an FRR router it may be a server or another workload that requires L3 connectivity.

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":8,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>

The ce nodes have their `eth1` interfaces configured with IPv4 addresses and our goal is to build the L3 connectivity between the ce devices such that `ce1` can ping `ce2` over using their `eth1` interfaces.

## Client-facing interface on leaf

First we configure the client-facing interface on leaf switches. As per our lab, the CE device is connected to the leaf' `ethernet-1/1` port, so we enable this interface with a logical routed subinterface and assign IP address.

On each leaf we select IP address from the same subnet that the client is using. For example, if `ce1` has IP `192.168.1.100/24`, then we address the leaf interface with `192.168.1.1/24`:

```srl
set / interface ethernet-1/1 subinterface 1 admin-state enable
set / interface ethernet-1/1 subinterface 1 ipv4 admin-state enable
set / interface ethernet-1/1 subinterface 1 ipv4 address 192.168.1.1/24
```

## VXLAN interface

We also need to create a VXLAN Tunnel End Point (VTEP) that will be used to encap/decap VXLAN traffic. On SR Linux this is done by creating a logical tunnel interface defined by a virtual network identifier (VNI) and an overlay network type. Type **routed** is chosen for Layer 3 routing, while **bridged** is used for Layer 2 switching[^1].

```srl
set / tunnel-interface vxlan1 vxlan-interface 100 type routed
set / tunnel-interface vxlan1 vxlan-interface 100 ingress vni 100
```

## L3 Network Instance (IP-VRF)

The next step is to create an L3 Network Instance (IP-VRF) on our leaf switches that is a virtual routing and forwarding instance that will contain the routing table for the L3 EVPN service.

1. **Create Network Instance**  

    The VRF is of type `ip-vrf` to denote that it is an L3 VRF:

    ```srl
    set / network-instance ip-vrf-1 type ip-vrf
    set / network-instance ip-vrf-1 admin-state enable
    ```

2. **Attach interfaces to the network instance**  
    Associate the previously configured client' subinterface and the tunnel interface with the IP-VRF so that they become part of this L3 VRF:

    ```srl
    set / network-instance ip-vrf-1 interface ethernet-1/1.1
    set / network-instance ip-vrf-1 vxlan-interface vxlan1.100
    ```

1. **Configure EVPN Parameters**  
    At this step we configure the BGP EVPN parameters of this IP VRF by creating a `bgp-instance` and adding the vxlan interface under it.

    ```srl
    set / network-instance ip-vrf-1 protocols bgp-evpn bgp-instance 1 admin-state enable
    set / network-instance ip-vrf-1 protocols bgp-evpn bgp-instance 1 vxlan-interface vxlan1.100
    ```

    Define an EVPN Virtual Identifier (EVI) under the bgp-evpn instance will be used as a service identifier and to auto-derive the route distinguisher value.  
    As for the Route Target, we will set it manually, because auto-derivation will use the AS number specified under the global BGP process, and we have different AS numbers per leaf.

    ```srl
    set / network-instance ip-vrf-1 protocols bgp-evpn bgp-instance 1 evi 100
    set / network-instance ip-vrf-1 protocols bgp-vpn bgp-instance 1 route-target export-rt target:65535:100
    set / network-instance ip-vrf-1 protocols bgp-vpn bgp-instance 1 route-target import-rt target:65535:100
    ```

    And create the `bgp-vpn` context under the IP VRF to enable multi-protocol BGP operation.

    ```srl
    set / network-instance ip-vrf-1 protocols bgp-vpn bgp-instance 1
    ```

    Optionally configure ECMP to enable load balancing in the overlay network.

    ```srl
    set / network-instance ip-vrf-1 protocols bgp-evpn bgp-instance 1 ecmp 8
    ```

The resulting configuration will look like this:

/// tab | leaf1

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf1.conf:client-interface"

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf1.conf:tunnel-interface"

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf1.conf:ipvrf"

commit now
```

///
/// tab | leaf2

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf2.conf:client-interface"

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf2.conf:tunnel-interface"

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf2.conf:ipvrf"

commit now
```

///

With this configuration in place we've built the following layout of basic L3 EVPN constructs on our leaf switches:

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":9,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>

## Verification

To verify L3 EVPN configuration we can start with checking the BGP VPN status and checking that RT value is auto-derived from the EVI we set. And RD value is set manually to the same value on both leafs.

```srl
==================================================================================================
Net Instance   : ip-vrf-1
    bgp Instance 1
--------------------------------------------------------------------------------------------------
        route-distinguisher: 10.0.0.1:100, auto-derived-from-evi
        export-route-target: target:65535:100, manual
        import-route-target: target:65535:100, manual
==================================================================================================
```

Next we can check the overlay BGP neighbor status:

```srl
A:leaf1# / show network-instance default protocols bgp neighbor 10.*
--------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
--------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------
+---------+---------+---------+---------+---------+---------+---------+---------+---------+
|  Net-   |  Peer   |  Group  |  Flags  | Peer-AS |  State  | Uptime  | AFI/SAF | [Rx/Act |
|  Inst   |         |         |         |         |         |         |    I    | ive/Tx] |
+=========+=========+=========+=========+=========+=========+=========+=========+=========+
| default | 10.10.1 | overlay | S       | 65535   | establi | 0d:3h:2 | evpn    | [1/1/1] |
|         | 0.10    |         |         |         | shed    | 8m:11s  |         |         |
+---------+---------+---------+---------+---------+---------+---------+---------+---------+
--------------------------------------------------------------------------------------------------
Summary:
1 configured neighbors, 1 configured sessions are established,0 disabled peers
1 dynamic peers
```

Now we see that a single route has been sent and received by the `leaf1` to/from the `spine` switch acting as a Route Reflector. Let's chec what has been received and sent:

/// tab | received

```srl
A:leaf1# / show network-instance default protocols bgp neighbor 10.* received-routes evpn
--------------------------------------------------------------------------------------------------
Peer        : 10.10.10.10, remote AS: 65535, local AS: 65535
Type        : static
Description : None
Group       : overlay
--------------------------------------------------------------------------------------------------
Status codes: u=used, *=valid, >=best, x=stale
Origin codes: i=IGP, e=EGP, ?=incomplete
--------------------------------------------------------------------------------------------------
Type 5 IP Prefix Routes
+--------+---------------------+--------+----------------+----------+-----+---------+------+
| Status | Route-distinguisher | Tag-ID |   IP-address   | Next-Hop | MED | LocPref | Path |
+========+=====================+========+================+==========+=====+=========+======+
| u*>    | 10.0.0.2:100        | 0      | 192.168.2.0/24 | 10.0.0.2 | -   | 100     |      |
+--------+---------------------+--------+----------------+----------+-----+---------+------+
--------------------------------------------------------------------------------------------------
0 Ethernet Auto-Discovery routes 0 used, 0 valid
0 MAC-IP Advertisement routes 0 used, 0 valid
0 Inclusive Multicast Ethernet Tag routes 0 used, 0 valid
0 Ethernet Segment routes 0 used, 0 valid
1 IP Prefix routes 1 used, 1 valid
--------------------------------------------------------------------------------------------------
```

///
/// tab | sent

```srl
A:leaf1# / show network-instance default protocols bgp neighbor 10.* advertised-routes evpn
--------------------------------------------------------------------------------------------------
Peer        : 10.10.10.10, remote AS: 65535, local AS: 65535
Type        : static
Description : None
Group       : overlay
--------------------------------------------------------------------------------------------------
Origin codes: i=IGP, e=EGP, ?=incomplete
--------------------------------------------------------------------------------------------------
Type 5 IP Prefix Routes
+---------------------+--------+----------------+----------+-----+---------+------+
| Route-distinguisher | Tag-ID |   IP-address   | Next-Hop | MED | LocPref | Path |
+=====================+========+================+==========+=====+=========+======+
| 10.0.0.1:100        | 0      | 192.168.1.0/24 | 10.0.0.1 | -   | 100     |      |
+---------------------+--------+----------------+----------+-----+---------+------+
--------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------
0 advertised Ethernet Auto-Discovery routes
0 advertised MAC-IP Advertisement routes
0 advertised Inclusive Multicast Ethernet Tag routes
0 advertised Ethernet Segment routes
1 advertised IP Prefix routes
--------------------------------------------------------------------------------------------------
```

///

Brilliant, we receive the remote IP prefix `192.168.2.0/24` and sent local IP prefix `192.168.0.1/24` to the other leaf. Let's have a look at the routing table of IP-VRF on both leafs:

/// tab | leaf1

```srl hl_lines="17-19"
A:leaf1# / show network-instance ip-vrf-1 route-table
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance ip-vrf-1
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+----------------------+------+-----------+---------------------+---------+---------+--------+-----------+-------------+-------------+-------------+----------------+
|        Prefix        |  ID  |   Route   |     Route Owner     | Active  | Origin  | Metric |   Pref    |  Next-hop   |  Next-hop   |   Backup    |  Backup Next-  |
|                      |      |   Type    |                     |         | Network |        |           |   (Type)    |  Interface  |  Next-hop   | hop Interface  |
|                      |      |           |                     |         | Instanc |        |           |             |             |   (Type)    |                |
|                      |      |           |                     |         |    e    |        |           |             |             |             |                |
+======================+======+===========+=====================+=========+=========+========+===========+=============+=============+=============+================+
| 192.168.1.0/24       | 4    | local     | net_inst_mgr        | True    | ip-     | 0      | 0         | 192.168.1.1 | ethernet-   |             |                |
|                      |      |           |                     |         | vrf-1   |        |           | (direct)    | 1/1.1       |             |                |
| 192.168.1.1/32       | 4    | host      | net_inst_mgr        | True    | ip-     | 0      | 0         | None        | None        |             |                |
|                      |      |           |                     |         | vrf-1   |        |           | (extract)   |             |             |                |
| 192.168.1.255/32     | 4    | host      | net_inst_mgr        | True    | ip-     | 0      | 0         | None        |             |             |                |
|                      |      |           |                     |         | vrf-1   |        |           | (broadcast) |             |             |                |
| 192.168.2.0/24       | 0    | bgp-evpn  | bgp_evpn_mgr        | True    | ip-     | 0      | 170       | 10.0.0.2/32 |             |             |                |
|                      |      |           |                     |         | vrf-1   |        |           | (indirect/v |             |             |                |
|                      |      |           |                     |         |         |        |           | xlan)       |             |             |                |
+----------------------+------+-----------+---------------------+---------+---------+--------+-----------+-------------+-------------+-------------+----------------+
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 routes total                    : 4
IPv4 prefixes with active routes     : 4
IPv4 prefixes with active ECMP routes: 0
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

///

/// tab | leaf2

```srl hl_lines="10"
A:leaf2# / show network-instance ip-vrf-1 route-table
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance ip-vrf-1
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+----------------------+------+-----------+---------------------+---------+---------+--------+-----------+-------------+-------------+-------------+----------------+
|        Prefix        |  ID  |   Route   |     Route Owner     | Active  | Origin  | Metric |   Pref    |  Next-hop   |  Next-hop   |   Backup    |  Backup Next-  |
|                      |      |   Type    |                     |         | Network |        |           |   (Type)    |  Interface  |  Next-hop   | hop Interface  |
|                      |      |           |                     |         | Instanc |        |           |             |             |   (Type)    |                |
|                      |      |           |                     |         |    e    |        |           |             |             |             |                |
+======================+======+===========+=====================+=========+=========+========+===========+=============+=============+=============+================+
| 192.168.1.0/24       | 0    | bgp-evpn  | bgp_evpn_mgr        | True    | ip-     | 0      | 170       | 10.0.0.1/32 |             |             |                |
|                      |      |           |                     |         | vrf-1   |        |           | (indirect/v |             |             |                |
|                      |      |           |                     |         |         |        |           | xlan)       |             |             |                |
| 192.168.2.0/24       | 4    | local     | net_inst_mgr        | True    | ip-     | 0      | 0         | 192.168.2.1 | ethernet-   |             |                |
|                      |      |           |                     |         | vrf-1   |        |           | (direct)    | 1/1.1       |             |                |
| 192.168.2.1/32       | 4    | host      | net_inst_mgr        | True    | ip-     | 0      | 0         | None        | None        |             |                |
|                      |      |           |                     |         | vrf-1   |        |           | (extract)   |             |             |                |
| 192.168.2.255/32     | 4    | host      | net_inst_mgr        | True    | ip-     | 0      | 0         | None        |             |             |                |
|                      |      |           |                     |         | vrf-1   |        |           | (broadcast) |             |             |                |
+----------------------+------+-----------+---------------------+---------+---------+--------+-----------+-------------+-------------+-------------+----------------+
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 routes total                    : 4
IPv4 prefixes with active routes     : 4
IPv4 prefixes with active ECMP routes: 0
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

///

The routing table contains local and remote prefixes. Local prefixes, as expected, resolve via local interface pointing towards the CE device, while the remote prefix is resolved via the VXLAN tunnel interface.

Last check would be to verify that datapath is working correctly. Let's connect to `ce1`:

```bash
sudo docker exec -i -t l3evpn-ce1 vtysh
```

```srl
ce1# ping ip 192.168.2.100
PING 192.168.2.100 (192.168.2.100): 56 data bytes
64 bytes from 192.168.2.100: seq=0 ttl=63 time=0.836 ms
64 bytes from 192.168.2.100: seq=1 ttl=63 time=0.858 ms
^C
--- 192.168.2.100 ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.836/0.847/0.858 ms
```

Sweet, `ce1` can ping `ce2` over the IP fabric using the L3 EVPN service that we've just configured. Now let's dig deeper on the protocol details and explore the EVPN route types that made this datapath connectivity possible.

## Control plane details

It is quite important to understand how much simpler control plane operations are in the case of a pure L3 EVPN service. Here is what happens when we commit the configuration of the L3 EVPN service on the leaf switches.

/// note | packetcapture or it didn't happen
The following explanation is based on the packet capture fetched with Edgeshark from the `leaf1`'s `e1-49` interface. You can [download the pcap][capture-evpn-rt5].

///

`leaf1` opens a BGP session towards `spine` (spine acts as a Route Reflector) and signals the multiprotocol capability AFI/SAFI=L2VPN/EVPN.

```title="packet #9"
Internet Protocol Version 4, Src: 10.0.0.1, Dst: 10.10.10.10
Transmission Control Protocol, Src Port: 40979, Dst Port: 179, Seq: 1, Ack: 1, Len: 49
Border Gateway Protocol - OPEN Message
    Marker: ffffffffffffffffffffffffffffffff
    Length: 49
    Type: OPEN Message (1)
    Version: 4
    My AS: 65535
    Hold Time: 90
    BGP Identifier: 10.0.0.1
    Optional Parameters Length: 20
    Optional Parameters
        Optional Parameter: Capability
            Parameter Type: Capability (2)
            Parameter Length: 18
            Capability: Graceful Restart capability
            Capability: Multiprotocol extensions capability
                Type: Multiprotocol extensions capability (1)
                Length: 4
                AFI: Layer-2 VPN (25)
                Reserved: 00
                SAFI: EVPN (70)
            Capability: Route refresh capability
            Capability: Support for 4-octet AS number capability
```

The session between leaf-spine is established. Since both leafs have L3 interfaces in the IP-VRF and EVPN is configured in this network instance, EVPN starts exchanging routes.

First we have `leaf1` sending an update with the following contents:

```title="packet #15" linenums="1" hl_lines="16 20 25-26 39-42"
Internet Protocol Version 4, Src: 10.0.0.1, Dst: 10.10.10.10
Transmission Control Protocol, Src Port: 40979, Dst Port: 179, Seq: 88, Ack: 88, Len: 143
Border Gateway Protocol - UPDATE Message
    Marker: ffffffffffffffffffffffffffffffff
    Length: 113
    Type: UPDATE Message (2)
    Withdrawn Routes Length: 0
    Total Path Attribute Length: 90
    Path attributes
        Path Attribute - MP_REACH_NLRI
            Flags: 0x90, Optional, Extended-Length, Non-transitive, Complete
            Type Code: MP_REACH_NLRI (14)
            Length: 45
            Address family identifier (AFI): Layer-2 VPN (25)
            Subsequent address family identifier (SAFI): EVPN (70)
            Next hop: 10.0.0.1
            Number of Subnetwork points of attachment (SNPA): 0
            Network Layer Reachability Information (NLRI)
                EVPN NLRI: IP Prefix route
                    Route Type: IP Prefix route (5)
                    Length: 34
                    Route Distinguisher: 00010a0000010064 (10.0.0.1:100)
                    ESI: 00:00:00:00:00:00:00:00:00:00
                    Ethernet Tag ID: 0
                    IP prefix length: 24
                    IPv4 address: 192.168.1.0
                    IPv4 Gateway address: 0.0.0.0
                    VNI: 100
        Path Attribute - ORIGIN: IGP
        Path Attribute - AS_PATH: empty
        Path Attribute - LOCAL_PREF: 100
        Path Attribute - EXTENDED_COMMUNITIES
            Flags: 0xc0, Optional, Transitive, Complete
            Type Code: EXTENDED_COMMUNITIES (16)
            Length: 24
            Carried extended communities: (3 communities)
                Route Target: 65535:100 [Transitive 2-Octet AS-Specific]
                EVPN Router's MAC: Router's MAC: 1a:d3:02:ff:00:00 [Transitive EVPN]
                Encapsulation: VXLAN Encapsulation [Transitive Opaque]
                    Type: Transitive Opaque (0x03)
                    Subtype (Opaque): Encapsulation (0x0c)
                    Tunnel type: VXLAN Encapsulation (8)
```

Quite a lot of information here in this Route Type 5 (RT5), but the most important part is the EVPN NLRI that contains the IP Prefix route that matches the has `192.168.1.0` address with `/24` prefix length. This prefix route is derived from the IP address of the `ethernet-1/1.1` subinterface attached to the `ip-vrf-1` network instance.

At the very end of this update message we see the extended community that indicates that VXLAN encapsulation is used for this route. This information is crucial for the receiving leaf to know how to encapsulate the traffic towards the destination. We can ensure that this information is well received, by looking at the tunnel table on `leaf2`:

```srl
A:leaf2# /show tunnel vxlan-tunnel all
------------------------------------------------------------------------------------------------
Show report for vxlan-tunnels 
------------------------------------------------------------------------------------------------
+--------------+--------------+--------------------------+
| VTEP Address |    Index     |       Last Change        |
+==============+==============+==========================+
| 10.0.0.1     | 294343953951 | 2024-07-19T14:45:50.000Z |
+--------------+--------------+--------------------------+
1 VXLAN tunnels, 1 active, 0 inactive
------------------------------------------------------------------------------------------------
```

The VXLAN tunnel towards the `leaf1` is setup thanks to the extended community information in the EVPN route.

And, quite frankly, this is it. A single RT5 route is all it takes to setup the non-IRB-based L3 EVPN service. Much simpler than the L2 EVPN service, isn't it?

## Dataplane details

Just to make sure that the control plane is not lying to us, let's have a look at the packet capture from the `e1-49` interface of `leaf1` when we have pings running from `ce1` to `ce2`:

/// note | Dataplane packet capture
[Here you can download][capture-icmp] the dataplane pcap for encapsulated ICMP packets
///

```hl_lines="5-9"
Frame 11: 148 bytes on wire (1184 bits), 148 bytes captured (1184 bits) on interface e1-49, id 0
Ethernet II, Src: 1a:d3:02:ff:00:31 (1a:d3:02:ff:00:31), Dst: 1a:80:04:ff:00:01 (1a:80:04:ff:00:01)
Internet Protocol Version 4, Src: 10.0.0.1, Dst: 10.0.0.2
User Datagram Protocol, Src Port: 50963, Dst Port: 4789
Virtual eXtensible Local Area Network
    Flags: 0x0800, VXLAN Network ID (VNI)
    Group Policy ID: 0
    VXLAN Network Identifier (VNI): 100
    Reserved: 0
Ethernet II, Src: 1a:d3:02:ff:00:00 (1a:d3:02:ff:00:00), Dst: 1a:1f:03:ff:00:00 (1a:1f:03:ff:00:00)
Internet Protocol Version 4, Src: 192.168.1.100, Dst: 192.168.2.100
Internet Control Message Protocol
```

Good news, the ICMP packets are encapsulated in VXLAN frames and sent over the IP fabric towards the destination. The destination leaf will decapsulate the packet and forward it towards the `ce2` device.

Ok, now [off to a more fancy use case](l3evpn-bgp-pe-ce.md) of the L3 EVPN service where CE devices are actual routers and they exchange routes with the BGP process running on the leaf switches inside a VRF.

[^1]: Like it is in the [L2 EVPN tutorial](../l2evpn/evpn.md#tunnelvxlan-interface).

[capture-evpn-rt5]: https://gitlab.com/rdodin/pics/-/wikis/uploads/e0d9687ad72413769e4407eb4e498f71/bgp-underlay-overlay-ex1.pcapng
[capture-icmp]: https://gitlab.com/rdodin/pics/-/wikis/uploads/580114f029cd12ef3c459f84b07e2963/icmp-vxlan.pcapng
