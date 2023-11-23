---
comments: true
title: Troubleshooting LAGs
---

# LAG

## Status

/// tab | CLI

```srl
A:srl-a# show lag
======================================================================================
lag5 is down, reason no-active-links, min links 1
+-----------------+------------+---------------------------+
|   Member Name   | oper-state |     oper-down-reason      |
+=================+============+===========================+
| ethernet-1/2    | down       | port-oper-disabled        |
| ethernet-1/3    | down       | port-oper-disabled        |
+-----------------+------------+---------------------------+
--------------------------------------------------------------------------------------
======================================================================================
Summary
  0 LAG interfaces are up, 1 are down
======================================================================================
```

///
/// tab | Path
`/lag[name=lag5]`
///

## Statistics

/// tab | CLI

```srl
A:srl-a# show lag lag5 detail
======================================================================================
LagInterface: lag5
--------------------------------------------------------------------------------------
  Description    : <None>
  Oper state     : down
  Down reason    : no-active-links
  Min links      : 1
  Aggregate Speed: 0
+--------------+------------+--------------------+-----------------+
| Member Name  | oper-state |  oper-down-reason  | micro-bfd state |
+==============+============+====================+=================+
| ethernet-1/2 | down       | port-oper-disabled | false           |
| ethernet-1/3 | down       | port-oper-disabled | false           |
+--------------+------------+--------------------+-----------------+

--------------------------------------------------------------------------------------
Traffic statistics for lag5
--------------------------------------------------------------------------------------
       counter        Rx   Tx
  Octets              0    0
  Unicast packets     0    0
  Broadcast packets   0    0
  Multicast packets   0    0
  Errored packets     0    0
  FCS error packets   0    N/A
  MAC Pause frames    0    0
  Oversize frames     0    N/A
  Jabber frames       0    N/A
  Fragment frames     0    N/A
  CRC errors          0    N/A
```

```srl
A:srl-a# show lag lag5 member-statistics
======================================================================================
LagInterface: lag5
--------------------------------------------------------------------------------------
  Description: <None>
  Oper state : down
  +-----------------+-----------+-----------+-----------+-----------+-----------+----+--------+
  |     Members     | Rx Octets | Tx Octets |    Rx     |    Tx     | Rx Errors | Tx | Errors |
  |                 |           |           |  Packets  |  Packets  |           |    |        +
+=================+===========+===========+===========+===========+===========+======+========+
  | ethernet-1/2    | 0         | 0         | 0         | 0         | 0         | 0  |        |
  | ethernet-1/3    | 0         | 0         | 0         | 0         | 0         | 0  |        |
  +-----------------+-----------+-----------+-----------+-----------+-----------+----+--------+
```

///
/// tab | Path
`/lag[name=lag5]/statistics`
///
