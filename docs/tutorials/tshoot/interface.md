---
comments: true
title: Troubleshooting Interfaces
---

# Interface

## Interface Summary

Display summary of interfaces that are UP
/// tab | `show interface`

```srl
A:srl-a# show interface
=========================================================
ethernet-1/1 is up, speed 25G, type None
  ethernet-1/1.10 is up
    Network-instance:
    Encapsulation   : vlan-id 10
    Type            : routed
    IPv4 addr    : 192.168.10.1/30 (static, None)
  ethernet-1/1.20 is up
    Network-instance:
    Encapsulation   : vlan-id 20
    Type            : routed
    IPv4 addr    : 192.168.20.1/30 (static, None)
--------------------------------------------------------

Display summary of all interfaces
B:ixr137# show interface brief                                                               
+---------------------+----------------+----------------+----------------+-----------+
|        Port         |  Admin State   |   Oper State   |     Speed      |      Type      
+=====================+================+================+================+===========+
| ethernet-1/1        | disable        | down           |                |                
| ethernet-1/2        | disable        | down           |                |                
| ethernet-1/3        | disable        | down           |                |                
| ethernet-1/4        | enable         | up             | 100G           | 100G CWDM4 
| ethernet-1/5        | enable         | up             | 100G           | 100G CWDM4 
| ethernet-1/6        | disable        | down           |                |                
| ethernet-1/7        | disable        | down           |                |                
```

///
/// tab | `show interface all`

```srl
A:srl-a# show interface all
======================================================================================
ethernet-1/1 is up, speed 25G, type None
  ethernet-1/1.10 is up
    Network-instance:
    Encapsulation   : vlan-id 10
    Type            : routed
    IPv4 addr    : 192.168.10.1/30 (static, None)
  ethernet-1/1.20 is up
    Network-instance:
    Encapsulation   : vlan-id 20
    Type            : routed
    IPv4 addr    : 192.168.20.1/30 (static, None)
--------------------------------------------------------------------------------------
ethernet-1/2 is down, reason port-admin-disabled
--------------------------------------------------------------------------------------
ethernet-1/3 is down, reason port-admin-disabled
--------------------------------------------------------------------------------------
```

///
/// tab | Path
`/interface[name=*]`
///

## Interface Details

```srl
A:srl-a# show interface ethernet-1/1 detail
======================================================================================

Interface: ethernet-1/1
--------------------------------------------------------------------------------------

Description         : <None>
  Oper state          : up
  Down reason         : N/A
  Last change         : 14m59s ago, 1 flaps since last clear
  Speed               : 25G
  Flow control        : Rx is disabled
  Loopback mode       : false
  MTU                 : 9232
  VLAN tagging        : true
  VLAN TPID           : TPID_0X8100
  Queues              : 8 output queues supported, 1 used since the last clear
  Last stats clear    : 14m59s ago
  Breakout mode       : false
--------------------------------------------------------------------------------------

L2CP transparency rule for ethernet-1/1
--------------------------------------------------------------------------------------

Lldp              : trap-to-cpu-untagged
  Lacp              : trap-to-cpu-untagged
  xStp              : drop-tagged-and-untagged
  Dot1x             : drop-tagged-and-untagged
  Ptp               : drop-tagged-and-untagged
  Non-specified l2cp: false
--------------------------------------------------------------------------------------

Traffic statistics for ethernet-1/1
--------------------------------------------------------------------------------------

       counter         Rx     Tx
  Octets              5326   5312
  Unicast packets     0      0
  Broadcast packets   0      0
  Multicast packets   33     32
  Errored packets     0      0
  FCS error packets   0      N/A
  MAC pause frames    0      0
  Oversize frames     0      N/A
  Jabber frames       0      N/A
  Fragment frames     0      N/A
  CRC errors          0      N/A
```

## Management Interface

/// tab | CLI

```srl
A:srl-a# show interface mgmt0
======================================================================================

mgmt0 is up, speed 1G, type None
  mgmt0.0 is up
    Network-instance: mgmt
    Encapsulation   : null
    Type            : None
    IPv4 addr    : 172.20.20.3/24 (dhcp, preferred)
    IPv6 addr    : 2001:172:20:20::3/64 (dhcp, preferred)
    IPv6 addr    : fe80::42:acff:fe14:1403/64 (link-layer, preferred)
--------------------------------------------------------------------------------------
```

///
/// tab | Path
`/interface[name=mgmt0]`
///

## Interface Configuration

```srl
A:srl-a# info interface ethernet-1/1
    interface ethernet-1/1 {
        admin-state enable
        vlan-tagging true
        subinterface 10 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 192.168.10.1/30 {
                }
            }
            vlan {
                encap {
                    single-tagged {
                        vlan-id 10
                    }
                }
            }
        }
        subinterface 20 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 192.168.20.1/30 {
                }
            }
            vlan {
                encap {
                    single-tagged {
                        vlan-id 20
                    }
                }
```

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
