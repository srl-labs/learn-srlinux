---
comments: true
title: Show commands for ACL
---

# ACL

## Status

```{.srl .code-scroll-lg}
A:srl-a# show acl summary
--------------------------------------------------------------------------------------
CPM Filter ACLs
--------------------------------------------------------------------------------------
ipv4-entries: 38
ipv6-entries: 39
mac-entries : 0
--------------------------------------------------------------------------------------
Capture Filter ACLs
--------------------------------------------------------------------------------------
ipv4-entries: 0
ipv6-entries: 0
--------------------------------------------------------------------------------------
IPv4 Filter ACLs
--------------------------------------------------------------------------------------
Filter   : ip_tcp
Active On: 1 subinterfaces (input) and 0 subinterfaces (output)
Entries  : 1
--------------------------------------------------------------------------------------
IPv6 Filter ACLs
--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
MAC Filter ACLs
--------------------------------------------------------------------------------------

A:srl-a# show acl ipv4-filter ip_tcp
======================================================================================
Filter        : ip_tcp
SubIf-Specific: disabled
Entry-stats   : no
Entries       : 1
--------------------------------------------------------------------------------------
 Subinterface     Input   Output
ethernet-1/1.10   yes     no
--------------------------------------------------------------------------------------
Entry 100
  Match               : protocol=tcp, any(*)->any(*)
  Action              : accept
  Input Match Packets : 0
  Input Last Match    : never
  Output Match Packets: 0
  Output Last Match   : never
  TCAM Entries        : 2 for one subinterface and direction
--------------------------------------------------------------------------------------
```

```srl
A:srl-a# show acl ipv4-filter ip_tcp entry 100 subinterface ethernet-1/1.10
======================================================================================
Filter        : ip_tcp
SubIf-Specific: disabled
Entry-stats   : no
Entries       : 1
--------------------------------------------------------------------------------------
 Subinterface     Input   Output
ethernet-1/1.10   yes     no
--------------------------------------------------------------------------------------
Entry 100
  Match               : protocol=tcp, any(*)->any(*)
  Action              : accept
  Input Match Packets : 0
  Output Match Packets: 0
  TCAM Entries        : 2 for one subinterface and direction
--------------------------------------------------------------------------------------
```

## Logging

```srl
A:srl-a# info system logging file acl-log-1
    system {
        logging {
            file acl-log-1 {
                directory /var/log/srlinux/file/
                rotate 5
                size 1M
                subsystem acl {
                }
            }
        }
A:srl-a# info acl ipv4-filter ip_tcp
    acl {
        ipv4-filter ip_tcp {
            entry 100 {
                action {
                    drop {
                        log true
                    }
                }
                match {
                    protocol tcp
                }
```
