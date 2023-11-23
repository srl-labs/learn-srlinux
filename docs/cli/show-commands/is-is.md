---
comments: true
title: Troubleshooting IS-IS
---

# IS-IS

## Summary

/// tab | CLI

```{.srl .code-scroll-lg}
A:srl-a# show network-instance default protocols isis summary
--------------------------------------------------------------------------------------
Network instance "default", isis instance "isis-1" is enable and up
Level Capability : L2
Export policy    : None
--------------------------------------------------------------------------------------
System-id : 0100.1010.0001
NET       : [ 49.0000.0100.1010.0001.00 ]
Area-id   : [ 49.0000 ]
--------------------------------------------------------------------------------------
IPv4 routing is enable
IPv6 routing is enable using None
Max ECMP path : 1
--------------------------------------------------------------------------------------
Overload
Current Status : not in overload
--------------------------------------------------------------------------------------
Metric
Reference bandwidth: NA
L1 metric style: None
L2 metric style: wide
--------------------------------------------------------------------------------------
Graceful Restart
Helper Mode    : disabled
Current Status : not helping any neighbors
--------------------------------------------------------------------------------------
Timers
LSP Lifetime                : 1200
LSP Refresh                 : 600
SPF initial wait            : 1000
SPF second wait             : 1000
SPF max wait                : 10000
LSP generation initial wait : 10
LSP generation second wait  : 1000
LSP generation max wait     : 5000
--------------------------------------------------------------------------------------
Route Preference
L1 internal : None
L1 external : None
L2 internal : 18
L2 external : 165
--------------------------------------------------------------------------------------
L1->L2 Summary Addresses Not configured
--------------------------------------------------------------------------------------
Instance Statistics
SPF run            : 2
Last SPF           : 2023-04-10T19:24:24.100Z
Partial SPF run    : 0
Last Partial SPF   : None
--------------------------------------------------------------------------------------
PDU Statistics
+----------+----------+-----------+---------+------+
| pdu-name | received | processed | dropped | sent |
+==========+==========+===========+=========+======+
| LSP      | 0        | 0         | 0       | 0    |
| IIH      | 9        | 0         | 9       | 9    |
| CSNP     | 0        | 0         | 0       | 0    |
| PSNP     | 0        | 0         | 0       | 0    |
+----------+----------+-----------+---------+------+
```

///
/// tab | Path
`/network-instance[name=*]/protocols/isis`
///

## Adjacency

/// tab | CLI

```srl
A:srl-a# show network-instance default protocols isis adjacency
---------------------------------------------------------------------------------
Network Instance: default
Instance        : isis-1
+----------+----------+---------+---------+---------+-------+---------+---------+
| Interfac | Neighbor | Adjacen |   Ip    |  Ipv6   | State | Last tr | Remaini |
|  e Name  |  System  |   cy    | Address | Address |       | ansitio | ng hold |
|          |    Id    |  Level  |         |         |       |    n    |  time   |
+==========+==========+=========+=========+=========+=======+=========+=========+
| ethernet | 0100.101 | L2      | 192.168 | ::      | up    | 2023-04 | 27      |
| -1/1.10  | 0.0002   |         | .10.2   |         |       | -10T19: |         |
|          |          |         |         |         |       | 29:56.3 |         |
|          |          |         |         |         |       | 00Z     |         |
+----------+----------+---------+---------+---------+-------+---------+---------+
Adjacency Count: 1
---------------------------------------------------------------------------------
```

///
/// tab | Path
`/network-instance[name=*]/protocols/isis/instance[name=*]/interface[interface-name=*]`
///

## Database

/// tab | CLI

```srl
A:srl-a# show network-instance default protocols isis database
---------------------------------------------------------------------------------

Network Instance: default
Instance        : isis-1
+--------------+------------------+----------+----------+----------+------------+
| Level Number |      Lsp Id      | Sequence | Checksum | Lifetime | Attributes |
+==============+==================+==========+==========+==========+============+
| 2            | 0100.1010.0001.0 | 0x3      | 0x66b7   | 924      | L1 L2      |
|              | 0-00             |          |          |          |            |
| 2            | 0100.1010.0002.0 | 0x3      | 0x62b9   | 924      | L1 L2      |
|              | 0-00             |          |          |          |            |
+--------------+------------------+----------+----------+----------+------------+
LSP Count: 2
---------------------------------------------------------------------------------
```

///
/// tab | Path
`/network-instance[name=*]/protocols/isis/instance[name=*]/level-database[level-number=*][lsp-id=*]`
///
