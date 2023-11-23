---
comments: true
title: Show commands for ACL
---

# CPM

## CPM Filter Status

```srl
A:srl-a# show acl cpm-filter ipv4-filter
=============================================================================================
Filter     : CPM IPv4-filter
Entry-stats: yes
Entries    : 38
---------------------------------------------------------------------------------------------
Entry 10
  Match          : protocol=icmp, any(*)->any(*)
  Action         : accept
  Matched Packets: 0
  Last Match     : never
  TCAM Entries   : 12
Entry 20
  Match          : protocol=icmp, any(*)->any(*)
  Action         : accept
  Matched Packets: 0
  Last Match     : never
  TCAM Entries   : 2
Entry 30
  Match          : protocol=icmp, any(*)->any(*)
  Action         : accept
  Matched Packets: 0
  Last Match     : never
  TCAM Entries   : 2
```
