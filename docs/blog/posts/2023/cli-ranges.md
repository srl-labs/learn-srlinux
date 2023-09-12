---
date: 2023-09-07
tags:
  - cli
authors:
  - rdodin
---

# SR Linux CLI: Wildcards and Ranges

SR Linux CLI is likely one of the most advanced and user-friendly CLIs I have ever worked with. It shakes off the "industry standard" label and introduces a number of new concepts that make it easier for engineers to work with the configuration and state datastores of the system. One of these concepts is the ability to use wildcards and ranges in the CLI commands, and this is what we focus on in this post.

The notion of wildcards and ranges is not new; a few CLI engines already offer support for ranges and/or wildcards. However, SR Linux'es implementation of ranges and wildcards notches it up a level, and in this post we will see in what way.

<!-- more -->

Conceptually, the wildcards/ranges idea is simple: instead of specifying a single value for a parameter, you can specify a range of values or a wildcard. For example, instead of specifying a single interface name, you can specify a range of interfaces, or you can specify a wildcard that matches multiple interfaces. The CLI engine should then expand the range or wildcard into a list of values and execute the command for each value in the list.

But on SR Linux you don't have to choose between a range and a wildcard, you can mix and match them to one-up your CLI game.

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

Wildcards are not limited to info command, you can simplify your configuration workflows by using wildcards as well. For example, to add `subinterface 0` for every configured interface in the system we can do:

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

Technically, wildcards work on YANG's list keys, with the notable exception of interface names. The interface name is a key itself, but given how the name is composed of a linecard and port parts (e.g. `ethernet-1/1`), wildcards can be used on these parts individually. For example, to expand all interfaces on linecard 1:

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

A cool feature that both wildcards and ranges share is being able to enter the expanded context. Imagine that you want to analyze the state of the configured interfaces interactively. You can do so by entering the context of all your interfaces in one go:

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

Now that we entered the wildcarded context, we can use commands available in this context; the commands will be applied for all interfaces in the system as dictated by the wildcard. For example, checking the number of incoming unicast packets on all interfaces is as simple as:

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

Wildcards can be used in the context mode for configuration tasks. Here is how to add vlan tagging for `subinterface 0` on all interfaces:

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

It is important to keep in mind, that wildcards expand to existing objects only. If, say, your candidate or running datastore has only two interfaces `ethernet-1/1` and `ethernet-1/5`, then the wildcard `ethernet-1/*` will only match these two existing interfaces.

Another subtle wildcard's characteristic is that the existing list keys that wildcards can expand to must belong to the context where a wildcard is used.  
Consider the following example where a user has five interfaces configured for which they want to enable LLDP. First, they ensure that the interfaces exist:

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

But when trying to enable LLDP on all interfaces using a wildcard, it suddenly fails:

```srl
--{ + candidate shared default }--[  ]--
A:srl# system lldp interface ethernet-1/* admin-state enable
Error: Path '.system.lldp.interface{.name==ethernet-1/*}' does not specify any existing objects
```

The reason it errored is that the `/system/lldp/interface` list itself does not have these interfaces available in its own context. The interfaces are available in the `/interface` list, and referenced by `/system/lldp/interface`, which does not make them eligible for wildcard expansion.  

Later in this post, you will see how [ranges](#objects-and-scoping) can solve this by creating objects that do not exist yet.

### Wildcards and strings

It might not be obvious, but wildcards can be used with string-based keys. Pretty much as you'd expect, you can add a wildcard `*` character anywhere in the string key and it will match any number of characters in that position.

For example, on a system that has several VRFs that start with `red` we can match all of them like that:

```srl
--{ +* candidate shared default }--[  ]--
A:srl# info network-instance red*
    network-instance red {
        admin-state enable
    }
    network-instance red-a {
        admin-state enable
    }
    network-instance red-b {
        admin-state enable
    }
    network-instance red-c {
        admin-state enable
    }
    network-instance red1 {
        admin-state enable
    }
    network-instance red2 {
        admin-state enable
    }
```

As you can see `red*` expands to `red`, `red-a`, `red-b`, `red-c`, `red1`, and `red2` keys. Using wildcard expansion with string keys is a great way to filter out objects that match a particular pattern, like a customer name or location code.

## Ranges

Wildcards are great for bulk operations on all existing objects, but what if you want to operate on a subset of objects some of which may not exist yet? This is where ranges come in handy.

Ranges allow CLI users to specify a range of values for a given list key. The syntax is simple: you specify the range as a comma-separated list of values where a value may be a scalar value or a consecutive range of values separated by `..` delimiter, or a mix of both!

| Syntax       | Result       |
| ------------ | ------------ |
| `{1,3}`      | 1, 3         |
| `{2..5}`     | 2, 3, 4, 5   |
| `{1,3..5,8}` | 1, 3, 4, 5,8 |

Here are a few examples to illustrate the concept:

```srl title="show admin status of interfaces 1,3,5"
--{ + running }--[  ]--
A:srl# info interface ethernet-1/{1,3,5} admin-state
    interface ethernet-1/1 {
        admin-state enable
    }
    interface ethernet-1/3 {
        admin-state enable
    }
    interface ethernet-1/5 {
        admin-state enable
    }
```

With `..` notation you can create consecutive integer ranges, for instance:

```srl title="consecutive range of interfaces"
--{ + running }--[  ]--
A:srl# info interface ethernet-1/{2..4} admin-state
    interface ethernet-1/3 {
        admin-state enable
    }
    interface ethernet-1/4 {
        admin-state enable
    }
```

And as promised, you can mix the two approaches for greater flexibility:

```srl title="mixing ranges and scalars"
--{ + running }--[  ]--
A:srl# info interface ethernet-1/{1,3..5,8} admin-state
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

### Objects and scoping

Ranges differ from wildcards in that they do not have to expand to existing objects. Ranges can be used to create new objects in the system, giving you a lot of flexibility in bulk creation of objects.

Having said that, if an object that range expands to already exists, it will be overwritten in the case of a configuration command. And vice versa, if in the `info` command, a range expands to a non-existing object, it will be skipped.

Let's see how it works in practice. Starting with a freshly deployed system, we can see that there are no `ethernet-1/*` interfaces configured:

```srl
--{ + running }--[  ]--
A:srl# info interface ethernet-1/*
--{ + running }--[  ]--
A:srl#
```

If at this stage we wanted to create a bunch of interfaces, we couldn't use wildcards, as they would not expand to anything. But we can use ranges:

```srl title="creating new objects with ranges"
--{ + running }--[  ]--
A:srl# enter candidate

--{ + candidate shared default }--[  ]--
A:srl# interface ethernet-1/{1..4} admin-state enable
```

As a result, we have four interfaces created:

```diff
--{ +* candidate shared default }--[  ]--
A:srl# diff
+     interface ethernet-1/1 {
+         admin-state enable
+     }
+     interface ethernet-1/2 {
+         admin-state enable
+     }
+     interface ethernet-1/3 {
+         admin-state enable
+     }
+     interface ethernet-1/4 {
+         admin-state enable
+     }
```

Because ranges can create new list elements, we can achieve the task of enabling LLDP on multiple interfaces that we [couldn't do](#existing-objects-and-scoping) with wildcards.

```srl
--{ +* candidate shared default }--[  ]--
A:srl# system lldp interface ethernet-1/{1,2} admin-state enable
```

### String keys

<small>First available in 23.10 version</small>

An attentive reader may have noticed that all the examples above use integer keys. Either interface numbers or VLAN IDs. But what about string-based keys? For example, creating multiple named VRFs, or ACLs?

In release 23.10 we are adding support for string/literal-based ranges expansion that opens the door to even more powerful CLI workflows.

| Syntax         | Result                    |
| -------------- | ------------------------- |
| `{red,blue}`   | "red", "blue"             |
| `{red{1..2}}`  | "red1", "red2"            |
| `{red-{a..c}}` | "red-a", "red-b", "red-c" |

Now you can create multiple VRFs in one go:

=== "List of strings"
    ```srl
    --{ +* candidate shared default }--[  ]--
    A:srl# network-instance {red,blue} admin-state enable
    ```
    ```diff
    --{ +* candidate shared default }--[  ]--
    A:srl# diff
    +     network-instance blue {
    +         admin-state enable
    +     }
    +     network-instance red {
    +         admin-state enable
    +     }
    ```
=== "Nested ranges"
    ```srl
    --{ +* candidate shared default }--[  ]--
    A:srl# network-instance {red{1..2},blue{1..2}} admin-state enable
    ```
    ```diff
    --{ +* candidate shared default }--[ network-instance {red{1..2},blue{1..2}} ]--
    A:srl# diff
    +     network-instance red1 {
    +         admin-state enable
    +     }
    +     network-instance red2 {
    +         admin-state enable
    +     }
    +     network-instance blue1 {
    +         admin-state enable
    +     }
    +     network-instance blue2 {
    +         admin-state enable
    +     }
    ```
=== "Nested literal ranges"
    ```srl
    --{ +* candidate shared default }--[  ]--
    A:srl# network-instance {red-{a..c}} admin-state enable
    ```
    ```diff
    --{ +* candidate shared default }--[ network-instance {red{1..2},blue{1..2}} ]--
    A:srl# diff
    +     network-instance red-a {
    +         admin-state enable
    +     }
    +     network-instance red-b {
    +         admin-state enable
    +     }
    +     network-instance red-c {
    +         admin-state enable
    +     }
    ```

As you can see, string-based ranges allow the creation of multiple named objects in a single sweep and by nesting them you can create even more complex structures.

As expected, `info` command can benefit from string-based ranges as well. We can now show all ACLs that are named following a certain pattern:

```srl
--{ +* candidate shared default }--[  ]--
A:srl# info acl ipv4-filter {cust1-*,cust2-*} description
    acl {
        ipv4-filter cust1-filter1 {
            description somefilter
        }
        ipv4-filter cust1-filter2 {
            description somefilter
        }
        ipv4-filter cust2-filter1 {
            description somefilter
        }
        ipv4-filter cust2-filter2 {
            description somefilter
        }
    }
```

Operators dealing with large scale deployments where named objects usually encode some customer/facility information can smell the quality of life improvements that string-based ranges bring to the table.
