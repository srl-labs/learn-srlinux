---
comments: true
---

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>

# L3 EVPN Instance with BGP PE-CE


## (Optional) BGP Peering with the CE/Client

This step is optional and is relevant if another router, acting as our client, wants to exchange routes with the EVPN Overlay (ip-vrf).

<p align="center">
  <img src="https://raw.githubusercontent.com/srl-labs/srl-l3evpn-tutorial-lab/main/images/pe-ce.png" alt="Peering with Client">
</p>

In this case, both clients have loopback IPs that need to be advertised to the L3 EVPN Network Instance (ip-vrf). This requires setting up a routing protocol between the clients (frr) and the routers they're connected to (Leaf1 & Leaf2).

In the previous chapter, we completed the ip-vrf configuration, moving forward, we'll integrate a routing protocol within it to establish connectivity with the client. SRLinux supports OSPF, ISIS, and BGP in the overlay. We're opting for BGP because we love it for many reasons. **Please note, the FRR client BGP parameters have been pre configured.**

1. **AS Number and Router ID**  
The initial step involves specifying the autonomous system number and router-id for this ip-vrf, which will be uniformly applied across all routers encompassed by this ip-vrf. Ultimately, these routers will function collectively as if they are a singular router distributed over multiple devices.

    ``` srl
    set / network-instance ip-vrf-1 protocols bgp autonomous-system 500
    set / network-instance ip-vrf-1 protocols bgp router-id 3.3.3.3
    ```

1. **BGP Address Family**  
Since our clients use IPv4 addresses, we activate the BGP IPv4 address family to facilitate route exchange with the client. Although the overlay supports IPv6, we have not enabled it as our clients do not have IPv6 routes to announce.

    ``` srl
    set / network-instance ip-vrf-1 protocols bgp afi-safi ipv4-unicast admin-state enable
    ```

1. **Configure the Neighbor Parameters**  
We configure the BGP peer/neighbor IP and its corresponding autonomous system number, then assign the BGP neighbor to a peer group.

    ``` srl
    set / network-instance ip-vrf-1 protocols bgp group client
    set / network-instance ip-vrf-1 protocols bgp neighbor 192.168.1.100 peer-as 1000000000
    set / network-instance ip-vrf-1 protocols bgp neighbor 192.168.1.100 peer-group client
    ```

1. **Allow BGP to exchange routes by default**  
By default, all incoming and outgoing eBGP routes are blocked. We will disable this default setting to permit all incoming and outgoing routes.

    ``` srl
    set / network-instance ip-vrf-1 protocols bgp ebgp-default-policy import-reject-all false
    set / network-instance ip-vrf-1 protocols bgp ebgp-default-policy export-reject-all false
    ```

1. **Send Default Route to the Client**  
In the previous step, we disabled eBGP's default route blocking. However, eBGP doesn't automatically announce routes to the client since it treats the peer as an external system and only announces selected routes through a policy. To share overlay routes with the client, we must either configure an export route policy or enable the following feature to distribute a default route to the client.

    ``` srl
    set / network-instance ip-vrf-1 protocols bgp group client send-default-route ipv4-unicast true
    ```

**Verification**

Each leaf appears to have successfully established eBGP with its client.

/// tab | leaf1

```srl hl_lines="10"
A:leaf1# show network-instance ip-vrf-1 protocols bgp neighbor
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "ip-vrf-1"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+------------------------+-----------------------------------+------------------------+--------+-------------+-------------------+-------------------+-----------------+-----------------------------------+
|        Net-Inst        |               Peer                |         Group          | Flags  |   Peer-AS   |       State       |      Uptime       |    AFI/SAFI     |          [Rx/Active/Tx]           |
+========================+===================================+========================+========+=============+===================+===================+=================+===================================+
| ip-vrf-1               | 192.168.1.100                     | client                 | S      | 1000000000  | established       | 2d:1h:56m:18s     | ipv4-unicast    | [3/1/1]                           |
+------------------------+-----------------------------------+------------------------+--------+-------------+-------------------+-------------------+-----------------+-----------------------------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Summary:
1 configured neighbors, 1 configured sessions are established,0 disabled peers
0 dynamic peers
```

///

/// tab | leaf2

```srl hl_lines="10"
A:leaf2# show network-instance ip-vrf-1 protocols bgp neighbor
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "ip-vrf-1"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+----------------------+--------------------------------+----------------------+--------+------------+------------------+------------------+----------------+--------------------------------+
|       Net-Inst       |              Peer              |        Group         | Flags  |  Peer-AS   |      State       |      Uptime      |    AFI/SAFI    |         [Rx/Active/Tx]         |
+======================+================================+======================+========+============+==================+==================+================+================================+
| ip-vrf-1             | 192.168.2.100                  | client               | S      | 2000000000 | established      | 2d:1h:57m:51s    | ipv4-unicast   | [3/1/1]                        |
+----------------------+--------------------------------+----------------------+--------+------------+------------------+------------------+----------------+--------------------------------+
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Summary:
1 configured neighbors, 1 configured sessions are established,0 disabled peers
0 dynamic peers
```

///

Below are the advertised and received routes from Leaf's perspective. Each leaf has announced a default route to its clients and is receiving the client's loopback IP (highlighted).

It appears the client is re-advertising the default route back to the leaf, but the leaf is ignoring the route due to AS-Loop.

/// tab | leaf1

```srl hl_lines="33"
A:leaf1# show network-instance ip-vrf-1 protocols bgp neighbor 192.168.1.100 advertised-routes ipv4
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Peer        : 192.168.1.100, remote AS: 1000000000, local AS: 500
Type        : static
Description : None
Group       : client
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Origin codes: i=IGP, e=EGP, ?=incomplete
+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|                 Network                              Path-id                   Next Hop                 MED                                     LocPref                                   AsPath               Origin      |
+============================================================================================================================================================================================================================+
| 0.0.0.0/0                                 0                               192.168.1.1                    -                                        100                               [500]                         ?        |
+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
1 advertised BGP routes
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



A:leaf1# show network-instance ip-vrf-1 protocols bgp neighbor 192.168.1.100 received-routes ipv4
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Peer        : 192.168.1.100, remote AS: 1000000000, local AS: 500
Type        : static
Description : None
Group       : client
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Status codes: u=used, *=valid, >=best, x=stale
Origin codes: i=IGP, e=EGP, ?=incomplete
+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|  Status               Network                        Path-id                   Next Hop                 MED                                    LocPref                                   AsPath               Origin      |
+===========================================================================================================================================================================================================================+
|             0.0.0.0/0                      0                              192.168.1.100                  -                                       100                               [1000000000, 500]             ?        |
|    u*>      1.1.1.1/32                     0                              192.168.1.100                  -                                       100                               [1000000000]                  ?        |
|     *       192.168.1.0/24                 0                              192.168.1.100                  -                                       100                               [1000000000]                  ?        |
+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
3 received BGP routes : 1 used 2 valid
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

///

/// tab | leaf2

```srl hl_lines="33"
A:leaf2# show network-instance ip-vrf-1 protocols bgp neighbor 192.168.2.100 advertised-routes ipv4
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Peer        : 192.168.2.100, remote AS: 2000000000, local AS: 500
Type        : static
Description : None
Group       : client
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Origin codes: i=IGP, e=EGP, ?=incomplete
+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|               Network                          Path-id                 Next Hop               MED                                 LocPref                               AsPath             Origin     |
+=======================================================================================================================================================================================================+
| 0.0.0.0/0                             0                            192.168.2.1                 -                                    100                            [500]                      ?       |
+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
1 advertised BGP routes
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



A:leaf2# show network-instance ip-vrf-1 protocols bgp neighbor 192.168.2.100 received-routes ipv4
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Peer        : 192.168.2.100, remote AS: 2000000000, local AS: 500
Type        : static
Description : None
Group       : client
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Status codes: u=used, *=valid, >=best, x=stale
Origin codes: i=IGP, e=EGP, ?=incomplete
+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|  Status             Network                      Path-id                 Next Hop               MED                                 LocPref                               AsPath             Origin     |
+=========================================================================================================================================================================================================+
|            0.0.0.0/0                    0                            192.168.2.100               -                                    100                            [2000000000, 500]          ?       |
|   u*>      2.2.2.2/32                   0                            192.168.2.100               -                                    100                            [2000000000]               ?       |
|    *       192.168.2.0/24               0                            192.168.2.100               -                                    100                            [2000000000]               ?       |
+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
3 received BGP routes : 1 used 2 valid
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

///

Let's examine the routing table of the VRF on each leaf. Both leaves share the same list of routes, with different next hops. Local routes resolve to a local interface, while remote routes learned from the other leaf resolve to a VxLAN tunnel. Routes resolving to a VxLAN tunnel are highlighted for clarity.

/// tab | leaf1

```srl hl_lines="12 18"
A:leaf1# show network-instance ip-vrf-1 route-table
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance ip-vrf-1
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+---------------------------------+-------+------------+----------------------+----------+----------+---------+------------+--------------------+--------------------+--------------------+------------------------------------+
|             Prefix              |  ID   | Route Type |     Route Owner      |  Active  |  Origin  | Metric  |    Pref    |  Next-hop (Type)   | Next-hop Interface |  Backup Next-hop   |     Backup Next-hop Interface      |
|                                 |       |            |                      |          | Network  |         |            |                    |                    |       (Type)       |                                    |
|                                 |       |            |                      |          | Instance |         |            |                    |                    |                    |                                    |
+=================================+=======+============+======================+==========+==========+=========+============+====================+====================+====================+====================================+
| 1.1.1.1/32                      | 0     | bgp        | bgp_mgr              | True     | ip-vrf-1 | 0       | 170        | 192.168.1.0/24     | ethernet-1/1.1     |                    |                                    |
|                                 |       |            |                      |          |          |         |            | (indirect/local)   |                    |                    |                                    |
| 2.2.2.2/32                      | 0     | bgp-evpn   | bgp_evpn_mgr         | True     | ip-vrf-1 | 0       | 170        | 100.0.0.2/32       |                    |                    |                                    |
|                                 |       |            |                      |          |          |         |            | (indirect/vxlan)   |                    |                    |                                    |
| 192.168.1.0/24                  | 2     | local      | net_inst_mgr         | True     | ip-vrf-1 | 0       | 0          | 192.168.1.1        | ethernet-1/1.1     |                    |                                    |
|                                 |       |            |                      |          |          |         |            | (direct)           |                    |                    |                                    |
| 192.168.1.1/32                  | 2     | host       | net_inst_mgr         | True     | ip-vrf-1 | 0       | 0          | None (extract)     | None               |                    |                                    |
| 192.168.1.255/32                | 2     | host       | net_inst_mgr         | True     | ip-vrf-1 | 0       | 0          | None (broadcast)   |                    |                    |                                    |
| 192.168.2.0/24                  | 0     | bgp-evpn   | bgp_evpn_mgr         | True     | ip-vrf-1 | 0       | 170        | 100.0.0.2/32       |                    |                    |                                    |
|                                 |       |            |                      |          |          |         |            | (indirect/vxlan)   |                    |                    |                                    |
+---------------------------------+-------+------------+----------------------+----------+----------+---------+------------+--------------------+--------------------+--------------------+------------------------------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 routes total                    : 6
IPv4 prefixes with active routes     : 6
IPv4 prefixes with active ECMP routes: 0
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

///

/// tab | leaf2

```srl hl_lines="10 14"
A:leaf2# show network-instance ip-vrf-1 route-table
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance ip-vrf-1
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+-----------------------------+-------+------------+----------------------+----------+----------+---------+------------+------------------+------------------+------------------+--------------------------+
|           Prefix            |  ID   | Route Type |     Route Owner      |  Active  |  Origin  | Metric  |    Pref    | Next-hop (Type)  |     Next-hop     | Backup Next-hop  |     Backup Next-hop      |
|                             |       |            |                      |          | Network  |         |            |                  |    Interface     |      (Type)      |        Interface         |
|                             |       |            |                      |          | Instance |         |            |                  |                  |                  |                          |
+=============================+=======+============+======================+==========+==========+=========+============+==================+==================+==================+==========================+
| 1.1.1.1/32                  | 0     | bgp-evpn   | bgp_evpn_mgr         | True     | ip-vrf-1 | 0       | 170        | 100.0.0.1/32     |                  |                  |                          |
|                             |       |            |                      |          |          |         |            | (indirect/vxlan) |                  |                  |                          |
| 2.2.2.2/32                  | 0     | bgp        | bgp_mgr              | True     | ip-vrf-1 | 0       | 170        | 192.168.2.0/24   | ethernet-1/1.1   |                  |                          |
|                             |       |            |                      |          |          |         |            | (indirect/local) |                  |                  |                          |
| 192.168.1.0/24              | 0     | bgp-evpn   | bgp_evpn_mgr         | True     | ip-vrf-1 | 0       | 170        | 100.0.0.1/32     |                  |                  |                          |
|                             |       |            |                      |          |          |         |            | (indirect/vxlan) |                  |                  |                          |
| 192.168.2.0/24              | 2     | local      | net_inst_mgr         | True     | ip-vrf-1 | 0       | 0          | 192.168.2.1      | ethernet-1/1.1   |                  |                          |
|                             |       |            |                      |          |          |         |            | (direct)         |                  |                  |                          |
| 192.168.2.1/32              | 2     | host       | net_inst_mgr         | True     | ip-vrf-1 | 0       | 0          | None (extract)   | None             |                  |                          |
| 192.168.2.255/32            | 2     | host       | net_inst_mgr         | True     | ip-vrf-1 | 0       | 0          | None (broadcast) |                  |                  |                          |
+-----------------------------+-------+------------+----------------------+----------+----------+---------+------------+------------------+------------------+------------------+--------------------------+
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 routes total                    : 6
IPv4 prefixes with active routes     : 6
IPv4 prefixes with active ECMP routes: 0
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

///

Then let's send a ping between client loopbacks to conclue this chapter.

/// tab | Ping between client loopbacks

```srl
frr1:/# ping 2.2.2.2 -I 1.1.1.1 -c3
PING 2.2.2.2 (2.2.2.2) from 1.1.1.1: 56 data bytes
64 bytes from 2.2.2.2: seq=0 ttl=63 time=2.453 ms
64 bytes from 2.2.2.2: seq=1 ttl=63 time=1.865 ms
64 bytes from 2.2.2.2: seq=2 ttl=63 time=1.922 ms

--- 2.2.2.2 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 1.865/2.080/2.453 ms
```

///

[^1]: Like it is in the [L2 EVPN tutorial](../l2evpn/evpn.md#tunnelvxlan-interface).
