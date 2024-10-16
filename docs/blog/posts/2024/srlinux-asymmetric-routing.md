---
date: 2024-10-14
tags:
    - bgp
    - evpn
authors:
    - aninda
links:
    - EVPN Multihoming tutorial: tutorials/evpn-mh/basics/index.md
    - Basic L2 EVPN tutorial: tutorials/l2evpn/intro.md
---

# Asymmetric routing with SR Linux in EVPN VXLAN fabrics

This post dives deeper into the asymmetric routing model[^1] for EVPN VXLAN fabrics on SR Linux.  
The topology in use is a 3-stage Clos fabric with BGP EVPN and VXLAN, with

* server `s1` single-homed to `leaf1`
* `s2` dual-homed to leaf2 and `leaf3`
* and `s3` single-homed to `leaf4`.

Servers s1 and s2 are in the same subnet, 172.16.10.0/24 while s3 is in a different subnet, 172.16.20.0/24. Thus, this post demonstrates Layer 2 extension over a routed fabric as well as how Layer 3 services are deployed over the same fabric, with an asymmetric routing model.

The physical topology is shown below:

![](https://gitlab.com/aninchat1/images/-/wikis/uploads/1d3750d935d534973fc913e3a3a68c49/srlinux-asymmetric-1.png)

<!-- more -->

The [Containerlab](https://containerlab.dev) topology file used for this is shown below:

```{.yaml .code-scroll-lg}
name: srlinux-asymmetric-routing
prefix: ""

topology:
  defaults:
    kind: nokia_srlinux
    image: ghcr.io/nokia/srlinux:24.7.1
  nodes:
    spine1:
    spine2:
    leaf1:
    leaf2:
    leaf3:
    leaf4:

    s1:
      kind: linux
      image: ghcr.io/srl-labs/network-multitool
      exec:
        - ip addr add 172.16.10.1/24 dev eth1
        - ip route add 172.16.20.0/24 via 172.16.10.254
    s2:
      kind: linux
      image: ghcr.io/srl-labs/network-multitool
      exec:
        - ip link add bond0 type bond mode 802.3ad
        - ip link set eth1 down 
        - ip link set eth2 down 
        - ip link set eth1 master bond0
        - ip link set eth2 master bond0
        - ip addr add 172.16.10.2/24 dev bond0
        - ip link set eth1 up
        - ip link set eth2 up
        - ip link set bond0 up
        - ip route add 172.16.20.0/24 via 172.16.10.254
    s3:
      kind: linux
      image: ghcr.io/srl-labs/network-multitool
      exec:
        - ip addr add 172.16.20.3/24 dev eth1
        - ip route add 172.16.10.0/24 via 172.16.20.254
  links:
    - endpoints: ["leaf1:e1-1", "spine1:e1-1"]
    - endpoints: ["leaf1:e1-2", "spine2:e1-1"]
    - endpoints: ["leaf2:e1-1", "spine1:e1-2"]
    - endpoints: ["leaf2:e1-2", "spine2:e1-2"]
    - endpoints: ["leaf3:e1-1", "spine1:e1-3"]
    - endpoints: ["leaf3:e1-2", "spine2:e1-3"]
    - endpoints: ["leaf4:e1-1", "spine1:e1-4"]
    - endpoints: ["leaf4:e1-2", "spine2:e1-4"]
    - endpoints: ["leaf1:e1-3", "s1:eth1"]
    - endpoints: ["leaf2:e1-3", "s2:eth1"]
    - endpoints: ["leaf3:e1-3", "s2:eth2"]
    - endpoints: ["leaf4:e1-3", "s3:eth1"]
```

/// admonition | Notes
    type: subtle-note
<h4>SR Linux version</h4>
Configuration snippets and outputs in this post are based on SR Linux 24.7.1.
<h4>Credentials</h4>
As usual, Nokia SR Linux nodes can be accessed with `admin:NokiaSrl1!` credentials and the host nodes use `user:multit00l`.
///

The end goal of this post is to ensure that server s1 can communicate with both s2 (same subnet) and s3 (different subnet) using an asymmetric routing model. To that end, the following IPv4 addressing is used (with the IRB addressing following a distributed, anycast model):

|      Resource       |    IPv4 scope    |
| :-----------------: | :--------------: |
|      Underlay       | 198.51.100.0/24  |
| `system0` interface |   192.0.2.0/24   |
|      VNI 10010      |  172.16.10.0/24  |
|      VNI 10020      |  172.16.20.0/24  |
|      server s1      |  172.16.10.1/24  |
|      server s2      |  172.16.10.2/24  |
|      server s3      |  172.16.20.3/24  |
| `irb0.10` interface | 172.16.10.254/24 |
| `irb0.20` interface | 172.16.20.254/24 |

## Reviewing the asymmetric routing model

When routing between VNIs, in a VXLAN fabric, there are two major routing models that can be used - asymmetric and symmetric. Asymmetric routing, which is the focus of this post, uses a `bridge-route-bridge` model, implying that the ingress leaf bridges the packet into the Layer 2 domain, routes it from one VLAN/VNI to another and then bridges the packet across the VXLAN fabric to the destination. The *asymmetry* is in the the number of lookups needed on the ingress and the egress leafs - on the ingress leaf, a MAC lookup, an IP lookup and then another MAC lookup is performed while on the egress leaf, only a MAC lookup is performed.

/// note
Asymmetric and symmetric routing models are defined in [RFC 9135](https://datatracker.ietf.org/doc/html/rfc9135).
///

Such a design naturally implies that both the source and the destination IRBs (and the corresponding Layer 2 domains and bridge tables) must exist on all leafs hosting servers that need to communicate with each other. While this increases the operational state on the leafs themselves (ARP state and MAC address state is stored everywhere), it does offer operational simplicity.  
This is because unlike symmetric routing, there is no concept of a `L3VNI` here, which keeps the routing complexity to a minimum, and analogous to traditional inter-VLAN routing, only with a VXLAN-encapsulation, in this case. No additional VLANs/VNIs need to be configured (for L3VNIs, which are typically mapped per IP VRF), making this a simpler solution to implement and operate. The obvious drawbacks of this approach, however, is that VLANs/VNIs cannot be scoped to specific leafs only - they must exist across all leafs that want to participate in inter-VNI routing, which contributes to the scalability considerations.

![](https://gitlab.com/aninchat1/images/-/wikis/uploads/f93957318e62633db1c8603dbef57b69/srlinux-asymmetric-2.png)

## Configuration walkthrough

With a basic understanding of the asymmetric routing model, let's start to configure this fabric. This configuration walkthrough includes building out the entire fabric from scratch - only the base configuration, loaded with Containerlab by default, exists on all nodes.

### Point-to-point interfaces

The underlay of the fabric includes the physically connected point-to-point interfaces between the leafs and the spines, the IPv4/IPv6 addressing used for these interfaces and a routing protocol, deployed to distribute the loopback (system0) addresses across the fabric, with the simple end goal of achieving reachability between these loopback addresses. The configuration for these point-to-point addresses is shown below from all the nodes.

/// tab | leaf1

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf1# info interface ethernet-1/{1,2}
    interface ethernet-1/1 {
        admin-state enable
        mtu 9100
        subinterface 0 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 198.51.100.0/31 {
                }
            }
        }
    }
    interface ethernet-1/2 {
        admin-state enable
        mtu 9100
        subinterface 0 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 198.51.100.2/31 {
                }
            }
        }
    }
```

///

/// tab | leaf2

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf2# info interface ethernet-1/{1,2}
    interface ethernet-1/1 {
        admin-state enable
        mtu 9100
        subinterface 0 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 198.51.100.4/31 {
                }
            }
        }
    }
    interface ethernet-1/2 {
        admin-state enable
        mtu 9100
        subinterface 0 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 198.51.100.6/31 {
                }
            }
        }
    }
```

///

/// tab | leaf3

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf3# info interface ethernet-1/{1,2}
    interface ethernet-1/1 {
        admin-state enable
        mtu 9100
        subinterface 0 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 198.51.100.8/31 {
                }
            }
        }
    }
    interface ethernet-1/2 {
        admin-state enable
        mtu 9100
        subinterface 0 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 198.51.100.10/31 {
                }
            }
        }
    }
```

///

/// tab | leaf4

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf4# info interface ethernet-1/{1,2}
    interface ethernet-1/1 {
        admin-state enable
        mtu 9100
        subinterface 0 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 198.51.100.12/31 {
                }
            }
        }
    }
    interface ethernet-1/2 {
        admin-state enable
        mtu 9100
        subinterface 0 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 198.51.100.14/31 {
                }
            }
        }
    }
```

///

/// tab | spine1

```{.srl .code-scroll-lg}
A:spine1# info interface ethernet-1/{1..4}
    interface ethernet-1/1 {
        admin-state enable
        mtu 9100
        subinterface 0 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 198.51.100.1/31 {
                }
            }
        }
    }
    interface ethernet-1/2 {
        admin-state enable
        mtu 9100
        subinterface 0 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 198.51.100.5/31 {
                }
            }
        }
    }
    interface ethernet-1/3 {
        admin-state enable
        mtu 9100
        subinterface 0 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 198.51.100.9/31 {
                }
            }
        }
    }
    interface ethernet-1/4 {
        admin-state enable
        mtu 9100
        subinterface 0 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 198.51.100.13/31 {
                }
            }
        }
    }
```

///

/// tab | spine2

```{.srl .code-scroll-lg}
A:spine2# info interface ethernet-1/{1..4}
    interface ethernet-1/1 {
        admin-state enable
        mtu 9100
        subinterface 0 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 198.51.100.3/31 {
                }
            }
        }
    }
    interface ethernet-1/2 {
        admin-state enable
        mtu 9100
        subinterface 0 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 198.51.100.7/31 {
                }
            }
        }
    }
    interface ethernet-1/3 {
        admin-state enable
        mtu 9100
        subinterface 0 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 198.51.100.11/31 {
                }
            }
        }
    }
    interface ethernet-1/4 {
        admin-state enable
        mtu 9100
        subinterface 0 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 198.51.100.15/31 {
                }
            }
        }
    }
```

///

/// admonition | CLI Ranges
    type: tip
Notice that configuration for multiple interfaces are shown with a single command using the concept of ranges.  
Different ways of using ranges are shown with one style used for the leafs and another for the spines. With `interface ethernet-1{1,2}`, the comma-separation allows the user to enter any set of numbers (contiguous or not), which are subsequently expanded. Thus, this expands to `interface ethernet-1/1` and `interface ethernet-1/2`.

On the other hand, you can also provide a contiguous range of numbers by using `..`, as shown for the spines. In that case, `interface ethernet-1/{1..4}` implies ethernet-1/1 through ethernet-1/4.

Check out a separate post on [CLI Ranges and Wildcards](../2023/cli-ranges.md).
///

Remember, by default, there is no global routing instance/table in SR Linux. A `network-instance` with named `default` must be configured and these interfaces, including the `system0` interface need to be added to this network instance for point-to-point connectivity.

### Underlay and overlay BGP

For the underlay, eBGP is used to advertise the `system0` interface addresses. However, since SR Linux has adapted eBGP behavior specifically for the L2VPN EVPN AFI/SAFI (no modification of next-hop address at every eBGP hop and the default use of `system0` interface address as the next-hop when originating a route instead of the Layer 3 interface address over which the peering is formed), we can simply enable this address-family over the same peering (leveraging MP-BGP functionality). BGP is configured under the default `network-instance` since this is for the underlay in the global routing table.

The BGP configuration from all nodes is shown below:

/// tab | leaf1

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf1# info network-instance default protocols bgp
    network-instance default {
        protocols {
            bgp {
                admin-state enable
                autonomous-system 65411
                router-id 192.0.2.11
                afi-safi evpn {
                    admin-state enable
                }
                afi-safi ipv4-unicast {
                    admin-state enable
                    multipath {
                        maximum-paths 2
                    }
                }
                group spine {
                    peer-as 65500
                    export-policy [
                        spine-export
                    ]
                    import-policy [
                        spine-import
                    ]
                    afi-safi evpn {
                        admin-state enable
                    }
                    afi-safi ipv4-unicast {
                        admin-state enable
                    }
                }
                neighbor 198.51.100.1 {
                    peer-group spine
                }
                neighbor 198.51.100.3 {
                    peer-group spine
                }
            }
        }
    }
```

///

/// tab | leaf2

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf2# info network-instance default protocols bgp
    network-instance default {
        protocols {
            bgp {
                admin-state enable
                autonomous-system 65412
                router-id 192.0.2.12
                afi-safi evpn {
                    admin-state enable
                }
                afi-safi ipv4-unicast {
                    admin-state enable
                    multipath {
                        maximum-paths 2
                    }
                }
                group spine {
                    peer-as 65500
                    export-policy [
                        spine-export
                    ]
                    import-policy [
                        spine-import
                    ]
                    afi-safi evpn {
                        admin-state enable
                    }
                    afi-safi ipv4-unicast {
                        admin-state enable
                    }
                }
                neighbor 198.51.100.5 {
                    peer-group spine
                }
                neighbor 198.51.100.7 {
                    peer-group spine
                }
            }
        }
    }
```

///

/// tab | leaf3

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf3# info network-instance default protocols bgp
    network-instance default {
        protocols {
            bgp {
                admin-state enable
                autonomous-system 65413
                router-id 192.0.2.13
                afi-safi evpn {
                    admin-state enable
                }
                afi-safi ipv4-unicast {
                    admin-state enable
                    multipath {
                        maximum-paths 2
                    }
                }
                group spine {
                    peer-as 65500
                    export-policy [
                        spine-export
                    ]
                    import-policy [
                        spine-import
                    ]
                    afi-safi evpn {
                        admin-state enable
                    }
                    afi-safi ipv4-unicast {
                        admin-state enable
                    }
                }
                neighbor 198.51.100.9 {
                    peer-group spine
                }
                neighbor 198.51.100.11 {
                    peer-group spine
                }
            }
        }
    }
```

///

/// tab | leaf4

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf4# info network-instance default protocols bgp
    network-instance default {
        protocols {
            bgp {
                admin-state enable
                autonomous-system 65414
                router-id 192.0.2.14
                afi-safi evpn {
                    admin-state enable
                }
                afi-safi ipv4-unicast {
                    admin-state enable
                    multipath {
                        maximum-paths 2
                    }
                }
                group spine {
                    peer-as 65500
                    export-policy [
                        spine-export
                    ]
                    import-policy [
                        spine-import
                    ]
                    afi-safi evpn {
                        admin-state enable
                    }
                    afi-safi ipv4-unicast {
                        admin-state enable
                    }
                }
                neighbor 198.51.100.13 {
                    peer-group spine
                }
                neighbor 198.51.100.15 {
                    peer-group spine
                }
            }
        }
    }
```

///

/// tab | spine1

```{.srl .code-scroll-lg}
--{ running }--[  ]--
A:spine1# info network-instance default protocols bgp
    network-instance default {
        protocols {
            bgp {
                admin-state enable
                autonomous-system 65500
                router-id 192.0.2.101
                afi-safi evpn {
                    admin-state enable
                    evpn {
                        inter-as-vpn true
                    }
                }
                afi-safi ipv4-unicast {
                    admin-state enable
                }
                group leaf {
                    export-policy [
                        leaf-export
                    ]
                    import-policy [
                        leaf-import
                    ]
                    afi-safi evpn {
                        admin-state enable
                    }
                    afi-safi ipv4-unicast {
                        admin-state enable
                    }
                }
                neighbor 198.51.100.0 {
                    peer-as 65411
                    peer-group leaf
                }
                neighbor 198.51.100.4 {
                    peer-as 65412
                    peer-group leaf
                }
                neighbor 198.51.100.8 {
                    peer-as 65413
                    peer-group leaf
                }
                neighbor 198.51.100.12 {
                    peer-as 65414
                    peer-group leaf
                }
            }
        }
    }
```

///

/// tab | spine2

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:spine2# info network-instance default protocols bgp
    network-instance default {
        protocols {
            bgp {
                admin-state enable
                autonomous-system 65500
                router-id 192.0.2.102
                afi-safi evpn {
                    admin-state enable
                    evpn {
                        inter-as-vpn true
                    }
                }
                afi-safi ipv4-unicast {
                    admin-state enable
                }
                group leaf {
                    export-policy [
                        leaf-export
                    ]
                    import-policy [
                        leaf-import
                    ]
                    afi-safi evpn {
                        admin-state enable
                    }
                    afi-safi ipv4-unicast {
                        admin-state enable
                    }
                }
                neighbor 198.51.100.2 {
                    peer-as 65411
                    peer-group leaf
                }
                neighbor 198.51.100.6 {
                    peer-as 65412
                    peer-group leaf
                }
                neighbor 198.51.100.10 {
                    peer-as 65413
                    peer-group leaf
                }
                neighbor 198.51.100.14 {
                    peer-as 65414
                    peer-group leaf
                }
            }
        }
    }
```

///

/// note
On the spines, the configuration option `inter-as-vpn` must be set to `true` under the `protocols bgp afi-safi evpn evpn` hierarchy. Since the spines are not configured as VTEPs and act as pure IP forwarders in this design, there are no Layer 2 or Layer 3 VXLAN constructs created on the spines, associated to any route targets for EVPN route import.

By default, such routes (which have no local route target for import) will be rejected and not advertised to other leafs. The `inter-as-vpn` configuration option overrides this behavior.
///
The BGP configuration defines a peer-group called `spine` on the leafs and `leaf` on the spines to build out common configuration that can be applied across multiple neighbors. These peer-groups enable both the IPv4-unicast and EVPN address-families, using MP-BGP to establish a single peering for both families. In addition to this, `export` and `import` policies are defined, controlling what routes are exported and imported.

The following packet capture also confirms the MP-BGP capabilities exchanged with the BGP OPEN messages, where both IPv4 unicast and L2VPN EVPN capabilities are advertised:

![](https://gitlab.com/aninchat1/images/-/wikis/uploads/a55a3e47da51d29386b372c2a1a790ee/srlinux-asymmetric-3.png)

### Routing policies for the underlay and overlay

The configuration of the routing policies used for export and import of BGP routes is shown below. Since the policies for the leafs are the same across all leafs and the policies for the spines are the same across all spines, the configuration is only shown from two nodes, leaf1 and spine1, using them as references.

/// tab | leaf1

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf1# info routing-policy policy spine-*
    routing-policy {
        policy spine-export {
            default-action {
                policy-result reject
            }
            statement loopback {
                match {
                    protocol local
                }
                action {
                    policy-result accept
                }
            }
            statement allow-evpn {
                match {
                    family [
                        evpn
                    ]
                }
                action {
                    policy-result accept
                }
            }
        }
        policy spine-import {
            default-action {
                policy-result reject
            }
            statement bgp-underlay {
                match {
                    protocol bgp
                    family [
                        ipv4-unicast
                        ipv6-unicast
                    ]
                }
                action {
                    policy-result accept
                }
            }
            statement bgp-evpn-overlay {
                match {
                    family [
                        evpn
                    ]
                }
                action {
                    policy-result accept
                }
            }
        }
    }
--{ + running }--[  ]--
```

///

/// tab | spine1

```{.srl .code-scroll-lg}
--{ running }--[  ]--
A:spine1# info routing-policy policy leaf-*
    routing-policy {
        policy leaf-export {
            default-action {
                policy-result reject
            }
            statement loopback {
                match {
                    protocol local
                }
                action {
                    policy-result accept
                }
            }
            statement bgp-underlay {
                match {
                    protocol bgp
                    family [
                        ipv4-unicast
                        ipv6-unicast
                    ]
                }
                action {
                    policy-result accept
                }
            }
            statement bgp-evpn-overlay {
                match {
                    family [
                        evpn
                    ]
                }
                action {
                    policy-result accept
                }
            }
        }
        policy leaf-import {
            default-action {
                policy-result reject
            }
            statement bgp-underlay {
                match {
                    protocol bgp
                    family [
                        ipv4-unicast
                        ipv6-unicast
                    ]
                }
                action {
                    policy-result accept
                }
            }
            statement bgp-evpn-overlay {
                match {
                    family [
                        evpn
                    ]
                }
                action {
                    policy-result accept
                }
            }
        }
    }
--{ running }--[  ]--
```

///

/// admonition | CLI Wildcards
    type: tip
Similar to how ranges can be used to pull configuration state from multiple interfaces as an example, in this case a wildcard `*` is used to select multiple routing-policies. The wildcard `spine-*` matches both policies named `spine-import` and `spine-export`.
///

### Host connectivity and LAG Ethernet Segment (ESI LAG)

With BGP configured, we can start to deploy the connectivity to the servers and configure the necessary VXLAN constructs for end-to-end connectivity. The interfaces, to the servers, are configured as untagged interfaces. Since host s2 is multi-homed to leaf2 and leaf3, this segment is configured as an ESI LAG. This includes:

1. Mapping the physical interface to a LAG interface (`lag1`, in this case).
2. The LAG interface configured with the required LACP properties - mode `active` and a system-mac of `00:00:00:00:23:23`. This LAG interface is also configured with a subinterface of type `bridged`.
3. An Ethernet Segment defined under the `system network-instance protocols evpn ethernet-segments` hierarchy.

/// tab | leaf1

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf1# info interface ethernet-1/3
    interface ethernet-1/3 {
        admin-state enable
        mtu 9100
        vlan-tagging false
        subinterface 0 {
            type bridged
            admin-state enable
        }
    }
--{ + running }--[  ]--
```

///

/// tab | leaf2

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf2# info interface ethernet-1/3
    interface ethernet-1/3 {
        admin-state enable
        ethernet {
            aggregate-id lag1
        }
    }
--{ + running }--[  ]--
```

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf2# info interface lag1
    interface lag1 {
        admin-state enable
        vlan-tagging false
        subinterface 0 {
            type bridged
            admin-state enable
        }
        lag {
            lag-type lacp
            lacp {
                lacp-mode ACTIVE
                system-id-mac 00:00:00:00:23:23
            }
        }
    }
--{ + running }--[  ]--
```

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf2# info system network-instance protocols evpn
    system {
        network-instance {
            protocols {
                evpn {
                    ethernet-segments {
                        bgp-instance 1 {
                            ethernet-segment es1 {
                                admin-state enable
                                esi 00:00:11:11:11:11:11:11:23:23
                                multi-homing-mode all-active
                                interface lag1 {
                                }
                            }
                        }
                    }
                }
            }
        }
    }
--{ + running }--[  ]--
```

///

/// tab | leaf3

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf3# info interface ethernet-1/3
    interface ethernet-1/3 {
        admin-state enable
        ethernet {
            aggregate-id lag1
        }
    }
--{ + running }--[  ]--
```

```{.srl .code-scroll-lg}
A:leaf3# info interface lag1
    interface lag1 {
        admin-state enable
        vlan-tagging false
        subinterface 0 {
            type bridged
            admin-state enable
        }
        lag {
            lag-type lacp
            lacp {
                lacp-mode ACTIVE
                system-id-mac 00:00:00:00:23:23
            }
        }
    }
--{ + running }--[  ]--
```

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf3# info system network-instance protocols evpn
    system {
        network-instance {
            protocols {
                evpn {
                    ethernet-segments {
                        bgp-instance 1 {
                            ethernet-segment es1 {
                                admin-state enable
                                esi 00:00:11:11:11:11:11:11:23:23
                                multi-homing-mode all-active
                                interface lag1 {
                                }
                            }
                        }
                    }
                }
            }
        }
    }
--{ + running }--[  ]--
```

///

/// tab | leaf4

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf4# info interface ethernet-1/3
    interface ethernet-1/3 {
        admin-state enable
        vlan-tagging false
        subinterface 0 {
            type bridged
            admin-state enable
        }
    }
```

///

### VXLAN tunnel interfaces

On each leaf, VXLAN tunnel-interfaces are created next. In this case, two logical interfaces are created, one for VNI 10010 and another for VNI 10020 (since this is asymmetric routing, all VNIs must exist on all leafs that want to route between the respective VNIs). Since the end-goal is to have server s1 communicate with s2 and s3, only leaf1 and leaf4 are configured with VNI 10020 as well, while leaf2 and leaf3 are only configured with VNI 10010.

/// tab | leaf1

```{.srl .code-scroll-lg}
A:leaf1# info tunnel-interface *
    tunnel-interface vxlan1 {
        vxlan-interface 1 {
            type bridged
            ingress {
                vni 10010
            }
        }
        vxlan-interface 2 {
            type bridged
            ingress {
                vni 10020
            }
        }
    }
```

///

/// tab | leaf2

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf2# info tunnel-interface *
    tunnel-interface vxlan1 {
        vxlan-interface 1 {
            type bridged
            ingress {
                vni 10010
            }
        }
    }
```

///

/// tab | leaf3

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf3# info tunnel-interface *
    tunnel-interface vxlan1 {
        vxlan-interface 1 {
            type bridged
            ingress {
                vni 10010
            }
        }
    }
```

///

/// tab | leaf4

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf4# info tunnel-interface *
    tunnel-interface vxlan1 {
        vxlan-interface 1 {
            type bridged
            ingress {
                vni 10010
            }
        }
        vxlan-interface 2 {
            type bridged
            ingress {
                vni 10020
            }
        }
    }
```

///

### IRBs on the leafs

IRBs are deployed using an anycast, distributed gateway model, implying that all leafs are configured with the same IP address and MAC address for a specific IRB subinterface. These IRB subinterfaces act as the default gateway for the endpoints. For our topology, we will create two subinterfaces `irb0.10` and `irb0.20` corresponding to hosts mapped to VNIs 10010 and 10020, respectively. The configuration of these IRB interfaces is shown below:

/// tab | leaf1

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf1# info interface irb0
    interface irb0 {
        admin-state enable
        subinterface 10 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 172.16.10.254/24 {
                    anycast-gw true
                }
                arp {
                    learn-unsolicited true
                    proxy-arp true
                    host-route {
                        populate dynamic {
                        }
                    }
                    evpn {
                        advertise dynamic {
                        }
                    }
                }
            }
            anycast-gw {
                anycast-gw-mac 00:00:5E:00:53:00
            }
        }
        subinterface 20 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 172.16.20.254/24 {
                    anycast-gw true
                }
                arp {
                    learn-unsolicited true
                    host-route {
                        populate dynamic {
                        }
                    }
                    evpn {
                        advertise dynamic {
                        }
                    }
                }
            }
            anycast-gw {
                anycast-gw-mac 00:00:5E:00:53:00
            }
        }
    }
```

///

/// tab | leaf2

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf2# info interface irb0
    interface irb0 {
        admin-state enable
        subinterface 10 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 172.16.10.254/24 {
                    anycast-gw true
                }
                arp {
                    learn-unsolicited true
                    proxy-arp true
                    host-route {
                        populate dynamic {
                        }
                    }
                    evpn {
                        advertise dynamic {
                        }
                    }
                }
            }
            anycast-gw {
                anycast-gw-mac 00:00:5E:00:53:00
            }
        }
    }
```

///

/// tab | leaf3

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf2# info interface irb0
    interface irb0 {
        admin-state enable
        subinterface 10 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 172.16.10.254/24 {
                    anycast-gw true
                }
                arp {
                    learn-unsolicited true
                    proxy-arp true
                    host-route {
                        populate dynamic {
                        }
                    }
                    evpn {
                        advertise dynamic {
                        }
                    }
                }
            }
            anycast-gw {
                anycast-gw-mac 00:00:5E:00:53:00
            }
        }
    }
```

///

/// tab | leaf4

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf2# info interface irb0
    interface irb0 {
        admin-state enable
        subinterface 10 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 172.16.10.254/24 {
                    anycast-gw true
                }
                arp {
                    learn-unsolicited true
                    proxy-arp true
                    host-route {
                        populate dynamic {
                        }
                    }
                    evpn {
                        advertise dynamic {
                        }
                    }
                }
            }
            anycast-gw {
                anycast-gw-mac 00:00:5E:00:53:00
            }
        }
        subinterface 20 {
            admin-state enable
            ipv4 {
                admin-state enable
                address 172.16.20.254/24 {
                    anycast-gw true
                }
                arp {
                    learn-unsolicited true
                    host-route {
                        populate dynamic {
                        }
                    }
                    evpn {
                        advertise dynamic {
                        }
                    }
                }
            }
            anycast-gw {
                anycast-gw-mac 00:00:5E:00:53:00
            }
        }
    }
```

///

There is a lot going on here, so let's breakdown some of the configuration options:

`anycast-gw [true|false]`

:   When this is set to `true`, the IPv4 address is associated to the anycast gateway MAC address and this MAC address is used to respond to any ARP requests for that IPv4 address. This also allows the same IPv4 address to be configured on other nodes for the same broadcast domain, essentially suppressing duplicate IP detection.

`anycast-gw anycast-gw-mac [mac-address]`

:   The MAC address configured with this option is the anycast gateway MAC address and is associated to the IP address for that subinterface. If this is omitted, the anycast gateway MAC address is auto-derived from the VRRP MAC address group range, as specified in RFC 9135..

`arp learn-unsolicited [true|false]`

:   This enables the node to learn the IP-to-MAC binding from any ARP packet and not just ARP requests.

`arp host-route populate dynamic`

:   This enables the node to insert a host route (/32 for IPv4 and /128 for IPv6) in the routing table from dynamic ARP entries.

`arp evpn advertise [dynamic|static]`

:   This enables the node to advertise EVPN Type-2 MAC+IP routes from dynamic or static ARP entries.

### MAC VRFs on leafs

Finally, MAC VRFs are created on the leafs to create a broadcast domain and corresponding bridge table for Layer 2 learning. Since, by default, a MAC VRF corresponds to a single broadcast domain and bridge table, we can map only one Layer 2 VNI to it. Thus, on leaf1 and leaf4, two MAC VRFs are created - one for VNI 10010 and another for VNI 10020. Under the MAC VRF, there are several important things to consider:

* The Layer 2 subinterface is bound to the MAC VRF using the `interface` configuration option.
* The corresponding IRB subinterface is bound to the MAC VRF using the `interface` configuration option.
* The VXLAN tunnel subinterface is bound to the MAC VRF using the `vxlan-interface` configuration option.
* BGP EVPN learning is enabled for the MAC VRF using the `protocols bgp-evpn` hierarchy and the MAC VRF is bound to an EVI (EVPN virtual instance).
* The `ecmp` configuration option determines how many VTEPs can be considered for load-balancing by the local VTEP (more on this in the validation section). This is for overlay ECMP in relation to remote multihomed hosts (for multihoming aliasing).
* Route distinguishers and route targets are configured for the MAC VRF using the `protocols bgp-vpn` hierarchy.

/// tab | leaf1

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf1# info network-instance macvrf*
    network-instance macvrf1 {
        type mac-vrf
        admin-state enable
        interface ethernet-1/3.0 {
        }
        interface irb0.10 {
        }
        vxlan-interface vxlan1.1 {
        }
        protocols {
            bgp-evpn {
                bgp-instance 1 {
                    admin-state enable
                    vxlan-interface vxlan1.1
                    evi 10
                    ecmp 2
                }
            }
            bgp-vpn {
                bgp-instance 1 {
                    route-distinguisher {
                        rd 192.0.2.11:1
                    }
                    route-target {
                        export-rt target:10:10
                        import-rt target:10:10
                    }
                }
            }
        }
    }
    network-instance macvrf2 {
        type mac-vrf
        admin-state enable
        interface irb0.20 {
        }
        vxlan-interface vxlan1.2 {
        }
        protocols {
            bgp-evpn {
                bgp-instance 1 {
                    admin-state enable
                    vxlan-interface vxlan1.2
                    evi 20
                    ecmp 2
                }
            }
            bgp-vpn {
                bgp-instance 1 {
                    route-distinguisher {
                        rd 192.0.2.11:2
                    }
                    route-target {
                        export-rt target:20:20
                        import-rt target:20:20
                    }
                }
            }
        }
    }
```

///

/// tab | leaf2

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf2# info network-instance macvrf1
    network-instance macvrf1 {
        type mac-vrf
        admin-state enable
        interface irb0.10 {
        }
        interface lag1.0 {
        }
        vxlan-interface vxlan1.1 {
        }
        protocols {
            bgp-evpn {
                bgp-instance 1 {
                    admin-state enable
                    vxlan-interface vxlan1.1
                    evi 10
                    ecmp 2
                }
            }
            bgp-vpn {
                bgp-instance 1 {
                    route-distinguisher {
                        rd 192.0.2.12:1
                    }
                    route-target {
                        export-rt target:10:10
                        import-rt target:10:10
                    }
                }
            }
        }
    }
```

///

/// tab | leaf3

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf3# info network-instance macvrf1
    network-instance macvrf1 {
        type mac-vrf
        admin-state enable
        interface irb0.10 {
        }
        interface lag1.0 {
        }
        vxlan-interface vxlan1.1 {
        }
        protocols {
            bgp-evpn {
                bgp-instance 1 {
                    admin-state enable
                    vxlan-interface vxlan1.1
                    evi 10
                    ecmp 2
                }
            }
            bgp-vpn {
                bgp-instance 1 {
                    route-distinguisher {
                        rd 192.0.2.13:1
                    }
                    route-target {
                        export-rt target:10:10
                        import-rt target:10:10
                    }
                }
            }
        }
    }
```

///

/// tab | leaf4

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf4# info network-instance macvrf*
    network-instance macvrf1 {
        type mac-vrf
        admin-state enable
        interface irb0.10 {
        }
        vxlan-interface vxlan1.1 {
        }
        protocols {
            bgp-evpn {
                bgp-instance 1 {
                    admin-state enable
                    vxlan-interface vxlan1.1
                    evi 10
                    ecmp 2
                }
            }
            bgp-vpn {
                bgp-instance 1 {
                    route-distinguisher {
                        rd 192.0.2.14:1
                    }
                    route-target {
                        export-rt target:10:10
                        import-rt target:10:10
                    }
                }
            }
        }
    }
    network-instance macvrf2 {
        type mac-vrf
        admin-state enable
        interface ethernet-1/3.0 {
        }
        interface irb0.20 {
        }
        vxlan-interface vxlan1.2 {
        }
        protocols {
            bgp-evpn {
                bgp-instance 1 {
                    admin-state enable
                    vxlan-interface vxlan1.2
                    evi 20
                    ecmp 2
                }
            }
            bgp-vpn {
                bgp-instance 1 {
                    route-distinguisher {
                        rd 192.0.2.14:2
                    }
                    route-target {
                        export-rt target:20:20
                        import-rt target:20:20
                    }
                }
            }
        }
    }
```

///

/// note
If needed, route distinguishers can be auto-derived as well by simply omitting the `bgp-vpn bgp-instance [instance-number] route-distinguisher` configuration option.
///

This completes the configuration walkthrough section of this post. Next, we'll cover the control plane and data plane validation.

## Control plane & data plane validation

When the hosts come online, they typically send a GARP to ensure there is no duplicate IP address in their broadcast domain. This enables the locally attached leafs to learn the IP-to-MAC binding and build an ARP entry in the ARP cache table (since the `arp learn-unsolicited` configuration option is set to `true`). This, in turn, is advertised as an EVPN Type-2 MAC+IP route for remote leafs to learn this as well and eventually insert the IP-to-MAC binding as an entry in their ARP caches.

On leaf1, we can confirm that it has learnt the IP-to-MAC binding for server s1 (locally attached) and s3 (attached to remote leaf, leaf4).

```{.srl .code-scroll-lg}
A:leaf1# show arpnd arp-entries interface irb0
+-------------------+-------------------+-----------------+-------------------+-------------------------------------+------------------------------------------------------------------------+
|     Interface     |   Subinterface    |    Neighbor     |      Origin       |         Link layer address          |                                 Expiry                                 |
+===================+===================+=================+===================+=====================================+========================================================================+
| irb0              |                10 |     172.16.10.1 |           dynamic | AA:C1:AB:CA:A0:83                   | 3 hours from now                                                       |
| irb0              |                10 |     172.16.10.2 |              evpn | AA:C1:AB:11:BE:88                   |                                                                        |
| irb0              |                20 |     172.16.20.3 |              evpn | AA:C1:AB:9F:EF:E2                   |                                                                        |
+-------------------+-------------------+-----------------+-------------------+-------------------------------------+------------------------------------------------------------------------+
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Total entries : 3 (0 static, 3 dynamic)
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

The ARP entry for host s3 (172.16.20.3) is learnt via the EVPN Type-2 MAC+IP route received from leaf4, as shown below.

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf1# show network-instance default protocols bgp routes evpn route-type 2 ip-address 172.16.20.3 detail
---------------------------------------------------------------------------------------------------------------------------
Show report for the EVPN routes in network-instance  "default"
---------------------------------------------------------------------------------------------------------------------------
Route Distinguisher: 192.0.2.14:2
Tag-ID             : 0
MAC address        : AA:C1:AB:9F:EF:E2
IP Address         : 172.16.20.3
neighbor           : 198.51.100.1
Received paths     : 1
  Path 1: <Best,Valid,Used,>
    ESI               : 00:00:00:00:00:00:00:00:00:00
    Label             : 10020
    Route source      : neighbor 198.51.100.1 (last modified 4d18h49m3s ago)
    Route preference  : No MED, No LocalPref
    Atomic Aggr       : false
    BGP next-hop      : 192.0.2.14
    AS Path           :  i [65500, 65414]
    Communities       : [target:20:20, bgp-tunnel-encap:VXLAN]
    RR Attributes     : No Originator-ID, Cluster-List is []
    Aggregation       : None
    Unknown Attr      : None
    Invalid Reason    : None
    Tie Break Reason  : none
  Path 1 was advertised to (Modified Attributes):
  [ 198.51.100.3 ]
    Route preference  : No MED, No LocalPref
    Atomic Aggr       : false
    BGP next-hop      : 192.0.2.14
    AS Path           :  i [65411, 65500, 65414]
    Communities       : [target:20:20, bgp-tunnel-encap:VXLAN]
    RR Attributes     : No Originator-ID, Cluster-List is []
    Aggregation       : None
    Unknown Attr      : None
---------------------------------------------------------------------------------------------------------------------------
Route Distinguisher: 192.0.2.14:2
Tag-ID             : 0
MAC address        : AA:C1:AB:9F:EF:E2
IP Address         : 172.16.20.3
neighbor           : 198.51.100.3
Received paths     : 1
  Path 1: <Valid,>
    ESI               : 00:00:00:00:00:00:00:00:00:00
    Label             : 10020
    Route source      : neighbor 198.51.100.3 (last modified 4d18h49m0s ago)
    Route preference  : No MED, No LocalPref
    Atomic Aggr       : false
    BGP next-hop      : 192.0.2.14
    AS Path           :  i [65500, 65414]
    Communities       : [target:20:20, bgp-tunnel-encap:VXLAN]
    RR Attributes     : No Originator-ID, Cluster-List is []
    Aggregation       : None
    Unknown Attr      : None
    Invalid Reason    : None
    Tie Break Reason  : peer-router-id
---------------------------------------------------------------------------------------------------------------------------
```

This is an important step for asymmetric routing. Consider a situation where server s1 wants to communicate with s3. When the IP packet hits leaf1, it will attempt to resolve the destination IP address via an ARP request, as it is directly attached locally (via the `irb.20` interface), as shown below.

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf1# show network-instance default route-table ipv4-unicast prefix 172.16.20.0/24
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance default
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+---------------------------+-------+------------+----------------------+----------+----------+---------+------------+-----------------+-----------------+-----------------+----------------------+
|          Prefix           |  ID   | Route Type |     Route Owner      |  Active  |  Origin  | Metric  |    Pref    | Next-hop (Type) |    Next-hop     | Backup Next-hop |   Backup Next-hop    |
|                           |       |            |                      |          | Network  |         |            |                 |    Interface    |     (Type)      |      Interface       |
|                           |       |            |                      |          | Instance |         |            |                 |                 |                 |                      |
+===========================+=======+============+======================+==========+==========+=========+============+=================+=================+=================+======================+
| 172.16.20.0/24            | 10    | local      | net_inst_mgr         | True     | default  | 0       | 0          | 172.16.20.254   | irb0.20         |                 |                      |
|                           |       |            |                      |          |          |         |            | (direct)        |                 |                 |                      |
+---------------------------+-------+------------+----------------------+----------+----------+---------+------------+-----------------+-----------------+-----------------+----------------------+
```

Since this IRB interface exists on leaf4 as well, the ARP reply will be consumed by it, never reaching leaf1, and thus, creating a failure in the ARP process. To circumvent this problem associated with an anycast, distributed IRB model, the EVPN Type-2 MAC+IP routes are used to populate the ARP cache.

Let's consider two flows to understand the data plane forwarding in such a design - server s1 communicating with s2 (same subnet) and s1 communicating with s3 (different subnet).

Since s1 is in the same subnet as s2, when communicating with s2, s1 will try to resolve its IP address directly via an ARP request. This is received on leaf1 and leaked to the CPU via `irb0.10`. Since L2 proxy-arp is not enabled, the `arp_nd_mgr` process picks up the ARP request and responds back using its own anycast gateway MAC address while suppressing the ARP request from being flooded in the fabric. A packet capture of this ARP reply is shown below.

![](https://gitlab.com/aninchat1/images/-/wikis/uploads/bc7ebec1d9e45487dead1d77849f09c2/srlinux-asymmetric-4.png)

Once this ARP process completes, host s1 generates an ICMP request (since we are testing communication between hosts using the `ping` tool). When this IP packet arrives on leaf1, it does a routing lookup (since the destination MAC address is owned by itself) and this routing lookup hits the 172.16.10.0/24 entry, as shown below. Since this is a directly attached route, it is further resolved into a MAC address via the ARP table and then the packet is bridged towards the destination. This MAC address points to an Ethernet Segment, which in turn resolves into VTEPs 192.0.2.12 and 192.0.2.13.

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf1# show network-instance default route-table ipv4-unicast route 172.16.10.2
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance default
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+------------------------+-------+------------+----------------------+----------+----------+---------+------------+---------------+---------------+---------------+------------------+
|         Prefix         |  ID   | Route Type |     Route Owner      |  Active  |  Origin  | Metric  |    Pref    |   Next-hop    |   Next-hop    | Backup Next-  | Backup Next-hop  |
|                        |       |            |                      |          | Network  |         |            |    (Type)     |   Interface   |  hop (Type)   |    Interface     |
|                        |       |            |                      |          | Instance |         |            |               |               |               |                  |
+========================+=======+============+======================+==========+==========+=========+============+===============+===============+===============+==================+
| 172.16.10.0/24         | 4     | local      | net_inst_mgr         | True     | default  | 0       | 0          | 172.16.10.254 | irb0.10       |               |                  |
|                        |       |            |                      |          |          |         |            | (direct)      |               |               |                  |
+------------------------+-------+------------+----------------------+----------+----------+---------+------------+---------------+---------------+---------------+------------------+
```

```{.srl .code-scroll-lg}
--{ + candidate shared default }--[  ]--
A:leaf1# show arpnd arp-entries interface irb0 ipv4-address 172.16.10.2
+------------------+------------------+-----------------+------------------+-----------------------------------+--------------------------------------------------------------------+
|    Interface     |   Subinterface   |    Neighbor     |      Origin      |        Link layer address         |                               Expiry                               |
+==================+==================+=================+==================+===================================+====================================================================+
| irb0             |               10 |     172.16.10.2 |             evpn | AA:C1:AB:11:BE:88                 |                                                                    |
+------------------+------------------+-----------------+------------------+-----------------------------------+--------------------------------------------------------------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Total entries : 1 (0 static, 1 dynamic)
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

```{.srl .code-scroll-lg}
--{ + candidate shared default }--[  ]--
A:leaf1# show network-instance macvrf1 bridge-table mac-table mac AA:C1:AB:11:BE:88
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Mac-table of network instance macvrf1
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Mac                     : AA:C1:AB:11:BE:88
Destination             : vxlan-interface:vxlan1.1 esi:00:00:11:11:11:11:11:11:23:23
Dest Index              : 322085950259
Type                    : evpn
Programming Status      : Success
Aging                   : N/A
Last Update             : 2024-10-14T05:37:52.000Z
Duplicate Detect time   : N/A
Hold down time remaining: N/A
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

```{.srl .code-scroll-lg}
--{ + candidate shared default }--[  ]--
A:leaf1# show tunnel-interface vxlan1 vxlan-interface 1 bridge-table unicast-destinations destination | grep -A 7 "Ethernet Segment Destinations"
Ethernet Segment Destinations
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+-------------------------------+-------------------+------------------------+-----------------------------+
|              ESI              | Destination-index |         VTEPs          | Number MACs (Active/Failed) |
+===============================+===================+========================+=============================+
| 00:00:11:11:11:11:11:11:23:23 | 322085950259      | 192.0.2.12, 192.0.2.13 | 1(1/0)                      |
+-------------------------------+-------------------+------------------------+-----------------------------+
```

A packet capture of the in-flight packet (as leaf1 sends it to spine1) is shown below, which confirms that the packet ICMP request is VXLAN-encapsulated with a VNI of 10010. It also confirms that because of the L3 proxy-arp approach to suppressing ARPs in an EVPN VXLAN fabric, the source MAC address in the inner Ethernet header is the anycast gateway MAC address.

![](https://gitlab.com/aninchat1/images/-/wikis/uploads/2aba126b6ddb1c4c37d4be11d125c1c6/srlinux-asymmetric-5.png)

The communication between host s1 and s3 follows a similar pattern - the packet is received in macvrf1, mapped VNI 10010, and since the destination MAC address is the anycast MAC address owned by leaf1, it is then routed locally into VNI 10020 (since `irb0.20` is locally attached) and then bridged across to the destination, as confirmed below:

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf1# show network-instance default route-table ipv4-unicast route 172.16.20.3
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance default
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+------------------------+-------+------------+----------------------+----------+----------+---------+------------+---------------+---------------+---------------+------------------+
|         Prefix         |  ID   | Route Type |     Route Owner      |  Active  |  Origin  | Metric  |    Pref    |   Next-hop    |   Next-hop    | Backup Next-  | Backup Next-hop  |
|                        |       |            |                      |          | Network  |         |            |    (Type)     |   Interface   |  hop (Type)   |    Interface     |
|                        |       |            |                      |          | Instance |         |            |               |               |               |                  |
+========================+=======+============+======================+==========+==========+=========+============+===============+===============+===============+==================+
| 172.16.20.0/24         | 5     | local      | net_inst_mgr         | True     | default  | 0       | 0          | 172.16.20.254 | irb0.20       |               |                  |
|                        |       |            |                      |          |          |         |            | (direct)      |               |               |                  |
+------------------------+-------+------------+----------------------+----------+----------+---------+------------+---------------+---------------+---------------+------------------+
```

```{.srl .code-scroll-lg}
--{ + running }--[  ]--
A:leaf1# show network-instance * bridge-table mac-table mac AA:C1:AB:9F:EF:E2
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Mac-table of network instance macvrf2
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Mac                     : AA:C1:AB:9F:EF:E2
Destination             : vxlan-interface:vxlan1.2 vtep:192.0.2.14 vni:10020
Dest Index              : 322085950242
Type                    : evpn
Programming Status      : Success
Aging                   : N/A
Last Update             : 2024-10-14T01:05:54.000Z
Duplicate Detect time   : N/A
Hold down time remaining: N/A
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

/// admonition
    type: tip
Notice how the previous output used a wildcard for the network-instance name instead of a specific name (`show network-instance * bridge-table ...`). This is useful since the operator may not always know exactly which MAC VRF is used for forwarding, and thus, the wildcard traverses across all to determine where the MAC address is learned.
///

The following packet capture confirms that the in-flight packet has been routed on the ingress leaf itself (leaf1) and the VNI, in the VXLAN header, is 10020.

![](https://gitlab.com/aninchat1/images/-/wikis/uploads/4dad44354646d9f1c32a73d88c8f7da8/srlinux-asymmetric-6.png)

## Summary

Asymmetric routing uses a `bridge-route-bridge` model where the packet, from the source, is bridged into the ingress leaf's L2 domain, routed into the destination VLAN/VNI and the bridged across the VXLAN fabric to the destination.

Such a model requires the existence of both source and destination IRBs and L2 bridge domains (and L2 VNIs) to exist on all leafs that want to participate in routing between the VNIs. While this is operationally simpler, it does add additional state since all leafs will have to maintain all IP-to-MAC bindings (in the ARP table) and all MAC addresses in the bridge table.

[^1]: Asymmetric and Symmetric routing models are covered in [RFC 9135](https://datatracker.ietf.org/doc/html/rfc9135)
