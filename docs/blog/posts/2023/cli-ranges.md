---
date: 2023-09-07
tags:
  - cli
authors:
  - rdodin
---

# SR Linux CLI: Wildcards and Ranges

SR Linux CLI is likely one of the most advanced and user-friendly CLIs I have ever worked with. It shakes off the "industry standard" label and introduces a number of new concepts that make it easier for engineers to work with the configuration and state datastores of the system. One of these concepts is the ability to use wildcards and ranges in the CLI commands, and this is what we focus on in this post.

The concept of wildcards and ranges is not entirely new, as it makes complete sense to offer such functionality for CLI users and it was implemented in a few other CLI engines prior to SR Linux. However, SR Linux'es implementation of ranges and wildcards notches it up a level, and we will see why.

<!-- more -->

Conceptually, the wildcards/ranges idea is simple: instead of specifying a single value for a parameter, you can specify a range of values or a wildcard. For example, instead of specifying a single interface name, you can specify a range of interfaces, or you can specify a wildcard that matches multiple interfaces. The CLI engine should then expand the range or wildcard into a list of values and execute the command for each value in the list.

But on SR Linux you don't have to choose between a range and a wildcard, you can mix and match them to one-up your CLI game. But before we get to that, let's look at the basics.

## Wildcards

Wildcards allow CLI users to specify a pattern that matches all possible values for a parameter using `*` character. For example, if you want to show all subinterfaces of `ethernet-1/1` interface, you can use the following command:

```srl
--{ * candidate shared default }--[  ]--
A:srl# info /interface ethernet-1/1 subinterface *
    interface ethernet-1/1 {
        subinterface 0 {
            admin-state enable
        }
        subinterface 1 {
            admin-state enable
        }
        subinterface 2 {
            admin-state enable
        }
        subinterface 3 {
            admin-state enable
        }
    }
```

You can also substitute multiple parameters with a wildcard; For example, to show `active` status for all ipv4 unicast bgp routes in the default network instance:

```srl
A:leaf1# info from state network-instance default route-table ipv4-unicast route * id * route-type bgp route-owner * origin-network-instance * active
    network-instance default {
        route-table {
            ipv4-unicast {
                route 10.0.0.2/32 id 0 route-type bgp route-owner bgp_mgr origin-network-instance default {
                    active true
                }
                route 10.0.0.3/32 id 0 route-type bgp route-owner bgp_mgr origin-network-instance default {
                    active true
                }
                route 10.0.0.4/32 id 0 route-type bgp route-owner bgp_mgr origin-network-instance default {
                    active true
                }
                route 10.0.0.5/32 id 0 route-type bgp route-owner bgp_mgr origin-network-instance default {
                    active true
                }
                route 10.0.0.6/32 id 0 route-type bgp route-owner bgp_mgr origin-network-instance default {
                    active true
                }
            }
        }
    }
```

Wildcards are not limited to data retrieval commands, you can also use them in configuration commands. For example, to enable `lldp` on all interfaces in the system:

```srl

```
