---
date: 2023-09-07
tags:
  - cli
authors:
  - rdodin
---

# SR Linux CLI: Wildcards and Ranges

The SR Linux Command Line Interface (CLI) stands out as one of the most advanced and user-friendly CLI systems I've encountered. It breaks away from the conventional "industry standard" and introduces several innovative concepts that greatly enhance the ease of configuring and managing the network operating system. Among these innovations are "CLI wildcards and ranges," which, once mastered, can significantly improve your overall experience and efficiency.

The idea of using wildcards and ranges is not novel, as some CLI systems already include support for them. Nevertheless, SR Linux takes the concept of ranges and wildcards one step further, and in this post, we will explore how to harness their power effectively.

<!-- more -->

In essence, the concept behind wildcards and ranges is straightforward: rather than defining a single value for a parameter, you have the flexibility to define a range of values or use a wildcard. For instance, rather than designating a single interface name, you can define a range of interfaces, or you can employ a wildcard that matches multiple interfaces. The CLI engine will then automatically expand the specified range or wildcard into a list of individual values and execute the command for each value in that list.

And on SR Linux you don't have to choose between a range and a wildcard, you can mix and match them to one-up your CLI game.

## Wildcards

Wildcards enable CLI users to define a pattern that encompasses all existing values for a parameter by using the * character. For instance, if you wish to display all subinterfaces of the ethernet-1/1 interface, you can thrown in a `*` in your info command:

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

You can also substitute multiple parameters with a wildcard; For instance, if you want to check the active status for all IPv4 unicast BGP routes in the default network instance route table, just do this:

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

Wildcards aren't just for the `info` command; they can streamline your configuration tasks too. Take this for example: if you want to add `subinterface 0` for every configured interface in the system, it's exactly as you'd thought it'd be:

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

Technically, wildcards work on YANG's list keys, although there's a noteworthy exception for interface names. The interface name itself is a key, but here's the cool part: you can use wildcards on its individual components, like the linecard and port parts. So, if you want to expand all interfaces on linecard 1, it's intuitive:

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

Sure is, you can put an asterisk to the linecard number place and list certain ports on all line cards.

### Context

A cool feature that both wildcards and ranges share is the ability to enter into the expanded context. Imagine that you want to analyze the state of the configured interfaces interactively. Well, you can do just that by entering the context of all your interfaces all at once:

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

Having entered the wildcarded context, we gain access to a range of commands applicable within this context. These commands will be executed across all interfaces in the system, as specified by the wildcard. For example, listing the number of incoming unicast packets on all interfaces becomes a straightforward task:

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

As expected, wildcards can be used in the context mode for configuration tasks also. Here is how to add vlan tagging for `subinterface 0` on all interfaces:

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
A:srl# vlan encap single-tagged vlan-id any
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

I am a big fan of the context-based configuration workflows where wildcards and ranges eliminate copy pasting by "broadcasting" the configuration commmands to all applicable elements.

### Existing objects and scoping

It is important to keep in mind, that wildcards expand to existing objects only. If, say, your candidate or running datastore has only two interfaces `ethernet-1/1` and `ethernet-1/5`, then the wildcard `ethernet-1/*` will only match these particular existing interfaces.

Another subtle characteristic of wildcards is that the list keys they expand to must pertain to the context in which the wildcard is employed.  
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

But when trying to enable LLDP on all interfaces using a wildcard, the operation fails:

```srl
--{ + candidate shared default }--[  ]--
A:srl# system lldp interface ethernet-1/* admin-state enable
Error: Path '.system.lldp.interface{.name==ethernet-1/*}' does not specify any existing objects
```

The reason for the error is that the `/system/lldp/interface` list does not contain these interfaces within its own context. These interfaces are instead available within the `/interface` list and are referenced by `/system/lldp/interface`. This referencing structure does not make them eligible for wildcard expansion in this context.

Later in this post, we will see how [ranges](#objects-and-scoping) can solve this by creating objects that do not exist yet.

### Wildcards and strings

It might not be obvious, but wildcards can be used with string-based keys. Pretty much as you'd expect, you can add a wildcard `*` character anywhere in the string key and it will match any number of characters in that position.

For example, on a system that has several VRFs with names beginning with `red` we can match all of them like that:

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

As you can see `red*` expands to `red`, `red-a`, `red-b`, `red-c`, `red1`, and `red2` keys. Leveraging wildcard expansion with string keys is a great way to filter out objects that match a particular pattern, like a customer name or location code.

## Ranges

Wildcards are great for bulk operations on all existing objects, but what if you want to operate on a subset of objects some of which may not exist yet? This is where ranges come in handy.

Ranges provide CLI users with a convenient way to define a series of values for a particular list key. The syntax is straightforward: you express the range as a list of values separated by commas. Each value can be a single scalar value or a continuous range of values indicated by the `..` delimiter. You can also mix both formats within the same range specification.

Here is a short cheat sheet showing the syntax of the range pattern and how it translates to the list of elements:

| Syntax       | Result       |
| ------------ | ------------ |
| `{1,3}`      | 1, 3         |
| `{2..5}`     | 2, 3, 4, 5   |
| `{1,3..5,8}` | 1, 3, 4, 5,8 |

To illustrate the ranges concept let's have a look at a couple of examples:

In its basic form, a range accepts a comma-separated list of elements. For instance, in the example below, we can display the admin state of interfaces 1, 3, and 5 using just one command: 

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

A little bit more elaborated range expression uses `..` notation to create a consecutive range of integer values. Using the same task as above, we can employ `ethernet-1/{2..4}` range to list all interfaces in the range between 2 and 4[^1].

```srl title="consecutive range of interfaces"
--{ + running }--[  ]--
A:srl# info interface ethernet-1/{2..4} admin-state
    interface ethernet-1/2 {
        admin-state enable
    }
    interface ethernet-1/3 {
        admin-state enable
    }
    interface ethernet-1/4 {
        admin-state enable
    }
```

And you can mix the two range patterns for even greater flexibility:

```srl title="mixing ranges and scalars"
--{ + running }--[  ]--
A:srl# info interface ethernet-1/{1,3..5,8} admin-state
    interface ethernet-1/1 {
        admin-state enable
    }
    interface ethernet-1/2 {
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

Ranges have a distinct quality over wildcards in that they are not limited to existing objects. Ranges can be used to generate new objects within the system, which comes in super handy for bulk object creation.

However, it's worth noting that if a range expands to an object that already exists, a configuration command will overwrite that object. Conversely, in the case of an info command, if a range expands to a non-existing object, it will be skipped.

To demonstrate this in practice, let's begin with a freshly deployed system, where no `ethernet-1/*` interfaces are configured:

```srl
--{ + running }--[  ]--
A:srl# info interface ethernet-1/*
--{ + running }--[  ]--
A:srl#
```

At this point, if we aim to create a set of interfaces, wildcards won't be of any use since they wouldn't expand to anything. Here come ranges:

```srl title="creating new objects with ranges"
--{ + running }--[  ]--
A:srl# enter candidate

--{ + candidate shared default }--[  ]--
A:srl# interface ethernet-1/{1..4} admin-state enable
```

By using ranges in the candidate mode we created four new interfaces on the system with a single command:

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

An observant reader may have noticed that all the examples provided thus far have used integer keys, such as interface numbers or VLAN IDs. But what about scenarios involving string-based keys, such as creating multiple named VRFs or ACLs?

In release 23.10 we are adding support for string/literal-based ranges expansion that opens the door to even more powerful CLI workflows.

| Syntax         | Result                    |
| -------------- | ------------------------- |
| `{red,blue}`   | "red", "blue"             |
| `{red{1..2}}`  | "red1", "red2"            |
| `{red-{a..c}}` | "red-a", "red-b", "red-c" |

With this enhanced range syntax you now you can create multiple VRFs in one go:


In its simplest form, string-based ranges operate on comma-separated list of strings. Like in the example below where we provide two strings `red` and `blue` to the command to create network-instance.
```srl
--{ +* candidate shared default }--[  ]--
A:srl# network-instance {red,blue} admin-state enable
```

The range expands to a list of two elements and as a result we get two VRFs created:

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

And we didn't stop here. For those who love programming in Jinja we added advanced templation syntax that involves nested ranges and a combination of both integer and string values:

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

String-based ranges offer efficient creation of multiple named objects in one go, and by nesting them, you can construct even more intricate structures.

As expected, the `info` command can also take advantage of string-based ranges. This enables us to display all ACLs that adhere to a specific naming pattern:

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

## Summary

Command Line Interface has been under assault lately when many of us chanted "CLI is dead, long live API". But seasoned network professionals understand its enduring value in the realm of troubleshooting.  
When it comes to diagnosing and resolving network issues swiftly and effectively, the CLI's simplicity and precision shine through. So, while graphical interfaces and automation have evolved, the CLI retains its throne as the trusted companion of network experts, proving that it's far from obsolete.

This means CLI deserves to get quality of life improvements and features that match the workflows of today. We believe SR Linux CLI is one of these interfaces that offers modern management paradigms with wildcards and ranges being good examples.

I hope you'll get a chance to try these CLI nuggets yourself, but I must warn you, once you get a taster there is no turning back.

[^1]: the range boundaries are included.