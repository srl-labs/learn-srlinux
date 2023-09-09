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

Wildcards allow CLI users to specify a pattern that matches all existing values for a parameter using the `*` character. For example, if you want to show all subinterfaces of `ethernet-1/1` interface, you can use the following command:

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

You can also substitute multiple parameters with a wildcard; For example, to show `active` status for all ipv4 unicast bgp routes in the default network instance route table:

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

Wildcards are not limited to info command, you can simplify your configuration workflows by using wildcards as well. For example, to add `subinterface 0` for every interface in the system we can do:

=== "config"
    ```srl
    --{ + candidate shared default }--[  ]--
    A:srl# /interface * subinterface 0 description "created with a wildcard"
    ```
=== "verification"
    ```diff
    --{ +* candidate shared default }--[  ]--
    A:srl# diff
        interface ethernet-1/1 {
    +         subinterface 0 {
    +             description "created with a wildcard"
    +         }
        }
        interface ethernet-1/3 {
    +         subinterface 0 {
    +             description "created with a wildcard"
    +         }
        }
        interface ethernet-1/4 {
    +         subinterface 0 {
    +             description "created with a wildcard"
    +         }
        }
        interface ethernet-1/5 {
    +         subinterface 0 {
    +             description "created with a wildcard"
    +         }
        }
        interface ethernet-1/8 {
    +         subinterface 0 {
    +             description "created with a wildcard"
    +         }
        }
        interface mgmt0 {
            subinterface 0 {
    +             description "created with a wildcard"
            }
        }
    ```

### Interfaces

Technically, wildcards work on YANG's list keys, with the notable exception of interface names. The interface name is a key itself, but given how the name is composed of a linecard and port combination (e.g. `ethernet-1/1`), wildcards can be used on these components of the interface name individually. For example, to expand all interfaces on linecard 1:

```srl
--{ + candidate shared default }--[  ]--
A:srl# info interface ethernet-1/* admin-state
    interface ethernet-1/1 {
        admin-state enable
    }
    interface ethernet-1/3 {
        admin-state enable
    }
    interface ethernet-1/4 {
        admin-state enable
    }
    interface ethernet-1/5 {
        admin-state enable
    }
    interface ethernet-1/8 {
        admin-state enable
    }
```

### Context

A cool feature that both wildcards and ranges share is being able to enter in the context while using them. Say, you want to analyze state of the configured interfaces interactively. You can do so by entering in the context of all your interfaces in one go:

```srl
--{ + running }--[  ]--
#(1)!
A:srl# enter state

--{ + state }--[  ]--
#(2)!
A:srl# interface *

--{ + state }--[ interface * ]--
#(3)!
```

1. SR Linux employs a `state` datastore that is a read-only datastore that combines both configuration and state elements. Users can enter the `state` datastore to browse it.
2. Note, how the CLI engine's prompt reflects the datastore you're in.
3. When we used `interface *` context switching command, the prompt reflects that we are in the _wildcarded_ context of all interfaces in the system.

Now that we entered the wildcarded context we can use any command as we would normally do, but the command will be executed for all interfaces in the system. For example, to show all interfaces with their admin state:

```srl
--{ + state }--[ interface * ]--
A:srl# info statistics in-unicast-packets
    interface ethernet-1/1 {
        statistics {
            in-unicast-packets 0
        }
    }
    interface ethernet-1/3 {
        statistics {
            in-unicast-packets 0
        }
    }
    # snip
    interface mgmt0 {
        statistics {
            in-unicast-packets 919
        }
    }
```

And of course wildcards can be used in the context mode for configration task as well. Let's now make our subinterface vlan-tagged for all `subinterface 0` we added in one of the examples before:

```srl
# switching to candidate datastore
--{ + state }--[ interface * ]--
A:srl# enter candidate

# entering the wildcarded context
# of subinterface 0 of all interfaces
--{ + candidate shared default }--[  ]--
A:srl# interface * subinterface 0

# adding vlan tagging on all of them
--{ + candidate shared default }--[ interface * subinterface 0 ]--
A:srl# A:srl# vlan encap single-tagged vlan-id any
```

As a result, all subinterfaces get vlan tagging configuration:

```diff
--{ +* candidate shared default }--[ interface * subinterface 0 ]--
A:srl# diff
      interface ethernet-1/1 {
          subinterface 0 {
              vlan {
                  encap {
+                     single-tagged {
+                         vlan-id any
+                     }
                  }
              }
          }
      }
      interface ethernet-1/3 {
          subinterface 0 {
              vlan {
                  encap {
+                     single-tagged {
+                         vlan-id any
+                     }
                  }
              }
          }
      }
# snip
```

### Existing objects and scoping

It is important to keep in mind, that wildcards expand to existing objects only. If, say, your candidate or running datastore has only two interfaces `ethernet-1/1` and `ethernet-1/5`, then the wildcard `ethernet-1/*` will only match these two interfaces and will not crate other possible interfaces.

Another subtle characteristic of wildcards is that the existing list keys that wildcards can expand to must belong to the context where a wildcard is used.

Consider the following example where a user has five interfaces configured for which they want to enable lldp. First they check that the interfaces exist in the running datastore:

```srl
--{ + candidate shared default }--[  ]--
A:srl# info from running interface ethernet-1/* admin-state
    interface ethernet-1/1 {
        admin-state enable
    }
    interface ethernet-1/3 {
        admin-state enable
    }
    interface ethernet-1/4 {
        admin-state enable
    }
    interface ethernet-1/5 {
        admin-state enable
    }
    interface ethernet-1/8 {
        admin-state enable
    }
```

So they proceed with enabling lldp on all interfaces:

```srl
--{ + candidate shared default }--[  ]--
A:srl# system lldp interface ethernet-1/* admin-state enable
Error: Path '.system.lldp.interface{.name==ethernet-1/*}' does not specify any existing objects
```

The reason this configuration command failed is that the `/system/lldp/interface` list while referencing the global interfaces configured in the system, does not have these interfaces created in its own context.
