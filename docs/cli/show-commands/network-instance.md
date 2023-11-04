---
comments: true
title: Troubleshooting Network Instance
---

# Network Instance

## Network Instance Details

/// tab | CLI

Summary for all Network instances

```srl
A:srl-a# show network-instance summary
+--------------+--------------+--------------+--------------+--------------+------------+
|     Name     |     Type     | Admin state  |  Oper state  |  Router id   |Description |
+==============+==============+==============+==============+==============+============+
| default      | default      | enable       | up           | 10.10.10.1   |            |
| mgmt         | ip-vrf       | enable       | up           |              |Management  |
|              |              |              |              |              | network    |
|              |              |              |              |              | instance   |
+--------------+--------------+--------------+--------------+--------------+------------+
```

List all Interfaces in a Network Instance

```srl
A:srl-a# show network-instance default interfaces
====================================================================================
Net instance    : default
Interface       : ethernet-1/1.10
Type            : routed
Oper state      : up
Ip mtu          : 1500
  Prefix                     Origin                     Status
  ==============================================================================
  192.168.10.1/30            static                     preferred, primary
====================================================================================
Net instance    : default
Interface       : ethernet-1/1.20
Type            : routed
Oper state      : up
Ip mtu          : 1500
  Prefix                     Origin                     Status
  ==============================================================================
  192.168.20.1/30            static                     preferred, primary
====================================================================================
Net instance    : default
Interface       : lo0.0
Oper state      : up
  Prefix                     Origin                     Status
  ==============================================================================
  10.10.10.1/32              static                     preferred, primary
====================================================================================
```

///
/// tab | Path
`/network-instance[name=*]`
///

## Route Table

/// tab | CLI

From within the context of a network instance, the below command can be issued to see a summary of the route table. There are also options to see the route table of that instance.

```srl
--{ + running }--[ ]--
A:srl-a# show network-instance default route-table summary
---------------------------------------------------------------------------------

IPv4 Route Summary
---------------------------------------------------------------------------------

Name      Protocol   Active Routes
default   host       5
default   local      2
---------------------------------------------------------------------------------

IPv4 Active routes          : 7
IPv4 Active routes with ECMP: 0
IPV4 Resilient hash routes  : 0
IPv4 Failed routes          : 0
IPv4 Total routes           : 7
---------------------------------------------------------------------------------

IPv6 Route Summary
---------------------------------------------------------------------------------

Name      Protocol   Active Routes
default   -          0
---------------------------------------------------------------------------------

IPv6 Active routes          : 0
IPv6 Active routes with ECMP: 0
IPV6 Resilient hash routes  : 0
IPv6 Failed routes          : 0
IPv6 Total routes           : 0
---------------------------------------------------------------------------------
```

///
/// tab | Path
`/network-instance[name=*]/route-table`
///

## MAC Table

/// tab | CLI

```srl
--{ + running }--[ ]--
A:srl-a# show network-instance mac-vrf-1 bridge-table mac-table all
---------------------------------------------------------------------------------

Mac-table of network instance mac-vrf-1
---------------------------------------------------------------------------------

+----------+----------+----------+----------+----------+----------+----------+
| Address  | Destinat |   Dest   |   Type   |  Active  |  Aging   |   Last   |
|          |   ion    |  Index   |          |          |          |  Update  |
+==========+==========+==========+==========+==========+==========+==========+
| 1A:EA:00 | irb      | 0        | irb-inte | true     | N/A      | 2023-03- |
| :FF:00:4 |          |          | rface    |          |          | 02T19:03 |
| 2        |          |          |          |          |          | :55.000Z |
+----------+----------+----------+----------+----------+----------+----------+
Total Irb Macs                 :    1 Total    1 Active
Total Static Macs              :    0 Total    0 Active
Total Duplicate Macs           :    0 Total    0 Active
Total Learnt Macs              :    0 Total    0 Active
Total Evpn Macs                :    0 Total    0 Active
Total Evpn static Macs         :    0 Total    0 Active
Total Irb anycast Macs         :    0 Total    0 Active
Total Proxy Antispoof Macs     :    0 Total    0 Active
Total Reserved Macs            :    0 Total    0 Active
Total Eth-cfm Macs             :    0 Total    0 Active
```

///
/// tab | Path

* `/network-instance[name=*]/bridge-table/mac-table`
* `/network-instance[name=*]/bridge-table/statistics/`
///
