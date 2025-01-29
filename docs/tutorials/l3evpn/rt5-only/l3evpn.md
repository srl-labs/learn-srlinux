---
comments: true
---

# L3 EVPN Instance

In the prior chapters, we have been busy laying out the infrastructure foundation for the L3 overlay service. First we configured the IP fabric underlay routing, making sure that all leaf devices can reach spines and each other. Then, we established an iBGP peering between the leaf and spine devices with `evpn` address family to exchange overlay routing information.

All this has been leading up to the creation of an L3 EVPN instances that will allow our clients (Tenant Systems in the RFC terms) to have private L3 connectivity between them.

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":6,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>

We will have two use L3 EVPN use cases to cover. The focus of this chapter is on creating an L3 EVPN instance for the **Tenant 1** where tenant devices (for example, servers, named `srv1` and `srv2` in the diagram) are directly connected to the fabric switches with L3 interfaces.  
In the next chapter we will build a VPN instance for Tenant 2, where the tenant devices are routers that run BGP and exchange routes with the leaf switches.

As mentioned already, in this chapter the clients are directly connected to the leaf switches over L3 interfaces. Our clients are represented by `srv1` and `srv2` nodes and connected to the leaf switches. You can imagine, that these nodes are servers or another workload that requires L3 connectivity and are addressed with L3 interfaces themselves.

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":8,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>

The server nodes have their `eth1` interfaces configured with IPv4 addresses and our goal is to build the L3 connectivity between them such that `srv1` can ping `srv2` using their `eth1` interfaces.

On a logical level, the nodes should appear to be connected to a virtual router that will enable inter-subnet connectivity for them. This virtual router is represented by the L3 EVPN instance that we are about to create.

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":11,"zoom":3,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>

## Client-facing interface on leaf

First we configure the client-facing interface on leaf switches. As per our lab, the srv device is connected to the leaf' `ethernet-1/1` port, so we enable this interface with a logical routed subinterface and assign an IP address.

On each leaf we select IP address from the same subnet that the client is using. For example, if `srv1` has IP `192.168.1.100/24`, then we address the leaf interface with `192.168.1.1/24`:

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

The VNI value would play a crucial role in the VXLAN encapsulation and decapsulation process. It is used to identify the VXLAN tunnel and is used to map the VXLAN traffic to the correct VRF instance. For tenant 1 we chose to use VNI 100.

## L3 Network Instance (IP-VRF)

The next step is to create an L3 Network Instance (IP-VRF) on our leaf switches that is this virtual routing instance that contains the routing table for the L3 EVPN service.

1. **Create Network Instance**  

    We create a network instance named `tenant-1` that will be of type `ip-vrf` to denote that it is an L3 VRF:

    ```srl
    set / network-instance tenant-1 type ip-vrf
    set / network-instance tenant-1 admin-state enable
    ```

2. **Attach interfaces to the network instance**  
    Associate the previously configured client' subinterface and the tunnel interface with `tenant-1` VRF so that they become part of it:

    ```srl
    set / network-instance tenant-1 interface ethernet-1/1.1
    set / network-instance tenant-1 vxlan-interface vxlan1.100
    ```

3. **Configure EVPN Parameters**  
    At this step we configure the BGP EVPN parameters of this IP VRF by creating a `bgp-instance` and adding the vxlan interface under it.

    ```srl
    set / network-instance tenant-1 protocols bgp-evpn bgp-instance 1 admin-state enable
    set / network-instance tenant-1 protocols bgp-evpn bgp-instance 1 vxlan-interface vxlan1.100
    ```

    Define an EVPN Virtual Identifier (EVI) under the bgp-evpn instance will be used as a service identifier and to auto-derive the route distinguisher value.

    ```srl
    set / network-instance tenant-1 protocols bgp-evpn bgp-instance 1 evi 1
    ```

    We also create the `bgp-vpn` context under the IP VRF to enable multi-protocol BGP operation to support the EVPN route exchange.  
    Since we are going to exchange VPN routes (EVPN in this case) we need to provide a Route Target values for import and export so that the routes marked with this RT value would be imported in the target VRF.  
    We will set it manually, because otherwise auto-derivation process will use the AS number specified under the global BGP process, and we have different AS numbers per leaf.

    ```srl
    set / network-instance tenant-1 protocols bgp-vpn bgp-instance 1
    set / network-instance tenant-1 protocols bgp-vpn bgp-instance 1 route-target export-rt target:65535:1
    set / network-instance tenant-1 protocols bgp-vpn bgp-instance 1 route-target import-rt target:65535:1
    ```

    Optionally configure ECMP to enable load balancing in the overlay network.

    ```srl
    set / network-instance tenant-1 protocols bgp-evpn bgp-instance 1 ecmp 8
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

To verify L3 EVPN configuration we can start with checking the BGP VPN status and checking that RD value is auto-derived from the EVI we set. And RT value is set manually to the same value on both leafs.

```srl
A:leaf1# show network-instance tenant-1 protocols bgp-vpn bgp-instance 1
==================================================================================================
Net Instance   : tenant-1
    bgp Instance 1
--------------------------------------------------------------------------------------------------
        route-distinguisher: 10.0.0.1:1, auto-derived-from-evi
        export-route-target: target:65535:1, manual
        import-route-target: target:65535:1, manual
==================================================================================================
```

Next we can check the overlay BGP neighbor status:

```srl
A:leaf1# / show network-instance default protocols bgp neighbor 10.*
----------------------------------------------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
----------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------
+-----------------+-------------------------+-----------------+------+---------+--------------+--------------+------------+-------------------------+
|    Net-Inst     |          Peer           |      Group      | Flag | Peer-AS |    State     |    Uptime    |  AFI/SAFI  |     [Rx/Active/Tx]      |
|                 |                         |                 |  s   |         |              |              |            |                         |
+=================+=========================+=================+======+=========+==============+==============+============+=========================+
| default         | 10.10.10.10             | overlay         | S    | 65535   | established  | 0d:0h:7m:7s  | evpn       | [1/1/1]                 |
+-----------------+-------------------------+-----------------+------+---------+--------------+--------------+------------+-------------------------+
----------------------------------------------------------------------------------------------------------------------------------------------------------
Summary:
1 configured neighbors, 1 configured sessions are established,0 disabled peers
1 dynamic peers
```

Now we see that a single route has been sent and received by the `leaf1` to/from the `spine` switch acting as a Route Reflector. Let's check what has been received and sent:

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

Brilliant, we receive the remote IP prefix `192.168.2.0/24` and sent local IP prefix `192.168.0.1/24` to the other leaf.

/// details | Route Summarization
In a real-world scenario, you would see more routes being exchanged, especially if you have multiple clients connected to the leaf switches. A good design practice is to summarize the routes on the leaf switches to reduce the number of routes exchanged between the leafs and the spine and mimimize the control plane churn when new host routes are added/removed.

Route summarization is not covered in this tutorial, but it should be not that complicated to add it!
///

Let's have a look at the routing table of IP-VRF on both leafs:

/// tab | leaf1

```srl hl_lines="17-19"
A:leaf1# / show network-instance tenant-1 route-table
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance tenant-1
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+----------------------+------+-----------+---------------------+---------+---------+--------+-----------+-------------+-------------+-------------+----------------+
|        Prefix        |  ID  |   Route   |     Route Owner     | Active  | Origin  | Metric |   Pref    |  Next-hop   |  Next-hop   |   Backup    |  Backup Next-  |
|                      |      |   Type    |                     |         | Network |        |           |   (Type)    |  Interface  |  Next-hop   | hop Interface  |
|                      |      |           |                     |         | Instanc |        |           |             |             |   (Type)    |                |
|                      |      |           |                     |         |    e    |        |           |             |             |             |                |
+======================+======+===========+=====================+=========+=========+========+===========+=============+=============+=============+================+
| 192.168.1.0/24       | 4    | local     | net_inst_mgr        | True    | tenant- | 0      | 0         | 192.168.1.1 | ethernet-   |             |                |
|                      |      |           |                     |         | 1       |        |           | (direct)    | 1/1.1       |             |                |
| 192.168.1.1/32       | 4    | host      | net_inst_mgr        | True    | tenant- | 0      | 0         | None        | None        |             |                |
|                      |      |           |                     |         | 1       |        |           | (extract)   |             |             |                |
| 192.168.1.255/32     | 4    | host      | net_inst_mgr        | True    | tenant- | 0      | 0         | None        |             |             |                |
|                      |      |           |                     |         | 1       |        |           | (broadcast) |             |             |                |
| 192.168.2.0/24       | 0    | bgp-evpn  | bgp_evpn_mgr        | True    | tenant- | 0      | 170       | 10.0.0.2/32 |             |             |                |
|                      |      |           |                     |         | 1       |        |           | (indirect/v |             |             |                |
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
A:leaf2# / show network-instance tenant-1 route-table
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance tenant-1
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+----------------------+------+-----------+---------------------+---------+---------+--------+-----------+-------------+-------------+-------------+----------------+
|        Prefix        |  ID  |   Route   |     Route Owner     | Active  | Origin  | Metric |   Pref    |  Next-hop   |  Next-hop   |   Backup    |  Backup Next-  |
|                      |      |   Type    |                     |         | Network |        |           |   (Type)    |  Interface  |  Next-hop   | hop Interface  |
|                      |      |           |                     |         | Instanc |        |           |             |             |   (Type)    |                |
|                      |      |           |                     |         |    e    |        |           |             |             |             |                |
+======================+======+===========+=====================+=========+=========+========+===========+=============+=============+=============+================+
| 192.168.1.0/24       | 0    | bgp-evpn  | bgp_evpn_mgr        | True    | tenant- | 0      | 170       | 10.0.0.1/32 |             |             |                |
|                      |      |           |                     |         | 1       |        |           | (indirect/v |             |             |                |
|                      |      |           |                     |         |         |        |           | xlan)       |             |             |                |
| 192.168.2.0/24       | 4    | local     | net_inst_mgr        | True    | tenant- | 0      | 0         | 192.168.2.1 | ethernet-   |             |                |
|                      |      |           |                     |         | 1       |        |           | (direct)    | 1/1.1       |             |                |
| 192.168.2.1/32       | 4    | host      | net_inst_mgr        | True    | tenant- | 0      | 0         | None        | None        |             |                |
|                      |      |           |                     |         | 1       |        |           | (extract)   |             |             |                |
| 192.168.2.255/32     | 4    | host      | net_inst_mgr        | True    | tenant- | 0      | 0         | None        |             |             |                |
|                      |      |           |                     |         | 1       |        |           | (broadcast) |             |             |                |
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
sudo docker exec -i -t l3evpn-srv1 ash
```

```srl
/ # ping 192.168.2.100 -c 2
PING 192.168.2.100 (192.168.2.100): 56 data bytes
64 bytes from 192.168.2.100: seq=0 ttl=63 time=1.205 ms
64 bytes from 192.168.2.100: seq=1 ttl=63 time=0.841 ms

--- 192.168.2.100 ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.841/1.023/1.205 ms
```

Sweet, `srv1` can ping `srv2` over the IP fabric using the L3 EVPN service that we've just configured. Now let's dig deeper on the protocol details and explore the EVPN route types that made this datapath connectivity possible.

## Control plane details

It is quite important to understand how much simpler control plane operations are in case of a pure L3 EVPN service with no bridge domains involved. Here is what happens when we commit the configuration of the "tenant-1" L3 EVPN service on the leaf switches.

/// note | packetcapture or it didn't happen
The following explanation is based on the packet capture fetched with Edgeshark from the `leaf1`'s `e1-49` interface. You can [download the pcap][capture-evpn-rt5].

///

`leaf1` establishes a BGP session with `spine` (spine acts as a Route Reflector) and signals the multiprotocol capability AFI/SAFI=L2VPN/EVPN.

```title="packet #9" linenums="1"
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

Since both leafs have L3 interfaces in the `tenant-1` IP-VRF and EVPN is configured in this network instance, BGP process starts exchanging EVPN routes.

First we have `leaf1` sending an update with the following contents:

```title="packet #15" linenums="1" hl_lines="16 20 25-28 39-42"
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
                    Route Distinguisher: 00010a0000010064 (10.0.0.1:1)
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

Quite a lot of information here in this Route Type 5 (RT5), but the most important part is the EVPN NLRI that contains the IP Prefix route the has `192.168.1.0` address with `/24` prefix length and `VNI=100`.  
This prefix route is derived from the IP address of the `ethernet-1/1.1` subinterface attached to the `tenant-1` network instance. And the VNI value is the same as the one used in the VXLAN tunnel interface attached to the `tenant-1` network instance.

At the very end of this update message we see the extended community that indicates that VXLAN encapsulation is used for this route. This information is crucial for the receiving leaf to know how to encapsulate the traffic towards the destination. We can ensure that this information is well received, by looking at the tunnel table on `leaf2`:

```srl
A:leaf2# /show tunnel vxlan-tunnel vtep 10.0.0.1
--------------------------------------------------------------------
Show report for vxlan-tunnels vtep
--------------------------------------------------------------------
VTEP Address: 10.0.0.1
Index       : 320047052051
Last Change : 2024-07-22T12:57:11.000Z
--------------------------------------------------------------------
Destinations
--------------------------------------------------------------------
+------------------+-----------------+------------+----------------+
| Tunnel Interface | VXLAN Interface | Egress VNI |      Type      |
+==================+=================+============+================+
| vxlan1           | 100             | 100        | ip-destination |
+------------------+-----------------+------------+----------------+
--------------------------------------------------------------------
0 bridged destinations, 0 multicast, 0 unicast, 0 es
1 routed destinations
```

The VXLAN tunnel towards the `leaf1` is setup thanks to the extended community information in the EVPN route.

And, quite frankly, this is it. A single RT5 route is all it takes to setup the non-IRB-based L3 EVPN service. Much simpler than the L2 EVPN service, isn't it?

## Dataplane details

Just to make sure that the control plane is not lying to us, let's have a look at the packet capture from the `e1-49` interface of `leaf1` when we have pings running from `srv1` to `srv2`:

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

## Pros and Cons?

If the dataplane is simpler and there is less things to configure then why not use L3 EVPN with L3 interfaces all the time? Well, the answer is simple - it is not always feasible.

To start with, you may have workloads that still require L2 connectivity. In this case you would need to use L2 EVPN service.

Multihoming requires your server to be connected to multiple leaf switches and use ECMP to load balance the traffic. This puts a requirement on the server to be able to handle routing and to do ECMP hashing, which is another configuration step that may not be feasible in some cases.

Besides multihoming, workload migration may be a challenge, since moving the workload from one leaf to another would mandate the change of the IP address on the server.

Some of these limitations may be lifted off when [a more dynamic L3 EVPN service](l3evpn-bgp-pe-ce.md) is used with CE devices being actual routers exchanging prefixes with the L3 EVPN instance running on the leaf switches. Let's check it out!

[^1]: Like it is in the [L2 EVPN tutorial](../../l2evpn/evpn.md#tunnelvxlan-interface).

[capture-evpn-rt5]: https://gitlab.com/rdodin/pics/-/wikis/uploads/e0d9687ad72413769e4407eb4e498f71/bgp-underlay-overlay-ex1.pcapng
[capture-icmp]: https://gitlab.com/rdodin/pics/-/wikis/uploads/580114f029cd12ef3c459f84b07e2963/icmp-vxlan.pcapng

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
