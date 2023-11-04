---
comments: true
title: Show commands for Mirroring
---

# Mirroring

Mirror source config (can be either interface or ACL)

```srl
A:srl-a# /info system mirroring
    system {
        mirroring {
            mirroring-instance 1 {
                admin-state enable
                mirror-source {
                    interface ethernet-1/1 {
                        direction ingress-egress
                    }
                    acl {
                        ipv4-filter ip_tcp {
                            entry 100 {
                            }
                        }
                    }
                }
            }
```

Local Mirror Destination

```srl
A:srl-a# info /system mirroring
    mirroring-instance 1 {
        admin-state enable
        mirror-source {
            interface ethernet-1/1 {
                direction ingress-egress
            }
            acl {
                ipv4-filter ip_tcp {
                    entry 100 {
                    }
                }
            }
        }
        mirror-destination {
            local ethernet-1/2.1
        }
    }
```

## Mirror Statistics

```srl
A:srl-a# info from state interface ethernet-1/1 statistics | grep mirror
            out-mirror-octets 0
            out-mirror-packets 0
```
