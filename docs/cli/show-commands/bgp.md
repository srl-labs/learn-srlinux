---
comments: true
title: Troubleshooting BGP
---

# BGP

## Status

/// tab | CLI

```srl
A:srl-b# show network-instance default protocols bgp summary
------------------------------------------------------------------------------------
BGP is enabled and up in network-instance "default"
Global AS number  : 65000
BGP identifier    : 10.10.10.1
------------------------------------------------------------------------------------
  Total paths               : 6
  Received routes           : 3
  Received and active routes: None
  Total UP peers            : 1
  Configured peers          : 2, 0 are disabled
  Dynamic peers             : None
------------------------------------------------------------------------------------
Default preferences
  BGP Local Preference attribute: 100
  EBGP route-table preference   : 170
  IBGP route-table preference   : 170
------------------------------------------------------------------------------------
Wait for FIB install to advertise: True
Send rapid withdrawals           : disabled
------------------------------------------------------------------------------------
Ipv4-unicast AFI/SAFI
    Received routes               : 3
    Received and active routes    : 0
    Max number of multipaths      : 1, 1
    Multipath can transit multi AS: True
------------------------------------------------------------------------------------
Ipv6-unicast AFI/SAFI
    Received routes               : 0
    Received and active routes    : 0
    Max number of multipaths      : None,None
    Multipath can transit multi AS: None
------------------------------------------------------------------------------------
EVPN-unicast AFI/SAFI
    Received routes               : 0
    Received and active routes    : 0
    Max number of multipaths      : N/A
    Multipath can transit multi AS: N/A
------------------------------------------------------------------------------------
```

///
/// tab | Path
`/network-instance[name=*]/protocols/bgp`
///

## Neighbor

/// tab | CLI

```{.srl .code-scroll-lg}
A:srl-a# show network-instance default protocols bgp neighbor 192.168.10.2 detail
-------------------------------------------------------------------------------------------------
Peer : 192.168.10.2, remote AS: 65003, local AS: 65000, peer-type : ebgp
Type : static
Description : None
Group : eBGP-underlay
Export policies : export-all
Import policies: import-all
Under maintenance: False
Maintenance group:
-------------------------------------------------------------------------------------------------
Admin-state is enable, session-state is established, up for 0d:0h:59m:38s
TCP connection is 192.168.10.1 [179] -> 192.168.10.2 [41511]
TCP-MD5 authentication is disabled
0 messages in input queue, 0 messages in output queue
-------------------------------------------------------------------------------------------------
Last-state was active, last-event was recvOpen, 1 peer-flaps
Last received Notification was Error: None SubError: None
Failure detection: BFD is False, fast-failover is True
-------------------------------------------------------------------------------------------------
Graceful Restart
   Admin State : disable
   Restarts by the peer : None
   Last restart : N/A
   Peer requested restart-time : None
   Stale routes time : None
-------------------------------------------------------------------------------------------------
           Timer                 Configured      Operational                 Next
=============================================================================================
connect-retry                       120              120                      -
keepalive-interval                   30               30                      -
hold-time                            90               90                      -
minimum-advertisement-               5                5                       -
interval
prefix-limit-restart-timer           0                0                       -
-------------------------------------------------------------------------------------------------
Cap Sent:  ROUTE_REFRESH 4-OCTET_ASN MP_BGP GRACEFUL_RESTART
Cap Recv:  ROUTE_REFRESH 4-OCTET_ASN MP_BGP GRACEFUL_RESTART
-------------------------------------------------------------------------------------------------
      Messages                  Sent                  Received                  Last
=============================================================================================
Non Updates                      122                     122
Updates                           3                       4
Malformed updates                 0                       0
Route Refreshes                   0                       0
-------------------------------------------------------------------------------------------------
Ipv4-unicast AFI/SAFI
    End of RIB                     : sent, received
    Received routes                : 3
    Rejected routes                : None
    Active routes                  : None
    Advertised routes              : 3
    Prefix-limit                   : 4294967295 routes, warning at 90, prevent-teardown False
    Default originate              : disabled
    Advertise with IPv6 next-hops  : False
    Peer requested GR helper       : None
    Peer preserved forwarding state: None
-------------------------------------------------------------------------------------------------
Evpn-unicast AFI/SAFI
    End of RIB                     : sent, received
    Received routes                : None
    Rejected routes                : None
    Active routes                  : None
    Advertised routes              : None
    Prefix-limit                   : 4294967295 routes, warning at 90, prevent-teardown False
    Default originate              : disabled
    Advertise with IPv6 next-hops  : N/A
    Peer requested GR helper       : None
    Peer preserved forwarding state: None
-------------------------------------------------------------------------------------------------
```

///
/// tab | Path
`/network-instance[name=*]/protocols/bgp/neighbor[peer-address=*]`
///

## Routes

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

## Neighbor Received Routes

/// tab | CLI

```srl
A:srl-a# show network-instance default protocols bgp neighbor 192.168.10.2 received-routes ipv4
--------------------------------------------------------------------------------------------------------------------------
Peer        : 192.168.10.2, remote AS: 65003, local AS: 65000
Type        : static
Description : None
Group       : eBGP-underlay
--------------------------------------------------------------------------------------------------------------------------
Status codes: u=used, *=valid, >=best, x=stale
Origin codes: i=IGP, e=EGP, ?=incomplete
+-----------------------------------------------------------------------------------------------------------------------+
|    Status        Network        Path-id        Next Hop         MED          LocPref         AsPath         Origin    |
+=======================================================================================================================+
|      *         10.10.10.1/3   0              192.168.10.2        16            100        [65003]              i      |
|                2                                                                                                      |
|      *         192.168.10.0   0              192.168.10.2        -             100        [65003]              i      |
|                /30                                                                                                    |
|      *         192.168.20.0   0              192.168.10.2        -             100        [65003]              i      |
|                /30                                                                                                    |
+-----------------------------------------------------------------------------------------------------------------------+
--------------------------------------------------------------------------------------------------------------------------
3 received BGP routes : 0 used 3 valid
--------------------------------------------------------------------------------------------------------------------------
```

///
/// tab | Path
`/network-instance[name=*]/bgp-rib/ipv4-unicast/rib-in-out/rib-in-pre/routes[prefix=*][neighbor=*][path-id=*]/prefix`
///

## Neighbor Advertised Routes

/// tab | CLI

```srl
A:srl-a# show network-instance default protocols bgp neighbor 192.168.10.2 advertised-routes ipv4
-------------------------------------------------------------------------------------------------------------------------------
Peer        : 192.168.10.2, remote AS: 65003, local AS: 65000
Type        : static
Description : None
Group       : eBGP-underlay
-------------------------------------------------------------------------------------------------------------------------------
Origin codes: i=IGP, e=EGP, ?=incomplete
+-----------------------------------------------------------------------------------------------------------------------------+
|     Network           Path-id          Next Hop             MED             LocPref           AsPath            Origin      |
+=============================================================================================================================+
| 10.10.10.1/32     0                 192.168.10.1             -                100         [65000]                  i        |
| 192.168.10.0/30   0                 192.168.10.1             -                100         [65000]                  i        |
| 192.168.20.0/30   0                 192.168.10.1             -                100         [65000]                  i        |
+-----------------------------------------------------------------------------------------------------------------------------+
-------------------------------------------------------------------------------------------------------------------------------
3 advertised BGP routes
-------------------------------------------------------------------------------------------------------------------------------
```

///
/// tab | Path
`/network-instance[name=*]/bgp-rib/ipv4-unicast/rib-in-out/rib-out-post/routes[prefix=*][neighbor=*][path-id=*]/prefix`
///
