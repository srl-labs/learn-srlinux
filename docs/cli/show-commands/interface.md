---
comments: true
title: Troubleshooting Interfaces
---

# Interface

## Interface Summary

Display summary of interfaces that are UP
/// tab | `show interface`

```srl
========================================================================================================================
ethernet-1/1 is up, speed 25G, type None
  ethernet-1/1.10 is up
    Network-instances:
    Encapsulation   : vlan-id 10
    Type            : routed
    IPv4 addr    : 192.168.10.1/30 (static, None)
  ethernet-1/1.20 is up
    Network-instances:
    Encapsulation   : vlan-id 20
    Type            : routed
    IPv4 addr    : 192.168.20.1/30 (static, None)
------------------------------------------------------------------------------------------------------------------------
lo0 is up, speed None, type None
  lo0.0 is up
    Network-instances:
    Encapsulation   : null
    Type            : None
    IPv4 addr    : 10.10.10.1/32 (static, None)
------------------------------------------------------------------------------------------------------------------------
mgmt0 is up, speed 1G, type None
  mgmt0.0 is up
    Network-instances:
      * Name: mgmt
    Encapsulation   : null
    Type            : None
    IPv4 addr    : 172.20.20.3/24 (dhcp, preferred)
    IPv6 addr    : 2001:172:20:20::3/64 (dhcp, preferred)
    IPv6 addr    : fe80::42:acff:fe14:1403/64 (link-layer, preferred)
------------------------------------------------------------------------------------------------------------------------
========================================================================================================================
Summary
  1 loopback interfaces configured
  1 ethernet interfaces are up
  1 management interfaces are up
  4 subinterfaces are up
========================================================================================================================
```

///
/// tab | `show interface brief`

Display summary of all interfaces

```{.srl .code-scroll-lg}
B:ixr-d2# show interface brief                                                               
+---------------------+-----------------------+-----------------------+-----------------------+-----------------------+
|        Port         |      Admin State      |      Oper State       |         Speed         |         Type          |
+=====================+=======================+=======================+=======================+=======================+
| ethernet-1/1        | enable                | up                    | 25G                   |                       |
| ethernet-1/2        | enable                | down                  | 25G                   |                       |
| ethernet-1/3        | enable                | down                  | 25G                   |                       |
| ethernet-1/4        | disable               | down                  | 25G                   |                       |
| ethernet-1/5        | disable               | down                  | 25G                   |                       |
| ethernet-1/6        | disable               | down                  | 25G                   |                       |
| ethernet-1/7        | disable               | down                  | 25G                   |                       |
| ethernet-1/8        | disable               | down                  | 25G                   |                       |
| ethernet-1/9        | disable               | down                  | 25G                   |                       |
| ethernet-1/10       | disable               | down                  | 25G                   |                       |
| ethernet-1/11       | disable               | down                  | 25G                   |                       |
| ethernet-1/12       | disable               | down                  | 25G                   |                       |
| ethernet-1/13       | disable               | down                  | 25G                   |                       |
| ethernet-1/14       | disable               | down                  | 25G                   |                       |
| ethernet-1/15       | disable               | down                  | 25G                   |                       |
| ethernet-1/16       | disable               | down                  | 25G                   |                       |
| ethernet-1/17       | disable               | down                  | 25G                   |                       |
| ethernet-1/18       | disable               | down                  | 25G                   |                       |
| ethernet-1/19       | disable               | down                  | 25G                   |                       |
| ethernet-1/20       | disable               | down                  | 25G                   |                       |
| ethernet-1/21       | disable               | down                  | 25G                   |                       |
| ethernet-1/22       | disable               | down                  | 25G                   |                       |
| ethernet-1/23       | disable               | down                  | 25G                   |                       |
| ethernet-1/24       | disable               | down                  | 25G                   |                       |
| ethernet-1/25       | disable               | down                  | 25G                   |                       |
| ethernet-1/26       | disable               | down                  | 25G                   |                       |
| ethernet-1/27       | disable               | down                  | 25G                   |                       |
| ethernet-1/28       | disable               | down                  | 25G                   |                       |
| ethernet-1/29       | disable               | down                  | 25G                   |                       |
| ethernet-1/30       | disable               | down                  | 25G                   |                       |
| ethernet-1/31       | disable               | down                  | 25G                   |                       |
| ethernet-1/32       | disable               | down                  | 25G                   |                       |
| ethernet-1/33       | disable               | down                  | 25G                   |                       |
| ethernet-1/34       | disable               | down                  | 25G                   |                       |
| ethernet-1/35       | disable               | down                  | 25G                   |                       |
| ethernet-1/36       | disable               | down                  | 25G                   |                       |
| ethernet-1/37       | disable               | down                  | 25G                   |                       |
| ethernet-1/38       | disable               | down                  | 25G                   |                       |
| ethernet-1/39       | disable               | down                  | 25G                   |                       |
| ethernet-1/40       | disable               | down                  | 25G                   |                       |
| ethernet-1/41       | disable               | down                  | 25G                   |                       |
| ethernet-1/42       | disable               | down                  | 25G                   |                       |
| ethernet-1/43       | disable               | down                  | 25G                   |                       |
| ethernet-1/44       | disable               | down                  | 25G                   |                       |
| ethernet-1/45       | disable               | down                  | 25G                   |                       |
| ethernet-1/46       | disable               | down                  | 25G                   |                       |
| ethernet-1/47       | disable               | down                  | 25G                   |                       |
| ethernet-1/48       | disable               | down                  | 25G                   |                       |
| ethernet-1/49       | disable               | down                  | 100G                  |                       |
| ethernet-1/50       | disable               | down                  | 100G                  |                       |
| ethernet-1/51       | disable               | down                  | 100G                  |                       |
| ethernet-1/52       | disable               | down                  | 100G                  |                       |
| ethernet-1/53       | disable               | down                  | 100G                  |                       |
| ethernet-1/54       | disable               | down                  | 100G                  |                       |
| ethernet-1/55       | disable               | down                  | 100G                  |                       |
| ethernet-1/56       | disable               | down                  | 100G                  |                       |
| lag5                | enable                | down                  |                       |                       |
| lo0                 | enable                | up                    |                       |                       |
| mgmt0               | enable                | up                    | 1G                    |                       |
+---------------------+-----------------------+-----------------------+-----------------------+-----------------------+  
```

///
/// tab | `show interface all`

```{.srl .code-scroll-lg}
A:ixr-d2# show interface all
========================================================================================================================
ethernet-1/1 is up, speed 25G, type None
  ethernet-1/1.10 is up
    Network-instances:
    Encapsulation   : vlan-id 10
    Type            : routed
    IPv4 addr    : 192.168.10.1/30 (static, None)
  ethernet-1/1.20 is up
    Network-instances:
    Encapsulation   : vlan-id 20
    Type            : routed
    IPv4 addr    : 192.168.20.1/30 (static, None)
------------------------------------------------------------------------------------------------------------------------
ethernet-1/2 is down, reason lower-layer-down
------------------------------------------------------------------------------------------------------------------------
ethernet-1/3 is down, reason lower-layer-down
------------------------------------------------------------------------------------------------------------------------
ethernet-1/4 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/5 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/6 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/7 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/8 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/9 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/10 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/11 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/12 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/13 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/14 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/15 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/16 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/17 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/18 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/19 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/20 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/21 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/22 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/23 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/24 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/25 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/26 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/27 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/28 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/29 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/30 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/31 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/32 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/33 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/34 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/35 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/36 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/37 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/38 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/39 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/40 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/41 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/42 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/43 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/44 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/45 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/46 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/47 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/48 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/49 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/50 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/51 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/52 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/53 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/54 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/55 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
ethernet-1/56 is down, reason port-admin-disabled
------------------------------------------------------------------------------------------------------------------------
lag5 is down, reason no-active-links
  lag5.0 is down, reason no-ip-config
    Network-instances:
    Encapsulation   : null
    Type            : routed
    IPv4 addr    : 172.16.10.1/30 (static, None)
------------------------------------------------------------------------------------------------------------------------
lo0 is up, speed None, type None
  lo0.0 is up
    Network-instances:
    Encapsulation   : null
    Type            : None
    IPv4 addr    : 10.10.10.1/32 (static, None)
------------------------------------------------------------------------------------------------------------------------
mgmt0 is up, speed 1G, type None
  mgmt0.0 is up
    Network-instances:
      * Name: mgmt
    Encapsulation   : null
    Type            : None
    IPv4 addr    : 172.20.20.3/24 (dhcp, preferred)
    IPv6 addr    : 2001:172:20:20::3/64 (dhcp, preferred)
    IPv6 addr    : fe80::42:acff:fe14:1403/64 (link-layer, preferred)
------------------------------------------------------------------------------------------------------------------------
========================================================================================================================
Summary
  1 loopback interfaces configured
  1 ethernet interfaces are up, 56 are down
  1 management interfaces are up, 0 are down
  4 subinterfaces are up, 1 are down
========================================================================================================================
```

///
/// tab | Path
`/interface[name=*]`
///

## Interface Details

```{.srl .code-scroll-lg}
A:srl-a# show interface ethernet-1/1 detail
========================================================================================================================
Interface: ethernet-1/1
------------------------------------------------------------------------------------------------------------------------
  Description         : <None>
  Oper state          : up
  Down reason         : N/A
  Last change         : 20h59m20s ago, 2 flaps since last clear
  Speed               : 25G
  Flow control        : Rx is disabled
  Loopback mode       : false
  MTU                 : 9232
  VLAN tagging        : true
  VLAN TPID           : TPID_0X8100
  Queues              : 8 output queues supported, 1 used since the last clear
  Last stats clear    : 7m58s ago
  Breakout mode       : false
------------------------------------------------------------------------------------------------------------------------
L2CP transparency rule for ethernet-1/1
------------------------------------------------------------------------------------------------------------------------
  Lldp              : trap-to-cpu-untagged
  Lacp              : trap-to-cpu-untagged
  xStp              : drop-tagged-and-untagged
  Dot1x             : drop-tagged-and-untagged
  Ptp               : drop-tagged-and-untagged
  Non-specified l2cp: false
------------------------------------------------------------------------------------------------------------------------
Traffic statistics for ethernet-1/1
------------------------------------------------------------------------------------------------------------------------
       counter         Rx     Tx
  Octets              3019   3006
  Unicast packets     0      0
  Broadcast packets   0      0
  Multicast packets   19     18
  Errored packets     0      0
  FCS error packets   0      N/A
  MAC pause frames    0      0
  Oversize frames     0      N/A
  Jabber frames       0      N/A
  Fragment frames     0      N/A
  CRC errors          0      N/A
------------------------------------------------------------------------------------------------------------------------
Traffic rate statistics for ethernet-1/1
------------------------------------------------------------------------------------------------------------------------
    units     Rx   Tx
  kbps rate   0    0
------------------------------------------------------------------------------------------------------------------------
Frame length statistics for ethernet-1/1
------------------------------------------------------------------------------------------------------------------------
  Frame length(Octets)   Rx   Tx
  64 bytes               0    0
  65-127 bytes           0    0
  128-255 bytes          0    0
  256-511 bytes          0    0
  512-1023 bytes         0    0
  1024-1518 bytes        0    0
  1519+ bytes            0    0
------------------------------------------------------------------------------------------------------------------------
Transceiver detail for ethernet-1/1
------------------------------------------------------------------------------------------------------------------------
  Status          : Transceiver state is down
  Oper down reason: not-present
========================================================================================================================
  Subinterface: ethernet-1/1.10
------------------------------------------------------------------------------------------------------------------------
  Description           : <None>
  Network-instance      : None
  Type                  : routed
  Oper state            : up
  Down reason           : N/A
  Last change           : 6m47s ago
  Encapsulation         : vlan-id 10
  IP MTU                : 1500
  Last stats clear      : never
  MAC duplication action: -
  IPv4 addr    : 192.168.10.1/30 (static, None)
------------------------------------------------------------------------------------------------------------------------
ARP/ND summary for ethernet-1/1.10
------------------------------------------------------------------------------------------------------------------------
  IPv4 ARP entries : 0 static, 0 dynamic
  IPv6 ND  entries : 0 static, 0 dynamic
------------------------------------------------------------------------------------------------------------------------
ACL filters applied to ethernet-1/1.10
------------------------------------------------------------------------------------------------------------------------
     Summary       In    Out
  IPv4 ACL Name   none   none
  IPv6 ACL Name   none   none
------------------------------------------------------------------------------------------------------------------------
QOS Policies applied to ethernet-1/1.10
------------------------------------------------------------------------------------------------------------------------
           Summary               In      Out
  DSCP classifier              default      -
  DSCP rewrite                       -   none
  IPv4 Multifield Classifier      none      -
  IPv6 Multifield Classifier      none      -
  Dot1p classifier             default      -
  Dot1p rewrite                      -   none
  Policer Template                none      -
------------------------------------------------------------------------------------------------------------------------
Traffic statistics for ethernet-1/1.10
------------------------------------------------------------------------------------------------------------------------
     Statistics       Rx   Tx
  Packets             0    0
  Octets              0    0
  Discarded packets   0    0
  Forwarded packets   0    0
  Forwarded octets    0    0
  CPM packets         -    0
  CPM octets          -    0
------------------------------------------------------------------------------------------------------------------------
IPv4 Traffic statistics for ethernet-1/1.10
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
IPv6 Traffic statistics for ethernet-1/1.10
------------------------------------------------------------------------------------------------------------------------
========================================================================================================================
  Subinterface: ethernet-1/1.20
------------------------------------------------------------------------------------------------------------------------
  Description           : <None>
  Network-instance      : None
  Type                  : routed
  Oper state            : up
  Down reason           : N/A
  Last change           : 6m47s ago
  Encapsulation         : vlan-id 20
  IP MTU                : 1500
  Last stats clear      : never
  MAC duplication action: -
  IPv4 addr    : 192.168.20.1/30 (static, None)
------------------------------------------------------------------------------------------------------------------------
ARP/ND summary for ethernet-1/1.20
------------------------------------------------------------------------------------------------------------------------
  IPv4 ARP entries : 0 static, 0 dynamic
  IPv6 ND  entries : 0 static, 0 dynamic
------------------------------------------------------------------------------------------------------------------------
ACL filters applied to ethernet-1/1.20
------------------------------------------------------------------------------------------------------------------------
     Summary       In    Out
  IPv4 ACL Name   none   none
  IPv6 ACL Name   none   none
------------------------------------------------------------------------------------------------------------------------
QOS Policies applied to ethernet-1/1.20
------------------------------------------------------------------------------------------------------------------------
           Summary               In      Out
  DSCP classifier              default      -
  DSCP rewrite                       -   none
  IPv4 Multifield Classifier      none      -
  IPv6 Multifield Classifier      none      -
  Dot1p classifier             default      -
  Dot1p rewrite                      -   none
  Policer Template                none      -
------------------------------------------------------------------------------------------------------------------------
Traffic statistics for ethernet-1/1.20
------------------------------------------------------------------------------------------------------------------------
     Statistics       Rx   Tx
  Packets             0    0
  Octets              0    0
  Discarded packets   0    0
  Forwarded packets   0    0
  Forwarded octets    0    0
  CPM packets         -    0
  CPM octets          -    0
------------------------------------------------------------------------------------------------------------------------
IPv4 Traffic statistics for ethernet-1/1.20
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
IPv6 Traffic statistics for ethernet-1/1.20
------------------------------------------------------------------------------------------------------------------------
========================================================================================================================
========================================================================================================================
```

## Management Interface

/// tab | CLI

```srl
A:srl-a# show interface mgmt0
========================================================================================================================
mgmt0 is up, speed 1G, type None
  mgmt0.0 is up
    Network-instances:
      * Name: mgmt
    Encapsulation   : null
    Type            : None
    IPv4 addr    : 172.20.20.3/24 (dhcp, preferred)
    IPv6 addr    : 2001:172:20:20::3/64 (dhcp, preferred)
    IPv6 addr    : fe80::42:acff:fe14:1403/64 (link-layer, preferred)
------------------------------------------------------------------------------------------------------------------------
========================================================================================================================
```

///
/// tab | Path
`/interface[name=mgmt0]`
///

## Optics Light Level

/// tab | CLI

```srl
B:ixr137# show interface ethernet-1/4 detail
======================================================================================

Interface: ethernet-1/4
--------------------------------------------------------------------------------------

Description     : <None>
  Oper state      : up
<snip>
--------------------------------------------------------------------------------------

Transceiver detail for ethernet-1/4
--------------------------------------------------------------------------------------

Status         : Transceiver is present and operational
  Form factor    : QSFP28
  Channels used  : 4
  Connector type : LC
  Vendor         : ColorChip ltd
  Vendor part    : C100Q020CWDM403B
  PMD type       : 100G CWDM4 MSA with FEC
  Fault condition: false
  Temperature    : 38
  Voltage        : 3.2970
--------------------------------------------------------------------------------------

Transceiver channel detail for ethernet-1/4
--------------------------------------------------------------------------------------

Channel No   Rx Power (dBm)   Tx Power (dBm)   Laser Bias current (mA)
  1            0.70             -1.63            30.694
  2            0.45             -2.46            29.344
  3            0.35             -1.45            34.678
  4            -0.60            -1.94            31.662
======================================================================================
```

///
/// tab | Path
`/interface[name=*]/transceiver`
///

## Interface Errors

/// tab | CLI

```srl
B:ixr137# show interface ethernet-1/4 detail
======================================================================================

Interface: ethernet-1/4
--------------------------------------------------------------------------------------

Description     : <None>
  Oper state      : up
<snip>
Traffic statistics for ethernet-1/4
--------------------------------------------------------------------------------------

       counter        Rx   Tx 
  Octets              0    0  
  Unicast packets     0    0  
  Broadcast packets   0    0  
  Multicast packets   0    0  
  Errored packets     0    0  
  FCS error packets   0    N/A
  MAC pause frames    0    0  
  Oversize frames     0    N/A
  Jabber frames       0    N/A
  Fragment frames     0    N/A
  CRC errors          0    N/A
```

///
/// tab | Path
`/interface[name=*]/statistics`
///
