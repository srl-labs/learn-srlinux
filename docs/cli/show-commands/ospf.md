---
comments: true
title: Troubleshooting OSPF
---

# OSPF

## Status

/// tab | CLI

```srl
A:srl-a# show network-instance default protocols ospf status
======================================================================================
Net-Inst default OSPFv2 Instance default Status
======================================================================================
OSPF Cfg Router Id        : 10.10.10.1
OSPF Oper Router Id       : 10.10.10.1
OSPF Version              : 2
OSPF Admin Status         : enable
OSPF Oper Status          : enable
Last Disable Reason       : None
Graceful Restart          : false
GR Helper Mode            : false
GR Strict LSA Checking    : false
Preference                : 10
External Preference       : 150
Backbone Router           : true
Area Border Router        : false
AS Border Router          : false
In Overload State         : false
In External Overflow State: false
Exit Overflow Interval    : None
Last Overflow Entered     : Never
Last Overflow Exit        : Never
External LSA Limit        : None
Reference Bandwidth       : 400000000
Init SPF Delay            : 1000
Sec SPF Delay             : 1000
Max SPF Delay             : 10000
Min LS Arrival Interval   : 1000
Init LSA Gen Delay        : 5000
Sec LSA Gen Delay         : 5000
Max LSA Gen Delay         : 5000
LSA accumulate            : 1000
Redistribute delay        : 1000
Incremental SPF wait      : 1000
Last Ext SPF Run          : 2023-04-10T20:07:53.100Z
Ext LSA Cksum Sum         : 0x0
OSPF Last Enabled         : 2023-04-10T20:02:35.800Z
Export Policies           : None
Export Limit              : None
Export Limit Log Percent  : None
Total Exp Routes          : 0
======================================================================================
```

///
/// tab | Path
`/network-instance[name=*]/protocols/ospf`
///

## Neighbor

/// tab | CLI

```srl
A:srl-a# show network-instance default protocols ospf neighbor
======================================================================================

Net-Inst default OSPFv2 Instance default Neighbors
======================================================================================

+-------------------------------------------------------------------------------------
| Interface-Name         Rtr Id            State        Pri   RetxQ    Time Before Dead |
+=====================================================================================
| ethernet-1/1.20        10.10.10.2        full         1     0        36
+-------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------

No. of Neighbors: 1
======================================================================================
```

///
/// tab | Path
`/network-instance[name=*]/protocols/ospf/instance[name=*]/area[area-id=*]/interface[interface-name=*]`
///

## Database

/// tab | CLI

```srl
A:srl-a# show network-instance default protocols ospf database
======================================================================================

Net-Inst default OSPFv2 Instance default Link State Database (type: All)
======================================================================================

--------------------------------------------------------------------------------------

AS Database
--------------------------------------------------------------------------------------

+------------------------------------------------------------+
| Type   Link State Id   Adv Rtr Id   Sequence   Age   Cksum |
+============================================================+
+------------------------------------------------------------+
No. of AS LSAs: 0
--------------------------------------------------------------------------------------

Area Database
--------------------------------------------------------------------------------------

+-------------------------------------------------------------------------------+
|    Type      Area Id   Link State Id   Adv Rtr Id    Sequence    Age   Cksum  |
+===============================================================================+
| router-lsa   0.0.0.0   10.10.10.1      10.10.10.1   0x80000006   206   0xeaae |
| router-lsa   0.0.0.0   10.10.10.2      10.10.10.2   0x80000004   310   0xecab |
+-------------------------------------------------------------------------------+
No. of Area LSAs: 2
--------------------------------------------------------------------------------------

Link-local Database
--------------------------------------------------------------------------------------

+----------------------------------------------------------------------------------+
| Type   Area Id   Interface   Link State Id   Adv Rtr Id   Sequence   Age   Cksum |
+==================================================================================+
+----------------------------------------------------------------------------------+
No. of Link-local LSAs: 0
--------------------------------------------------------------------------------------

Total No. of LSAs: 2
--------------------------------------------------------------------------------------

======================================================================================
```

///
/// tab | Path
`/network-instance[name=*]/protocols/ospf/instance[name=*]/lsdb`
///

## Statistics

/// tab | CLI

```srl
A:srl-a# show network-instance default protocols ospf statistics
======================================================================================

Net-Inst default OSPFv2 Instance default Statistics
======================================================================================

Rx Packets         : 50
Tx Packets         : 71
Rx Hellos          : 42
Rx DBDs            : 2
Rx LSRs            : 1
Rx LSUs            : 2
Rx LS Acks         : 3
Tx Hellos          : 62
Tx DBDs            : 3
Tx LSRs            : 1
Tx LSUs            : 4
Tx LS Acks         : 1
New LSAs Recvd     : 2
New LSAs Orig      : 2
Ext LSAs Count     : 0
No of Areas        : 1
Total SPF Runs     : 5
Ext SPF Runs       : 0
Retransmits        : 0
Discards           : 0
Bad Networks       : 0
Bad Areas          : 0
Bad Dest Addrs     : 0
Bad Auth Types     : 0
Auth Failures      : 0
Bad Neighbors      : 0
Bad Pkt Types      : 0
Bad Lengths        : 0
Bad Hello Int.     : 0
Bad Dead Int.      : 0
Bad Options        : 0
Bad Versions       : 0
Bad Checksums      : 0
Failed SPF Attempts: 0
======================================================================================
```

///
/// tab | Path
`/network-instance[name=*]/protocols/ospf/instance[name=*]`
///
