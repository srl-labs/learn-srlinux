---
comments: true
title: Troubleshooting BGP
---

# BGP

## BGP Status

/// tab | CLI

```srl
A:srl-b# show network-instance default protocols bgp summary
--------------------------------------------------------------------------------------

BGP is enabled and up in network-instance "default"
Global AS number  : 65502
BGP identifier    : 10.10.10.2
--------------------------------------------------------------------------------------

Total paths               : None
  Received routes           : None
  Received and active routes: None
  Total UP peers            : 1
  Configured peers          : 1, 0 are disabled
  Dynamic peers             : None
--------------------------------------------------------------------------------------
```

///
/// tab | Path
`/network-instance[name=*]/protocols/bgp`
///

## BGP Neighbor

/// tab | CLI

```srl
A:srl-a# show network-instance default protocols bgp neighbor 192.168.10.2 detail

---------------------------------------------------------------------------------

Peer : 192.168.10.2, remote AS: 65502, local AS: 65501, peer-type : ebgp
Type : static
Description : None
Group : EBGP1
Export policies : None
Import policies: None
Under maintenance: False
Maintenance group:
---------------------------------------------------------------------------------

Admin-state is enable, session-state is established, up for 0d:0h:20m:17s
TCP connection is 192.168.10.1 [179] -> 192.168.10.2 [45189]
TCP-MD5 authentication is disabled
0 messages in input queue, 0 messages in output queue
---------------------------------------------------------------------------------
```

///
/// tab | Path
`/network-instance[name=*]/protocols/bgp/neighbor[peer-address=*]`
///

## BGP Routes

/// tab | CLI

```srl
A:srl-a# show network-instance default protocols bgp routes ipv4 summary
--------------------------------------------------------------------------------------

Show report for the BGP route table of network-instance "default"
--------------------------------------------------------------------------------------

Status codes: u=used, *=valid, >=best, x=stale
Origin codes: i=IGP, e=EGP, ?=incomplete
--------------------------------------------------------------------------------------

+------+------------------+--------------------------+------+------+------------------
| Stat |     Network      |         Next Hop         | MED  | LocP |  Path Val
|  us  |                  |                          |      | ref  |
+======+==================+==========================+======+======+==================
| u*>  | 10.10.10.1/32    | 0.0.0.0                  | -    | 100  |  i              |
| u*>  | 192.168.10.0/30  | 0.0.0.0                  | -    | 100  |  i              |
| u*>  | 192.168.20.0/30  | 0.0.0.0                  | -    | 100  |  i              |
| u*>  | 192.168.50.0/30  | 0.0.0.0                  | -    | 100  |  i              |
+------+------------------+--------------------------+------+------+------------------


4 received BGP routes: 4 used, 4 valid, 0 stale
4 available destinations: 0 with ECMP multipaths
--------------------------------------------------------------------------------------
```

///
/// tab | Path
`/network-instance[name=*]/bgp-rib/ipv4-unicast/local-rib/routes[prefix=*][neighbor=*][origin-protocol=*][path-id=*]/`
///

## BGP Neighbor Received Routes

/// tab | CLI

```srl
A:srl-b# show network-instance default protocols bgp neighbor 192.168.10.1 received-routes ipv4
--------------------------------------------------------------------------------------

Peer        : 192.168.10.1, remote AS: 65501, local AS: 65502
Type        : static
Description : None
Group       : EBGP1
--------------------------------------------------------------------------------------------------------------------------------+

Status codes: u=used, *=valid, >=best, x=stale
Origin codes: i=IGP, e=EGP, ?=incomplete
+-------------------------------------------------------------------------------------------------------------------------------+
|    Status          Network         Path-id        Next Hop           MED           LocPref         AsPath          Origin     |
+===============================================================================================================================+
|                 10.10.10.1/32   0               192.168.10.1          -              100        [65501]               i       |
|                 192.168.10.0/   0               192.168.10.1          -              100        [65501]               i       |
|                 30                                                                                                            |
|                 192.168.20.0/   0               192.168.10.1          -              100        [65501]               i       |
|                 30                                                                                                            |
|                 192.168.50.0/   0               192.168.10.1          -              100        [65501]               i       |
|                 30                                                                                                            |
+-------------------------------------------------------------------------------------------------------------------------------+


4 received BGP routes : 0 used 0 valid
--------------------------------------------------------------------------------------
```

///
/// tab | Path
`/network-instance[name=*]/bgp-rib/ipv4-unicast/rib-in-out/rib-in-pre/routes[prefix=*][neighbor=*][path-id=*]/prefix`
///

## BGP Neighbor Advertised Routes

/// tab | CLI

```srl
A:srl-a# show network-instance default protocols bgp neighbor 192.168.10.2 advertised-routes ipv4
--------------------------------------------------------------------------------------

Peer        : 192.168.10.2, remote AS: 65502, local AS: 65501
Type        : static
Description : None
Group       : EBGP1
--------------------------------------------------------------------------------------

Origin codes: i=IGP, e=EGP, ?=incomplete
+-------------------------------------------------------------------------------------
|     Network           Path-id          Next Hop             MED             LocPref           AsPath            Origin      |
+=====================================================================================
| 10.10.10.1/32     0                 192.168.10.1             -                100         [65501]                  i        |
| 192.168.10.0/30   0                 192.168.10.1             -                100         [65501]                  i        |
| 192.168.20.0/30   0                 192.168.10.1             -                100         [65501]                  i        |
| 192.168.50.0/30   0                 192.168.10.1             -                100         [65501]                  i        |
+-------------------------------------------------------------------------------------
4 advertised BGP routes
--------------------------------------------------------------------------------------
```

///
/// tab | Path
`/network-instance[name=*]/bgp-rib/ipv4-unicast/rib-in-out/rib-out-post/routes[prefix=*][neighbor=*][path-id=*]/prefix`
///

## BGP Configuration

```srl
A:srl-a# info network-instance default protocols bgp
    network-instance default {
        protocols {
            bgp {
                autonomous-system 65501
                router-id 10.10.10.1
                group EBGP1 {
                    peer-as 65502
                }
                neighbor 192.168.10.2 {
                    export-policy export-local
                    peer-group EBGP1
                }
            }
        }
    }
```
