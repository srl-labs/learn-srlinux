---
date: 2024-09-26
tags:
    - cli
    - interfaces
    - bgp
authors:
    - aninda
    - vivek
links:
  - Get Started With SR Linux: get-started/index.md
---

# Navigating SR Linux

SR Linux (aka SRL), released back in 2021, is a new operating system from Nokia, designed to power data center fabrics, with network automation no longer being treated as a second-class citizen. SR Linux is built from the ground up using YANG, which is a modeling language describing how data is structured. As an operator, this enables you to view the entire structure as a schema tree (which we will see shortly).

Like any new operating system, there is a learning curve. In the past, I have had to learn several new operating systems (having originally started with Cisco IOS), including Cisco IOS-XE/NXOS, Arista EOS, Cumulus NCLU/NVUE, Juniper Junos and now, Nokia SR Linux. In general, I have always followed the same methodology in learning - learn by building something relatable. Since SR Linux focuses on data center fabrics, we're going to build something a little relatable to that. Let's dive in.

<small>This is a condensed version of a larger [SR Linux Getting Started Guide](../../../get-started/index.md).</small>

<!-- more -->

This topology is deployed using [Containerlab](https://containerlab.dev) with the following topology file:

```yaml title="navigating-srlinux.clab.yml"
name: nav-srl

topology:
  nodes:
    spine1:
      kind: nokia_srlinux
      image: ghcr.io/nokia/srlinux:24.7.2
    spine2:
      kind: nokia_srlinux
      image: ghcr.io/nokia/srlinux:24.7.2
    leaf1:
      kind: nokia_srlinux
      image: ghcr.io/nokia/srlinux:24.7.2
    leaf2:
      kind: nokia_srlinux
      image: ghcr.io/nokia/srlinux:24.7.2
    h1:
      kind: linux
      image: ghcr.io/srl-labs/network-multitool
      exec:
        - ip link set address 00:c1:ab:00:00:01 dev eth1
        - ip addr add 172.16.10.1/24 dev eth1
    h2:
      kind: linux
      image: ghcr.io/srl-labs/network-multitool
      exec:
        - ip link set address 00:c1:ab:00:00:02 dev eth1
        - ip addr add 172.16.20.1/24 dev eth1
  links:
    - endpoints: ["leaf1:e1-1", "spine1:e1-1"]
    - endpoints: ["leaf1:e1-2", "spine2:e1-1"]
    - endpoints: ["leaf2:e1-1", "spine1:e1-2"]
    - endpoints: ["leaf2:e1-2", "spine2:e1-2"]
    - endpoints: ["leaf1:e1-3", "h1:eth1"]
    - endpoints: ["leaf2:e1-3", "h2:eth1"]
```

By the end of this, you should be able to:

1. Navigate and understand the configuration structure of SR Linux.
2. Understand the concept of a network instance on SRL, instantiate a default network instance and configure and validate Layer 3 functionality such as IPv4 addressing on an interface.
3. Configure and validate basic Layer 2 functionality with SR Linux's concept of tagged/untagged interfaces and a MAC-VRF, while also associating IRB interfaces for Layer 3 host services.
4. Configure and validate a routing protocol such as BGP to exchange IPv4 network reachability information and achieve the end goal of host h1 communicating with h2.

## CLI modes in SR Linux and first look

SR Linux has three major CLI modes available for navigation (and a fourth which is more of a tool, ironically, called *tools*). These modes are:

1. **Running** - this is similar to the enable mode (in Cisco/Arista world) or the operational mode (Juniper Junos). In this mode, you can view the running/active configuration, but you cannot add/remove/modify any configuration.  
2. **Candidate** - this is the configuration mode where you can modify configuration. From the running mode, you can go into the candidate mode using the command *enter candidate*. This puts you in a shared configuration mode which other users can enter and modify the configuration as well. Alternatively, a user can enter the *exclusive* candidate mode using *enter candidate exclusive*, which locks out all other users from making changes or the *private* candidate mode using *enter candidate private*, which allows multiple users to enter the candidate mode but only commits your changes.
3. **State** - this is similar to the running state but can show you additional *state*, including statistics for interfaces, as an example.

While *tools* is not technically a CLI mode, it facilitates important functionality such as clearing interface statistics or clearing BGP neighbors, as examples.

With the containerlab topology deployed using `containerlab deploy -t [topology filename]`, it can be inspected to confirm the IP addressing for the nodes (in case static IP addresses are not provided as part of the topology file):

```shell
$ containerlab inspect -t navigating-srlinux.clab.yml
+---+---------------------+--------------+------------------------------------+---------------+---------+-----------------+----------------------+
| # |        Name         | Container ID |               Image                |     Kind      |  State  |  IPv4 Address   |     IPv6 Address     |
+---+---------------------+--------------+------------------------------------+---------------+---------+-----------------+----------------------+
| 1 | clab-nav-srl-h1     | 71c9b9d54fd4 | ghcr.io/srl-labs/network-multitool | linux         | running | 172.20.20.7/24  | 2001:172:20:20::7/64 |
| 2 | clab-nav-srl-h2     | 1913b02d0bd0 | ghcr.io/srl-labs/network-multitool | linux         | running | 172.20.20.12/24 | 2001:172:20:20::c/64 |
| 3 | clab-nav-srl-leaf1  | 8960a0944372 | ghcr.io/nokia/srlinux:24.7.2       | nokia_srlinux | running | 172.20.20.9/24  | 2001:172:20:20::9/64 |
| 4 | clab-nav-srl-leaf2  | d45cad84bd27 | ghcr.io/nokia/srlinux:24.7.2       | nokia_srlinux | running | 172.20.20.11/24 | 2001:172:20:20::b/64 |
| 5 | clab-nav-srl-spine1 | 777d4093244c | ghcr.io/nokia/srlinux:24.7.2       | nokia_srlinux | running | 172.20.20.8/24  | 2001:172:20:20::8/64 |
| 6 | clab-nav-srl-spine2 | d6bba1f1668a | ghcr.io/nokia/srlinux:24.7.2       | nokia_srlinux | running | 172.20.20.10/24 | 2001:172:20:20::a/64 |
+---+---------------------+--------------+------------------------------------+---------------+---------+-----------------+----------------------+
```

Let's login to leaf1 using the node name as shown in the table above:

```shell
ssh admin@clab-nav-srl-leaf1
```

<div class="embed-result">
```{.no-copy .no-select}
................................................................
:                  Welcome to Nokia SR Linux!                  :
:              Open Network OS for the NetOps era.             :
:                                                              :
:    This is a freely distributed official container image.    :
:                      Use it - Share it                       :
:                                                              :
: Get started: https://learn.srlinux.dev                       :
: Container:   https://go.srlinux.dev/container-image          :
: Docs:        https://doc.srlinux.dev/24-7                    :
: Rel. notes:  https://doc.srlinux.dev/rn24-7-2                :
: YANG:        https://yang.srlinux.dev/release/v24.7.2        :
: Discord:     https://go.srlinux.dev/discord                  :
: Contact:     https://go.srlinux.dev/contact-sales            :
................................................................

Welcome to the srlinux CLI.
Type 'help' (and press <ENTER>) if you need any help using this.

--{ running }--[  ]--
A:leaf1#

```
</div>

Once logged in, the user in placed in the running mode, indicated by `{ running }` in the prompt. Following this, square brackets indicate the current hierarchy (or the present working context) of the user - when this is empty, it implies that you are in the root hierarchy. Users can move to a specific hierarchy as needed, giving them the ability to view configuration or state only from that context/hierarchy. For example, using `interface ethernet1/1`, you can move to the interface ethernet1/1 hierarchy, and all info/show commands are now specific to this context only, as shown below.

```

--{ running }--[  ]--
A:leaf1# interface ethernet-1/1

--{ running }--[ interface ethernet-1/1 ]--
A:leaf1# show
==================================================

ethernet-1/1 is up, speed 25G, type None
--------------------------------------------------

==================================================

--{ running }--[ interface ethernet-1/1 ]--

```

/// admonition | Present working context
    type: subtle-note
The present working context or hierarchy will always be shown within square brackets `[ ]` after the CLI mode of the prompt.
///

In general, operational commands can be divided into two major categories:

1. Commands that show you the configuration of different objects in the system (like an interface, for example).
2. Commands that show you the state of different objects in the system (again, like an interface, for example).

With SR Linux, configuration can be viewed using `info` command when in the CLI is in `running` or `candidate` mode, while state can be viewed using `info` command in the `state` CLI mode and `show` commands. We'll use these more extensively in the following sections.  
Containerlab does some minimal bootstrapping of the node as part of launching it and thus, as an example below, the `info system lldp` displays the LLDP configuration and `show system lldp neighbor` displays discovered LLDP neighbors on leaf1.

/// tab | LLDP config
`info` command shows configuration of the `system lldp` context since the CLI is in `running` mode.
```srl
--{ running }--[  ]--
A:leaf1# info system lldp
    system {
        lldp {
            admin-state enable
        }
    }
```

///
/// tab | LLDP state

```srl
--{ running }--[  ]--
A:leaf1# show system lldp neighbor
  +--------------+-------------------+----------------------+---------------------+------------------------+----------------------+---------------+
  |     Name     |     Neighbor      | Neighbor System Name | Neighbor Chassis ID | Neighbor First Message | Neighbor Last Update | Neighbor Port |
  +==============+===================+======================+=====================+========================+======================+===============+
  | ethernet-1/1 | 1A:E8:04:FF:00:00 | spine1               | 1A:E8:04:FF:00:00   | 17 hours ago           | 6 seconds ago        | ethernet-1/1  |
  | ethernet-1/2 | 1A:7B:05:FF:00:00 | spine2               | 1A:7B:05:FF:00:00   | 17 hours ago           | 5 seconds ago        | ethernet-1/1  |
  +--------------+-------------------+----------------------+---------------------+------------------------+----------------------+---------------+

```

///

## Configuring Layer 3 interfaces

We're back on leaf1 and in the running mode. From here, let's enter the candidate mode with `enter candidate`.

```srl
--{ running }--[  ]--
A:leaf1# enter candidate

--{ candidate shared default }--[  ]--
A:leaf1#
```

SR Linux can be configured using flat `set` commands (similar to Junos) or by moving into a specific hierarchy configuring different parameters relevant to that hierarchy. Interfaces in SR Linux, like Junos, are defined as physical interfaces with one or more subinterfaces (units, in Junos terminology) with a set of physical properties for the physical interface and logical properties for the subinterfaces. As an example, `mtu` is a physical property that can be configured for the physical interface, while `ip mtu` is a logical property configured under a subinterface.

```text
interfaces {
  interface-name {
   physical-properties;
    [...]
    subinterface <> {
      logical-properties;
      [...]
    }
  }
}
```

Being a fully YANG-modelled at its core, SR Linux requires operators to be specific about their intent and by default, nothing is enabled in the OS. The user controls exactly what they want on the system. This is why you will see most objects associated with an `admin-state`. Let's configure Ethernet1/1 on leaf1 as a Layer 3 interface now using flat `set` commands.

```srl
--{ candidate shared default }--[  ]--
A:leaf1# set interface ethernet-1/1 admin-state enable

--{ * candidate shared default }--[  ]--
A:leaf1# set interface ethernet-1/1 mtu 9100

--{ * candidate shared default }--[  ]--
A:leaf1# set interface ethernet-1/1 subinterface 0 ipv4 address 198.51.100.0/31
```

Changes to the configuration in candidate mode must be explicitly committed similar to Junos or Cisco IOS-XR. However, it is important to provide the user a view to check changes and also, validate changes that were made, potentially alerting the user of any unmet dependencies.

The `diff` command displays a diff of the changes in the system specific to the hierarchy the user is in. Thus, the easiest way to view all diffs, regardless of where you are in the system, is using `diff /` (with `/` indicating the root of the tree). Changes can be validated using the `commit validate` command and then committed using the `commit` command.

The two most common ways of using this are `commit now` which commits any pending changes and moves the user back into running mode and `commit stay` which commits the changes but stays in candidate mode. Let's go ahead and view a diff of our changes and then commit them.

```srl
--{ * candidate shared default }--[  ]--
A:leaf1# diff /
      interface ethernet-1/1 {
+         mtu 9100
+         subinterface 0 {
+             ipv4 {
+                 address 198.51.100.0/31 {
+                 }
+             }
+         }
      }

--{ * candidate shared default }--[  ]--
A:leaf1# commit stay
All changes have been committed. Starting new transaction.
```

With these changes in place, let's look at the state of the interface with `show interface ethernet-1/1`.

```srl
--{ + candidate shared default }--[  ]--
A:leaf1# show interface ethernet-1/1
==================================================================================================================================================================================
ethernet-1/1 is up, speed 25G, type None
  ethernet-1/1.0 is down, reason no-ip-config
    Network-instances:
    Encapsulation   : null
    Type            : routed
    IPv4 addr    : 198.51.100.0/31 (static, None)
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
==================================================================================================================================================================================
```

While the physical interface is up, the subinterface (ethernet-1/1.0) is reported down. The down reason reads *no-ip-config* and it simply means that the subinterface has not been configured with any IP address family. How come, you may ask?

Recall, that SR Linux wants an operator to clearly indicate what needs to be enabled and doesn't do things on its own. Hence while we configured the IPv4 address on an interface, we did not enable this address family. This can be quickly fixed by setting the admin-state for IPv4 to `enable` as well, as shown below. Once this is done, the subinterface comes up.

```srl
--{ + candidate shared default }--[  ]--
A:leaf1# set interface ethernet-1/1 subinterface 0 ipv4 admin-state enable

--{ +* candidate shared default }--[  ]--
A:leaf1# commit stay

--{ + candidate shared default }--[  ]--
A:leaf1# show interface ethernet-1/1
==================================================================================================================================================================================
ethernet-1/1 is up, speed 25G, type None
  ethernet-1/1.0 is up
    Network-instances:
    Encapsulation   : null
    Type            : routed
    IPv4 addr    : 198.51.100.0/31 (static, None)
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
==================================================================================================================================================================================
```

With ethernet-1/1 configured, let's take the opportunity to configure ethernet-1/2 using hierarchical configuration. In candidate mode, we can move into a specific hierarchy as follows (using interface ethernet-1/2 as an example):

```srl
--{ +* candidate shared default }--[  ]--
A:leaf1# interface ethernet-1/2

--{ +* candidate shared default }--[ interface ethernet-1/2 ]--
```

From here, a <kbd>?</kbd> displays configuration options specific to this hierarchy only.

```srl
--{ +* candidate shared default }--[ interface ethernet-1/2 ]--
A:leaf1#
Local commands:
  admin-state*      The configured, desired state of the interface
  description*      A user-configured description of the interface
  ethernet
  lag               Container for options related to LAG
  loopback-mode*    Loopback mode of the port
  mtu*              Port MTU in bytes including ethernet overhead but excluding 4-bytes FCS
  sflow             Context to configure sFlow parameters
  subinterface      The list of subinterfaces (logical interfaces) associated with a physical interface
  tpid*             Optionally set the tag protocol identifier field (TPID) that
  transceiver
  vlan-tagging*     When set to true the interface is allowed to accept frames with one or more VLAN tags
```

Let's finish the configuration for this interface as well now, as shown below.

```srl
--{ +* candidate shared default }--[  ]--
A:leaf1# interface ethernet-1/2

--{ +* candidate shared default }--[ interface ethernet-1/2 ]--
A:leaf1# admin-state enable

--{ +* candidate shared default }--[ interface ethernet-1/2 ]--
A:leaf1# mtu 9100

--{ +* candidate shared default }--[ interface ethernet-1/2 ]--
A:leaf1# subinterface 0

--{ +* candidate shared default }--[ interface ethernet-1/2 subinterface 0 ]--
A:leaf1# ipv4 admin-state enable

--{ +* candidate shared default }--[ interface ethernet-1/2 subinterface 0 ]--
A:leaf1# ipv4 address 198.51.100.2/31

--{ +* candidate shared default }--[ interface ethernet-1/2 subinterface 0 ipv4 address 198.51.100.2/31 ]--
A:leaf1# commit now
All changes have been committed. Leaving candidate mode.

--{ + running }--[ interface ethernet-1/2 subinterface 0 ipv4 address 198.51.100.2/31 ]-
A:leaf1# /

--{ + running }--[  ]--
A:leaf1#
```

/// admonition | Note
    type: subtle-note
It is important to note that after committing a change and exiting back to running mode, the present working context does not change to root by default. To go back to root, you can use the forward slash symbol `/`.
///

## Network instances in SR Linux

### The default network instance

On SR Linux, network instances are virtual forwarding instances (tables), with their own set of interfaces and virtual forwarding tables. By default, a network instance called `mgmt` is created which isolates the management interface of the node. Outside of this, there are two types of network instances:

1. **IP VRF** - a network instance of type *ip-vrf* creates its own IP routing table, no different from how an IP VRF is created on Cisco/Arista/Juniper devices.
2. **MAC VRF** - a network instance of type *mac-vrf* creates its own bridging table and associated broadcast domains, based on the interfaces added to it. This can be thought of as an instantiation of a virtual switch within the node.

/// admonition | Default network instance
    type: subtle-note
There is a special IP-VRF network instance named **Default** that is analogous to the global routing table on Cisco/Arista devices or inet.0 on Junos devices.  
As a consequence, there can only be one network instance of named `default` in the system.
///

Since there is no default network instance defined in the SR Linux's factory config, there is no global routing table and no connectivity even though point-to-point addresses have been configured.  
This is an interesting paradigm shift - us network engineers typically work the base assumption that the default routing table is just there. With SR Linux, all intent is defined by the user, even something as simple as a default (global) routing table (network instance). Let's configure this now, as shown below, using leaf1 as a reference.

```srl
--{ + running }--[  ]--
A:leaf1# enter candidate

--{ +* candidate shared default }--[  ]--
A:leaf1# set network-instance default interface ethernet-1/1.0

--{ + candidate shared default }--[  ]--
A:leaf1# set network-instance default interface ethernet-1/2.0

--{ +* candidate shared default }--[  ]--
A:leaf1# diff /
+     network-instance default {
+         interface ethernet-1/1.0 {
+         }
+         interface ethernet-1/2.0 {
+         }
+     }

--{ +* candidate shared default }--[  ]--
A:leaf1# commit now
All changes have been committed. Leaving candidate mode.
```

Note, how we combined the Default network instance creation with the placement of the ethernet interfaces in a single command.

All interconnections between the leafs and the spines are configured in a similar fashion using `/31` IPv4 addresses and mapped to the default network instance. This routing table can now be viewed using the running mode command show network-instance default route-table all`.

```srl
--{ + running }--[  ]--
A:leaf1# show network-instance default route-table all
------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance default
------------------------------------------------------------------------------------------------------------------------------
+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+
| Prefix  |   ID    |  Route  |  Route  | Active  | Origin  | Metric  |  Pref   |  Next-  |  Next-  | Backup  | Backup  |
|         |         |  Type   |  Owner  |         | Network |         |         |   hop   | hop Int |  Next-  |  Next-  |
|         |         |         |         |         | Instanc |         |         | (Type)  | erface  |   hop   | hop Int |
|         |         |         |         |         |    e    |         |         |         |         | (Type)  | erface  |
+=========+=========+=========+=========+=========+=========+=========+=========+=========+=========+=========+=========+
| 198.51. | 2       | local   | net_ins | True    | default | 0       | 0       | 198.51. | etherne |         |         |
| 100.0/3 |         |         | t_mgr   |         |         |         |         | 100.0 ( | t-1/1.0 |         |         |
| 1       |         |         |         |         |         |         |         | direct) |         |         |         |
| 198.51. | 2       | host    | net_ins | True    | default | 0       | 0       | None (e | None    |         |         |
| 100.0/3 |         |         | t_mgr   |         |         |         |         | xtract) |         |         |         |
| 2       |         |         |         |         |         |         |         |         |         |         |         |
| 198.51. | 3       | local   | net_ins | True    | default | 0       | 0       | 198.51. | etherne |         |         |
| 100.2/3 |         |         | t_mgr   |         |         |         |         | 100.2 ( | t-1/2.0 |         |         |
| 1       |         |         |         |         |         |         |         | direct) |         |         |         |
| 198.51. | 3       | host    | net_ins | True    | default | 0       | 0       | None (e | None    |         |         |
| 100.2/3 |         |         | t_mgr   |         |         |         |         | xtract) |         |         |         |
| 2       |         |         |         |         |         |         |         |         |         |         |         |
+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+---------+
------------------------------------------------------------------------------------------------------------------------------
IPv4 routes total                    : 4
IPv4 prefixes with active routes     : 4
IPv4 prefixes with active ECMP routes: 0
------------------------------------------------------------------------------------------------------------------------------
```

We can confirm that the nodes can talk to each other by using the `ping` operational command (and specifying that the default network-instance is to be used for it) and testing reachability, as shown below from the perspective of leaf1 and leaf2, once all nodes have been configured with their respective point-to-point IPv4 addresses.

```srl
--{ + running }--[  ]--
A:leaf1# ping network-instance default 198.51.100.1
Using network instance default
PING 198.51.100.1 (198.51.100.1) 56(84) bytes of data.
64 bytes from 198.51.100.1: icmp_seq=1 ttl=64 time=4.12 ms
64 bytes from 198.51.100.1: icmp_seq=2 ttl=64 time=3.73 ms

--{ + running }--[  ]--
A:leaf1# ping network-instance default 198.51.100.3
Using network instance default
PING 198.51.100.3 (198.51.100.3) 56(84) bytes of data.
64 bytes from 198.51.100.3: icmp_seq=1 ttl=64 time=84.1 ms
64 bytes from 198.51.100.3: icmp_seq=2 ttl=64 time=2.86 ms

--{ + running }--[  ]--
A:leaf2# ping network-instance default 198.51.100.5
Using network instance default
PING 198.51.100.5 (198.51.100.5) 56(84) bytes of data.
64 bytes from 198.51.100.5: icmp_seq=1 ttl=64 time=17.2 ms
64 bytes from 198.51.100.5: icmp_seq=2 ttl=64 time=4.16 ms

--{ + running }--[  ]--
A:leaf2# ping network-instance default 198.51.100.7
Using network instance default
PING 198.51.100.7 (198.51.100.7) 56(84) bytes of data.
64 bytes from 198.51.100.7: icmp_seq=1 ttl=64 time=29.9 ms
64 bytes from 198.51.100.7: icmp_seq=2 ttl=64 time=4.00 ms
64 bytes from 198.51.100.7: icmp_seq=3 ttl=64 time=4.13 ms
```

### MAC VRFs for Layer 2 bridging

A MAC VRF, in SR Linux, is another type of network instance, that instantiates a virtual switch with a bridge/switching table, storing MAC addresses and their required forwarding instructions. This is how Layer 2 services attach themselves to the node, with the MAC VRF facilitating Layer 2 forwarding. The logic behind Layer 2 interfaces is the same - however, the subinterface is instantiated as a *bridged* type instead of an address family such as IPv4. In our case, ethernet-1/3 on leaf1 is connected to host `h1`. Let's configure this first.

```srl
--{ + candidate shared default }--[  ]--
A:leaf1# set interface ethernet-1/3 admin-state enable

--{ +* candidate shared default }--[  ]--
A:leaf1# set interface ethernet-1/3 vlan-tagging false

--{ +* candidate shared default }--[  ]--
A:leaf1# set interface ethernet-1/3 subinterface 0 type bridged
```

Breaking this down - the `vlan-tagging` parameter controls whether the physical interface expects tagged traffic or not. Since this is set to false, only untagged traffic is accepted on any subinterface and any tagged traffic is discarded. If the Layer 2 interface is expected to handle untagged and tagged traffic, then the `vlan-tagging` parameter can be set to true and additional subinterfaces can be configured with a tagged VLAN ID while the untagged subinterface can be configured as `set interface [intf-num] subinterface [subintf-num] vlan encap untagged`.

Again, this is a bit of a paradigm shift between more traditional network operating systems and SR Linux - traditionally, untagged interfaces are categorized as *access* interfaces, defined with a specific VLAN ID using commands such as `switchport access vlan [vlan-num]`. On SR Linux, the untagged VLAN is irrelevant since the forwarding of traffic is controlled purely by which interfaces are attached to the same MAC VRF (which acts as the bridge domain) rather than a VLAN identifier.

/// admonition | VLANs on SR Linux
    type: subtle-note
For a deep dive on VLANs on SR Linux topic, please see the [VLANs on SR Linux](srl-vlans.md) blog post.
///

On its own, this interface is doing nothing - it must be attached to a MAC VRF in order to participate in active Layer 2 forwarding. So, let's create a new network instance of type *mac-vrf* next and attach ethernet-1/3 to it.

```srl
--{ + candidate shared default }--[  ]--
A:leaf1# set network-instance macvrf1 type mac-vrf

--{ +* candidate shared default }--[  ]--
A:leaf1# set network-instance macvrf1 admin-state enable

--{ +* candidate shared default }--[  ]--
A:leaf1# set network-instance macvrf1 interface ethernet-1/3.0
```

Our goal is to provide inter-subnet connectivity for these servers so an IRB interface is created next. This is similar to Junos where the interface naming convention follows irb*x*, where *x* is the IRB number. The IRB interface is associated to the MAC VRF, tying it into the bridge domain hosted by that MAC VRF. This is shown below, using leaf1 as a reference for host h1's connectivity (remember to add the IRB interface in the default network instance).

```srl
--{ + candidate shared default }--[  ]--
A:leaf1# set interface irb1 admin-state enable

--{ +* candidate shared default }--[  ]--
A:leaf1# set interface irb1 subinterface 0 admin-state enable

--{ +* candidate shared default }--[  ]--
A:leaf1# set interface irb1 subinterface 0 ipv4 admin-state enable

--{ +* candidate shared default }--[  ]--
A:leaf1# set interface irb1 subinterface 0 ipv4 address 172.16.10.254/24

--{ + candidate shared default }--[  ]--
A:leaf1# set network-instance default interface irb1.0

--{ +* candidate shared default }--[  ]--
A:leaf1# set network-instance macvrf1 interface irb1.0

--{ +* candidate shared default }--[  ]--
A:leaf1# commit now
All changes have been committed. Leaving candidate mode.
```

Once these changes are committed, the server s1 can ping its gateway (the IRB interface on leaf1), and we can confirm that IP address is successfully resolved to a MAC address using the `show arpnd arp-entries` command. You can also view the MAC address table using the `show network-instance default bridge-table mac-table all` command, as shown below. Remember that the switching table is instantiated as part of the MAC VRF and thus, the network-instance used must be the MAC VRF in question.

```srl
--{ + running }--[  ]--
A:leaf1# ping network-instance default 172.16.10.1
Using network instance default
PING 172.16.10.1 (172.16.10.1) 56(84) bytes of data.
64 bytes from 172.16.10.1: icmp_seq=1 ttl=64 time=4.25 ms
64 bytes from 172.16.10.1: icmp_seq=2 ttl=64 time=2.03 ms

--{ + running }--[  ]--
A:leaf1# show arpnd arp-entries ipv4-address 172.16.10.1
+------------+------------+----------------+------------+----------------------+-------------------------------------------+
| Interface  | Subinterfa |    Neighbor    |   Origin   |  Link layer address  |                  Expiry                   |
|            |     ce     |                |            |                      |                                           |
+============+============+================+============+======================+===========================================+
| irb1       |          0 |    172.16.10.1 |    dynamic | AA:C1:AB:ED:BB:41    | 3 hours from now                          |
+------------+------------+----------------+------------+----------------------+-------------------------------------------+
------------------------------------------------------------------------------------------------------------------------------
  Total entries : 1 (0 static, 1 dynamic)
------------------------------------------------------------------------------------------------------------------------------

--{ + running }--[  ]--
A:leaf1# show network-instance macvrf1 bridge-table mac-table all
------------------------------------------------------------------------------------------------------------------------------
Mac-table of network instance macvrf1
------------------------------------------------------------------------------------------------------------------------------
+-------------------+------------------------------+-----------+---------+--------+-------+------------------------------+
|      Address      |         Destination          |   Dest    |  Type   | Active | Aging |         Last Update          |
|                   |                              |   Index   |         |        |       |                              |
+===================+==============================+===========+=========+========+=======+==============================+
| 1A:A5:02:FF:00:42 | irb-interface                | 0         | irb-int | true   | N/A   | 2024-09-20T17:47:40.000Z     |
|                   |                              |           | erface  |        |       |                              |
| AA:C1:AB:ED:BB:41 | ethernet-1/3.0               | 4         | learnt  | true   | 254   | 2024-09-21T07:04:09.000Z     |
+-------------------+------------------------------+-----------+---------+--------+-------+------------------------------+
Total Irb Macs                 :    1 Total    1 Active
Total Static Macs              :    0 Total    0 Active
Total Duplicate Macs           :    0 Total    0 Active
Total Learnt Macs              :    1 Total    1 Active
Total Evpn Macs                :    0 Total    0 Active
Total Evpn static Macs         :    0 Total    0 Active
Total Irb anycast Macs         :    0 Total    0 Active
Total Proxy Antispoof Macs     :    0 Total    0 Active
Total Reserved Macs            :    0 Total    0 Active
Total Eth-cfm Macs             :    0 Total    0 Active
Total Irb Vrrps                :    0 Total    0 Active
```

## Configuring BGP in SR Linux

Since we want BGP for the global routing table, it needs to be configured for the default network instance. This implies that all configuration for BGP will be under the `network-instance default` hierarchy. The configuration for BGP is fairly straightforward, following similar logic as any other vendor. A peer-group is created to group together common attributes for the peering.  
In addition to this, by default, eBGP in SR Linux does not export or import any routes as per the internet routing best practices and [RFC 8121](https://datatracker.ietf.org/doc/html/rfc8212). Explicit policies must be configured for this (included in the configuration below). This behavior can be changed using the `protocols bgp ebgp-default-policy` option.

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf1# enter candidate

--{ + candidate shared default }--[  ]--
A:leaf1# set network-instance default protocols bgp autonomous-system 65421

--{ +* candidate shared default }--[  ]--
A:leaf1# set network-instance default protocols bgp router-id 192.0.2.11

--{ +* candidate shared default }--[  ]--
A:leaf1# set network-instance default protocols bgp afi-safi ipv4-unicast admin-state enable

--{ +* candidate shared default }--[  ]--
A:leaf1# set network-instance default protocols bgp group spine-underlay peer-as 65500

--{ +* candidate shared default }--[  ]--
A:leaf1# set network-instance default protocols bgp group spine-underlay export-policy [direct-only]

--{ +* candidate shared default }--[  ]--
A:leaf1# set network-instance default protocols bgp group spine-underlay import-policy [bgp-only]

--{ +* candidate shared default }--[  ]--
A:leaf1# set network-instance default protocols bgp neighbor 198.51.100.1 peer-group spine-underlay

--{ +* candidate shared default }--[  ]--
A:leaf1# set network-instance default protocols bgp neighbor 198.51.100.3 peer-group spine-underlay

--{ +* candidate shared default }--[  ]--
A:leaf1# set routing-policy policy direct-only default-action policy-result reject

--{ +* candidate shared default }--[  ]--
A:leaf1# set routing-policy policy direct-only statement direct-routes-only match protocol local

--{ +* candidate shared default }--[  ]--
A:leaf1# set routing-policy policy direct-only statement direct-routes-only action policy-result accept

--{ + candidate shared default }--[  ]--
A:leaf1# set routing-policy policy bgp-only default-action policy-result reject

--{ +* candidate shared default }--[  ]--
A:leaf1# set routing-policy policy bgp-only statement bgp-routes-only match protocol bgp

--{ +* candidate shared default }--[  ]--
A:leaf1# set routing-policy policy bgp-only statement bgp-routes-only action policy-result accept

--{ +* candidate shared default }--[  ]--
A:leaf1# commit now
All changes have been committed. Leaving candidate mode.
```

The above configuration does the following:

1. It sets the ASN and router ID for the local node.
2. It enables the IPv4 unicast AFI/SAFI by setting the `admin-state` to enable.
3. It creates a peer-group called `spine-underlay` and sets several common parameters for this group, including the peer ASN and an import/export policy that controls which routes are exported to neighbors and which routes are imported from neighbors. These policies are created using the `routing-policy` hierarchy.

Once all peers are configured in a similar fashion, leaf1 and leaf2 establish eBGP peering with spine1 and spine2, as shown below.

```srl
--{ + running }--[  ]--
A:leaf1# show network-instance default protocols bgp neighbor
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+--------------------+------------------------------+--------------------+-------+-----------+----------------+----------------+---------------+------------------------------+
|      Net-Inst      |             Peer             |       Group        | Flags |  Peer-AS  |     State      |     Uptime     |   AFI/SAFI    |        [Rx/Active/Tx]        |
+====================+==============================+====================+=======+===========+================+================+===============+==============================+
| default            | 198.51.100.1                 | spine-underlay     | S     | 65500     | established    | 0d:0h:55m:58s  | ipv4-unicast  | [2/2/3]                      |
| default            | 198.51.100.3                 | spine-underlay     | S     | 65500     | established    | 0d:0h:52m:17s  | ipv4-unicast  | [2/1/3]                      |
+--------------------+------------------------------+--------------------+-------+-----------+----------------+----------------+---------------+------------------------------+
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Summary:
2 configured neighbors, 2 configured sessions are established, 0 disabled peers
0 dynamic peers

--{ + running }--[  ]--
A:leaf2# show network-instance default protocols bgp neighbor
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+--------------------+------------------------------+--------------------+-------+-----------+----------------+----------------+---------------+------------------------------+
|      Net-Inst      |             Peer             |       Group        | Flags |  Peer-AS  |     State      |     Uptime     |   AFI/SAFI    |        [Rx/Active/Tx]        |
+====================+==============================+====================+=======+===========+================+================+===============+==============================+
| default            | 198.51.100.5                 | spine-underlay     | S     | 65500     | established    | 0d:0h:48m:4s   | ipv4-unicast  | [2/2/3]                      |
| default            | 198.51.100.7                 | spine-underlay     | S     | 65500     | established    | 0d:0h:48m:28s  | ipv4-unicast  | [2/1/3]                      |
+--------------------+------------------------------+--------------------+-------+-----------+----------------+----------------+---------------+------------------------------+
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Summary:
2 configured neighbors, 2 configured sessions are established, 0 disabled peers
0 dynamic peers
```

The routes advertised by a node can be viewed using the `advertised-routes` option. In our case, leaf1 should be advertising the `172.16.10.0/24` prefix and leaf2 should be advertising the `172.16.20.0/24` prefix to the spines. This is confirmed as shown below.

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf1# show network-instance default protocols bgp neighbor 198.51.100.1 advertised-routes ipv4
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Peer        : 198.51.100.1, remote AS: 65500, local AS: 65421
Type        : static
Description : None
Group       : spine-underlay
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Origin codes: i=IGP, e=EGP, ?=incomplete
+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|             Network                        Path-id               Next Hop             MED                             LocPref                            AsPath           Origin     |
+======================================================================================================================================================================================+
| 172.16.10.0/24                     0                          198.51.100.0             -                                                             [65421]                 i       |
| 198.51.100.0/31                    0                          198.51.100.0             -                                                             [65421]                 i       |
| 198.51.100.2/31                    0                          198.51.100.0             -                                                             [65421]                 i       |
+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
3 advertised BGP routes
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--{ + running }--[  ]--
A:leaf2# show network-instance default protocols bgp neighbor 198.51.100.5 advertised-routes ipv4
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Peer        : 198.51.100.5, remote AS: 65500, local AS: 65422
Type        : static
Description : None
Group       : spine-underlay
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Origin codes: i=IGP, e=EGP, ?=incomplete
+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|             Network                        Path-id               Next Hop             MED                             LocPref                            AsPath           Origin     |
+======================================================================================================================================================================================+
| 172.16.20.0/24                     0                          198.51.100.4             -                                                             [65422]                 i       |
| 198.51.100.4/31                    0                          198.51.100.4             -                                                             [65422]                 i       |
| 198.51.100.6/31                    0                          198.51.100.4             -                                                             [65422]                 i       |
+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
3 advertised BGP routes
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

Eventually, each leaf will receive the other leaf's advertised route and install it in the default network-instance routing table. This can be confirmed using the `show network-instance default route-table ipv4-unicast [summary|prefix]` command.

```srl
--{ + running }--[  ]--
A:leaf1# show network-instance default route-table ipv4-unicast prefix 172.16.20.0/24
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance default
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+----------------------------+-------+------------+----------------------+----------+----------+---------+------------+------------------+------------------+------------------+-------------------------+
|           Prefix           |  ID   | Route Type |     Route Owner      |  Active  |  Origin  | Metric  |    Pref    | Next-hop (Type)  |     Next-hop     | Backup Next-hop  |     Backup Next-hop     |
|                            |       |            |                      |          | Network  |         |            |                  |    Interface     |      (Type)      |        Interface        |
|                            |       |            |                      |          | Instance |         |            |                  |                  |                  |                         |
+============================+=======+============+======================+==========+==========+=========+============+==================+==================+==================+=========================+
| 172.16.20.0/24             | 0     | bgp        | bgp_mgr              | True     | default  | 0       | 170        | 198.51.100.0/31  | ethernet-1/1.0   |                  |                         |
|                            |       |            |                      |          |          |         |            | (indirect/local) |                  |                  |                         |
+----------------------------+-------+------------+----------------------+----------+----------+---------+------------+------------------+------------------+------------------+-------------------------+
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--{ + running }--[  ]--
A:leaf2# show network-instance default route-table ipv4-unicast prefix 172.16.10.0/24
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance default
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+----------------------------+-------+------------+----------------------+----------+----------+---------+------------+------------------+------------------+------------------+-------------------------+
|           Prefix           |  ID   | Route Type |     Route Owner      |  Active  |  Origin  | Metric  |    Pref    | Next-hop (Type)  |     Next-hop     | Backup Next-hop  |     Backup Next-hop     |
|                            |       |            |                      |          | Network  |         |            |                  |    Interface     |      (Type)      |        Interface        |
|                            |       |            |                      |          | Instance |         |            |                  |                  |                  |                         |
+============================+=======+============+======================+==========+==========+=========+============+==================+==================+==================+=========================+
| 172.16.10.0/24             | 0     | bgp        | bgp_mgr              | True     | default  | 0       | 170        | 198.51.100.4/31  | ethernet-1/1.0   |                  |                         |
|                            |       |            |                      |          |          |         |            | (indirect/local) |                  |                  |                         |
+----------------------------+-------+------------+----------------------+----------+----------+---------+------------+------------------+------------------+------------------+-------------------------+
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

With the routes correctly programmed, hosts h1 can communicate with h2, confirming that our end network state is achieved.

```
root@h1:~# ping 172.16.20.2
PING 172.16.20.1 (172.16.20.1) 56(84) bytes of data.
64 bytes from 172.16.20.2: icmp_seq=1 ttl=61 time=1.48 ms
64 bytes from 172.16.20.2: icmp_seq=2 ttl=61 time=0.996 ms
64 bytes from 172.16.20.2: icmp_seq=3 ttl=61 time=1.03 ms
64 bytes from 172.16.20.2: icmp_seq=4 ttl=61 time=1.11 ms
^C
--- 172.16.20.2 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 6ms
rtt min/avg/max/mdev = 0.996/1.153/1.475/0.191 ms
```

## Closing thoughts and random coolness with SR Linux

Learning new technology can be hard. It's in our nature to avoid change when old is comfortable. Unfortunately, the one constant with technology is that it evolves. Designs change. What might be considered efficient and ideal in the past may no longer be so today. SR Linux is no different. It's foreign until it's not. There's a reason it's different - it was built to cater to the changing demands of how network infrastructure is built and operated, ensuring that automation is no longer a second-class citizen. This also implies that if you take the time to learn it, the rewards make you far richer.

### Outputs as YAML, JSON or table with chosen fields only

The automation-friendly nature of SR Linux is no joke. Any output can be reinterpreted in YAML or JSON (or even as a table dumping specific fields only for an easier CLI view of the data).

```srl
--{ + running }--[  ]--
A:leaf1# show network-instance default route-table ipv4-unicast prefix 172.16.20.0/24 | as yaml
---
instance:
  - Name: default
    ip route:
      - Prefix: 172.16.20.0/24
      - ID: 0
      - Route Type: bgp
      - Route Owner: bgp_mgr
      - Active: True
        Origin Network Instance: default
        Metric: 0
        Pref: 170
        Next-hop (Type): 198.51.100.0/31 (indirect/local)
        Next-hop Interface: ethernet-1/1.0
        Backup Next-hop (Type):
        Backup Next-hop Interface:

--{ + running }--[  ]--
A:leaf1# show network-instance default route-table ipv4-unicast prefix 172.16.20.0/24 | as json
{
  "instance": [
    {
      "Name": "default",
      "ip route": [
        {
          "Prefix": "172.16.20.0/24",
          "ID": 0,
          "Route Type": "bgp",
          "Route Owner": "bgp_mgr",
          "Active": "True",
          "Origin Network Instance": "default",
          "Metric": 0,
          "Pref": 170,
          "Next-hop (Type)": "198.51.100.0/31 (indirect/local)",
          "Next-hop Interface": "ethernet-1/1.0 ",
          "Backup Next-hop (Type)": "",
          "Backup Next-hop Interface": ""
        }
      ]
    }
  ]
}
```

### Watching for changes

With the `watch` command, you can watch for changes in state. For example, changes to BGP neighbor state or interface statistics (by default, this runs every 2s).

```
--{ + running }--[  ]--
A:leaf1# watch info from state interface ethernet-1/1 statistics
Every 2.0s: info from state interface ethernet-1/1 statistics                                (Executions 3, Sat 11:40:42AM)

    interface ethernet-1/1 {
        statistics {
            in-packets 6120
            in-octets 997159
            in-unicast-packets 354
            in-broadcast-packets 6
            in-multicast-packets 5737
            in-discarded-packets 23
            in-error-packets 0
            in-fcs-error-packets 0
            out-packets 6093
            out-octets 984102
            out-mirror-octets 0
            out-unicast-packets 373
            out-broadcast-packets 6
            out-multicast-packets 5714
            out-discarded-packets 0
            out-error-packets 0
            out-mirror-packets 0
            carrier-transitions 0
            last-clear "2024-09-19T12:03:49.079Z (a day ago)"
        }
    }
```

There are many more cool and unique features of SR Linux that we covered in our tutorials, blogs, and videos. Stay tuned for more content and join our [community](https://discord.gg/tZvgjQ6PZf) to get involved.
