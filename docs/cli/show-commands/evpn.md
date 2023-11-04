---
comments: true
title: Show commands for EVPN
---

# EVPN

## L2 EVPN BGP Commands

Checking Route Type 3 in the underlay:

```srl
A:srl-b# /show network-instance default protocols bgp routes evpn route-type 3 detail
--------------------------------------------------------------------------------------
Show report for the EVPN routes in network-instance  "default"
--------------------------------------------------------------------------------------
Route Distinguisher: 10.1.1.1:111
Tag-ID             : 0
Originating router : 10.1.1.1
neighbor           : 10.1.1.1
Received paths     : 1
  Path 1: <Best,Valid,Used,>
    VNI             : 1
    Route source    : neighbor 10.1.1.1 (last modified 50s ago)
    Route preference: No MED, LocalPref is 100
    Atomic Aggr     : false
    BGP next-hop    : 10.1.1.1
    AS Path         :  i
    Communities     : [target:65000:1, bgp-tunnel-encap:VXLAN]
    RR Attributes   : No Originator-ID, Cluster-List is []
    Aggregation     : None
    Unknown Attr    : None
    Invalid Reason  : None
    Tie Break Reason: none
--------------------------------------------------------------------------------------
```

Checking Route Type 2 in the underlay:

```srl
A:leaf1# show network-instance default protocols bgp routes evpn route-type 2 summary
--------------------------------------------------------------------------------------
BGP Router ID: 192.0.2.3      AS: 65003      Local AS: 65003
--------------------------------------------------------------------------------------
Type 2 MAC-IP Advertisement Routes
+--------+------------------+---------+-------------------+------------+-----------+--
| Status |      Route-      | Tag-ID  |    MAC-address    | IP-address | neighbor  | Next-Hop  | VNI |              ESI               |   MAC Mobility   |
|        |  distinguisher   |         |                   |            |           |           
+========+==================+=========+===================+============+===========+==
| u*>    | 192.0.2.4:1      | 0       | 00:00:00:00:00:02 | 0.0.0.0    | 192.0.2.1 | 192.0.2.4 | 1   | 00:00:00:00:00:00:00:00:00:00  | -                |
| u*>    | 192.0.2.5:1      | 0       | 00:00:00:00:00:03 | 0.0.0.0    | 192.0.2.1 | 192.0.2.5 | 1   | 00:00:00:00:00:00:00:00:00:00  | -                |
+--------+------------------+---------+-------------------+------------+-----------+--
```

## L2 EVPN MAC Table

A:leaf1# show network-instance mac_vrf_1 bridge-table mac-table all
+--------------------+-------------------------------------- ----------------+--------
|      Address       |                     Destination                      | Dest Index    |      Type      | Active  | Aging  |  Last Update            |
+====================+======================================================+=========
| 00:00:00:00:00:01  | ethernet-1/36.300                                     | 7            | learnt         | true    | 263    | 2021-05-04T13:56:25.000Z                             | 00:00:00:00:00:02  | vxlan-interface:vxlan1.1 vtep:192.0.2.4 vni:1         | 718427846823 | evpn           | true    | N/A    | 2021-05-04T13:43:48.000Z
| 00:00:00:00:00:03  | vxlan-interface:vxlan1.1 vtep:192.0.2.5 vni:1         | 718427846825 | evpn           | true    | N/A    | 2021-05-04T14:04:39.000Z
+--------+------------------+---------+-------------------+------------+-----------+--

## L3 EVPN-VxLAN Asymmetric

```srl
A:srl-a# /show network-instance mac-vrf-14 bridge-table mac-table all
--------------------------------------------------------------------------------------

Mac-table of network instance mac-vrf-14
--------------------------------------------------------------------------------------

+-------------------+----------------------------+-----------+--------+--------+------
|      Address      |        Destination         |   Dest    |  Type  | Active | Aging |        Last Update         |
|                   |                            |   Index   |        |        |
+===================+============================+===========+========+========+======
| 00:00:5E:00:01:01 | irb                        | 0         | irb-in | true   | N/A   | 2023-04-14T19:54:11.000Z   |
|                   |                            |           | terfac |        |       |                            |
|                   |                            |           | e-anyc |        |       |                            |
|                   |                            |           | ast    |        |       |                            |
| 1A:4E:01:FF:00:43 | vxlan-interface:vxlan1.14  | 6986941   | evpn-  | true   | N/A   | 2023-04-14T20:02:11.000Z   |
|                   | vtep:10.1.1.2 vni:14       |           | static |        |       |                            |
| 1A:B5:00:FF:00:43 | irb                        | 0         | irb-in | true   | N/A   | 2023-04-14T19:54:11.000Z   |
|                   |                            |           | terface |        |
+-------------------+----------------------------+-----------+--------+--------+------
```

```srl
A:srl-a# /show network-instance ip-vrf-15 route-table all
--------------------------------------------------------------------------------------

IPv4 unicast route table of network instance ip-vrf-15
--------------------------------------------------------------------------------------

+-------------+------+-----------+---------------------+---------------------+--------
|   Prefix    |  ID  |   Route   |     Route Owner     |       Active        | Metric  |  Pref  | Next-  | Next-  |
|             |      |   Type    |                     |                     |         |        |  hop   | hop In |
|             |      |           |                     |                     |         |        | (Type) | terfac |
|             |      |           |                     |                     |         |        |        |   e    |
+=============+======+===========+=====================+=====================+========
| 13.1.1.0/24 | 7    | local     | net_inst_mgr        | True                | 0       | 0      | 13.1.1 | irb2.1 |
|             |      |           |                     |                     |         |        | .250 ( | 3      |
|             |      |           |                     |                     |         |        | direct |        |
| 13.1.1.250/ | 7    | host      | net_inst_mgr        | True                | 0       | 0      | None ( | None   |
| 32          |      |           |                     |                     |         |        | extrac |        |
|             |      |           |                     |                     |         |        | t)     |        |
+-------------+------+-----------+---------------------+---------------------+--------
```

## L3VPN-VxLAN IFL BGP Commands

Checking Route Type 5 in the underlay:

```srl
A:srl-b# show network-instance default protocols bgp routes evpn route-type 5 summary
--------------------------------------------------------------------------------------

Show report for the BGP route table of network-instance "default"
--------------------------------------------------------------------------------------

Status codes: u=used, *=valid, >=best, x=stale
Origin codes: i=IGP, e=EGP, ?=incomplete
--------------------------------------------------------------------------------------

BGP Router ID: 10.10.10.2      AS: 65003      Local AS: 65003
--------------------------------------------------------------------------------------

Type 5 IP Prefix Routes
+--------+--------------+------------+---------------------+--------------+-----------
| Status | Route-distin |   Tag-ID   |     IP-address      |   neighbor   |   Next-Hop   |     VNI      |   Gateway    |
|        |   guisher    |            |                     |              |
+========+==============+============+=====================+==============+===========
| u*>    | 10.1.1.1:10  | 0          | 10.1.1.0/24         | 10.1.1.1     | 10.1.1.1     | 10           | 0.0.0.0      |
| u*>    | 10.1.1.1:10  | 0          | 11.1.1.0/24         | 10.1.1.1     | 10.1.1.1     | 10           | 0.0.0.0      |
+--------+--------------+------------+---------------------+--------------+-----------
--------------------------------------------------------------------------------------

2 IP Prefix routes 2 used, 2 valid
--------------------------------------------------------------------------------------
```

```srl
A:srl-b# show network-instance default protocols bgp routes evpn route-type 5 prefix 11.1.1.0/24 detail
--------------------------------------------------------------------------------------

Show report for the EVPN routes in network-instance  "default"
--------------------------------------------------------------------------------------

Route Distinguisher: 10.1.1.1:10
Tag-ID             : 0
ip-prefix-len      : 24
ip-prefix          : 11.1.1.0/24
neighbor           : 10.1.1.1
Gateway IP         : 0.0.0.0
Received paths     : 1
  Path 1: <Best,Valid,Used,>
    ESI             : 00:00:00:00:00:00:00:00:00:00
    VNI             : 10
    Route source    : neighbor 10.1.1.1 (last modified 8m20s ago)
    Route preference: No MED, LocalPref is 100
    Atomic Aggr     : false
    BGP next-hop    : 10.1.1.1
    AS Path         :  i
    Communities     : [target:65000:10, mac-nh:1a:b5:00:ff:00:00, bgp-tunnel-encap:VXLAN]
    RR Attributes   : No Originator-ID, Cluster-List is []
    Aggregation     : None
    Unknown Attr    : None
    Invalid Reason  : None
    Tie Break Reason: none
--------------------------------------------------------------------------------------
```

## VxLAN Tunnel Status

```srl
A:srl-b# /show network-instance default tunnel-table all
--------------------------------------------------------------------------------------

IPv4 tunnel table of network-instance "default"
--------------------------------------------------------------------------------------

+----------+----------+----------+----------+----------+----------+----------+--------
|   IPv4   |  Encaps  |  Tunnel  |  Tunnel  |   FIB    |  Metric  | Preferen |   Last   | Next-hop | Next-hop |
|  Prefix  |   Type   |   Type   |    ID    |          |          |    ce    |  Update  |  (Type)  |          |
+==========+==========+==========+==========+==========+==========+==========+========
| 10.1.1.1 | vxlan    | vxlan    | 1        | Y        | 0        | 0        | 2023-04- | 192.168. | ethernet |
| /32      |          |          |          |          |          |          | 12T13:22 | 10.1     | -1/1.10  |
|          |          |          |          |          |          |          | :27.649Z | (direct) |          |
+----------+----------+----------+----------+----------+----------+----------+--------
--------------------------------------------------------------------------------------

1 VXLAN tunnels, 1 active, 0 inactive
--------------------------------------------------------------------------------------
```

## VxLAN Tunnel Statistics

```srl
A:srl-b# info from state /tunnel vxlan-tunnel
    tunnel {
        vxlan-tunnel {
            vtep 10.1.1.1 {
                index 6986915
                last-change "20 minutes ago"
                statistics {
                    in-octets 0
                    in-packets 0
                    in-discarded-packets 0
                    out-octets 0
                    out-packets 0
                    out-discarded-packets 0
                }
            }
            statistics {
                in-octets 0
                in-packets 0
                in-discarded-packets 0
                out-octets 0
                out-packets 0
            }
        }
    }
```
