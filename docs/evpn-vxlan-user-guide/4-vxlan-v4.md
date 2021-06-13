This chapter describes the implementation for VXLAN tunnels that use IPv4 in the underlay.

## 4.1. VXLAN configuration
VXLAN on SR Linux uses a tunnel model where vxlan-interfaces are bound to network-instances, in the same way that subinterfaces are bound to network-instances. Up to one vxlan-interface per network-instance is supported.

Configuration of VXLAN on SR Linux is tied to EVPN. VXLAN configuration consists of the following steps:

1. Configure a tunnel-interface and vxlan-interface.  
    A tunnel-interface for VXLAN is configured as vxlan<N>, where N can be 0-255.
    A vxlan-interface is configured under a tunnel-interface. At a minimum, a vxlan-interface must have an index, type, and ingress VNI.
      * The index can be a number in the range 0-4294967295.
      * The type can be bridged or routed and indicates whether the vxlan-interface can be linked to a mac-vrf (bridged) or ip-vrf (routed).
      * The ingress VNI is the VXLAN Network Identifier that the system looks for in incoming VXLAN packets to classify them to this vxlan-interface and its network-instance.
    Configuration of an explicit vxlan-interface egress source IP is not permitted, given that the data path supports one source tunnel IP address for all VXLAN interfaces. The source IP used in the vxlan-interfaces is the IPv4 address of sub-interface system0.0 in the default network-instance.
2. Associate the vxlan-interface to a network-instance.  
    A vxlan-interface can only be associated to one network-instance, and a network-instance can have only one vxlan-interface.
3. Associate the vxlan-interface to a bgp-evpn instance.  
    The vxlan-interface must be linked to a bgp-evpn instance so that VXLAN destinations can be dynamically discovered and used to forward traffic.

The following configuration example illustrates these steps:
```
tunnel-interface vxlan1 {
  // (Step 1) Creation of the tunnel-interface and vxlan-interface
    vxlan-interface 1 {
        type bridged
        ingress {
            vni 1
        }
        egress {
            source-ip use-system-ipv4-address
        }
    }
}
network-instance blue {
    type mac-vrf
    admin-state enable
    description "network instance blue"
    interface ethernet-1/2.1 {
    }
    vxlan-interface vxlan1.1 {
  // (Step 2) Association of the vxlan-interface to the network-instance
    }
    protocols {
        bgp-evpn {
            bgp-instance 1 {
                admin-state enable
                vxlan-interface vxlan1.1
  // (Step 3) Association of the vxlan-interface to the bgp-evpn instance
                evi 1
            }
        }
        bgp-vpn {
            bgp-instance 1 {
                route-distinguisher {
                    route-distinguisher 1.1.1.1:1
                }
                route-target {
                    export-rt target:1234:1
                    import-rt target:1234:1
                }
            }
        }
    }
}
```

Upon receiving EVPN routes with VXLAN encapsulation, the SR Linux creates VTEPs (VXLAN Termination Endpoints) from the EVPN route next-hops, and each VTEP is allocated an index number (per source and destination tunnel IP addresses).

Once a VTEP is created in the vxlan-tunnel table and a non-zero index allocated, a tunnel-table entry is also created for the tunnel in the tunnel-table.

If the next hop is not resolved to any route in the network-instance default route-table, the index in the vxlan-tunnel table shows as 0 for the VTEP, and no tunnel-table entry would be created in the tunnel-table for that VTEP.

The following example illustrates the created vxlan-tunnel entries and tunnel-table entries upon receiving IMET routes from three different PEs.
``` linenums="1" hl_lines="2 24 68 82"
--{ [FACTORY] + candidate shared default }--[  ]--
# info from state tunnel vxlan-tunnel vtep *
    tunnel {
        vxlan-tunnel {
            vtep 10.22.22.2 {
                index 677716962894
 // index allocated per source and destination tunnel IP addresses.
 Index of 0 would mean that 10.22.22.2 is not resolved in the route-table
 and no tunnel-table entry is created.
                last-change "17 hours ago"
            }
            vtep 10.33.33.3 {
                index 677716962900
                last-change "17 hours ago"
            }
            vtep 10.44.44.4 {
                index 677716962897
                last-change "17 hours ago"
            }
        }
    }
 
--{ [FACTORY] + candidate shared default }--[  ]--
# info from state network-instance default tunnel-table ipv4
    network-instance default {
        tunnel-table {
            ipv4 {
                tunnel 10.22.22.2/32 type vxlan owner vxlan_mgr id 1 {
  // tunnel table entry for VTEP 10.22.22.2, created
 after the vxlan-tunnel vtep 10.22.22.2
                    next-hop-group 677716962900 // NHG-ID allocated by fib_mgr
                    metric 0
                    preference 0
                    last-app-update "17 hours ago"
                    vxlan {
                        destination-address 10.22.22.2
                        source-address 10.11.11.1
                        time-to-live 255
                    }
                }
                tunnel 10.33.33.3/32 type vxlan owner vxlan_mgr id 3 {
                    next-hop-group 677716962900
                    metric 0
                    preference 0
                    last-app-update "17 hours ago"
                    vxlan {
                        destination-address 10.33.33.3
                        source-address 10.11.11.1
                        time-to-live 255
                    }
                }
                tunnel 10.44.44.4/32 type vxlan owner vxlan_mgr id 2 {
                    next-hop-group 677716962897
                    metric 0
                    preference 0
                    last-app-update "17 hours ago"
                    vxlan {
                        destination-address 10.44.44.4
                        source-address 10.11.11.1
                        time-to-live 255
                    }
                }
            }
        }
    }
 
--{ [FACTORY] + candidate shared default }--[  ]--
# info from state network-instance default route-table next-hop-group 677716962900
    network-instance default {
        route-table {
            next-hop-group 677716962900 {
                next-hop 0 {
                    next-hop 677716962900
 // NH ID allocated by fib_mgr for the NHG-ID
                    active true
                }
            }
        }
    }
 
--{ [FACTORY] + candidate shared default }--[  ]--
# info from state network-instance default route-table next-hop 677716962900
    network-instance default {
        route-table {
            next-hop 677716962900 {
 // resolution of the NH ID
                type direct
                ip-address 10.1.2.2
                subinterface ethernet-1/1.1
            }
        }
    }
```

### 4.1.1. Source and destination VTEP addresses
In the network egress direction, the vxlan-interface/egress/source IP leaf determines the loopback interface that the system uses to source VXLAN packets (outer IP SA). The source IP used in the vxlan-interfaces is the IPv4 address of subinterface system0.0 in the default network-instance.

The egress VTEP (outer IP DA) is determined by EVPN and must be of the same family as the configured source IP (currently only IPv4).

Only unicast VXLAN tunnels are supported (outer IP DA is always unicast), and ingress replication is used to deliver BUM frames to the remote VTEPs in the current release.

In the network ingress direction, the IP DA matches one of the local loopback IP addresses in the default network-instance to move the packet to the VNI lookup stage (loopback interfaces only, not other interfaces in the default network-instance, such as IRB subinterfaces). The loopback IP address does not need to match the configured source IP address in the vxlan-interface.

The system can terminate any VXLAN packet with an outer destination IP matching a local loopback address, with no set restriction on the number of IPs.

### 4.1.2. Ingress/egress VNI
The configured ingress VNI determines the value used by the ingress lookup to find the network-instance for a further MAC lookup. The egress VNI is given by EVPN. For a mac-vrf, only one egress VNI is supported.The system ignores the value of the “I” flag on reception. According to RFC 7348, the “I” flag must be set to 1. However, the system accepts VXLAN packets with “I” flag set to 0; the “I” flag is set to 1 on transmission.

### 4.1.3. VLAN tagging for VXLAN
Outer VLAN tagging is supported (one VLAN tag only), assuming that the egress subinterface in the default network-instance uses VLAN tagging.

Inner VLAN tagging is transparent, and no specific handling is needed at network ingress for Layer 2 network-instances. Inner VLAN tagging is not supported for VXLAN originated/terminated traffic in ip-vrf network-instances that are BGP-EVPN interface-less enabled.

### 4.1.4. Network-instance and interface MTU
No specific MTU checks are done in network-instances with VXLAN.You should make the default network-instance interface MTU large enough to allow room for the VXLAN overhead. If the size of the egress VXLAN packets exceeds the IP MTU of the egress subinterface in the default network-instance, the packets are still forwarded. No statistics are collected, other than those for forwarded packets.

IP MTU checks are used only for the overlay domain; that is, for interfaces doing inner packet modifications. IP MTU checks are not done for VXLAN encapsulated packets on egress sub-interfaces of the default network-Instance (which are in the underlay domain).

### 4.1.5. Fragmentation for VXLAN traffic
Fragmentation for VXLAN traffic is handled as follows:

- The Don’t Fragment (DF) flag is set in the VXLAN outer IP header.
- The TTL of the VXLAN outer IP header is always 255.
- No reassembly is supported for VXLAN packets.

## 4.2. VXLAN and ECMP
Unicast traffic forwarded to VXLAN destinations can be load-balanced on network (underlay) ECMP links or overlay aliasing destinations.

Network LAGs, that is, LAG subinterfaces in the default network-instance, are not supported when VXLAN is enabled on the platform. LAG access subinterfaces on MAC-VRFs are supported.

VXLAN-originated packets support double spraying based on overlay ECMP (or aliasing) and underlay ECMP on the default network-instance.

Load-balancing is supported for the following:

- Encapsulated Layer 2 unicast frames (coming from a sub-interface within the same broadcast domain)
- Layer 3 frames coming from an IRB sub-interface.

For BUM frames, load balancing operates as follows:

- BUM supports spraying in access LAGs based on a hash. That is, BUM flows received from a VXLAN or a Layer 2 subinterface of a MAC-VRF are sprayed across egress access LAG links.
- BUM does not support spraying in underlay VXLAN next-hops. That is, BUM flows received from VXLAN or a Layer 2 subinterface of a MAC-VRF are sent to a single underlay subinterface.
- BUM VXLAN packets are sent to a single member of the NHG associated to a given VXLAN multicast destination. The chosen member is based on a hash of the NHG-ID of the VXLAN destination and the number of links in the NHG.

## 4.3. VXLAN ACLs
You can configure system-filter Access Control Lists (ACLs) to drop incoming VXLAN packets that should not be processed for reasons such as the following:

- The source IP is not recognized
- The destination IP is not an address that should be used for termination
- The default destination UDP port is not being used

SR Linux supports logging VXLAN of packets dropped by ACL policies.

A system-filter ACL is an IPv4 or IPv6 ACL that is evaluated before tunnel termination has occurred and before interface ACLs have been applied. A system-filter can match and drop unauthorized VXLAN tunnel packets before they are decapsulated. When a system-filter ACL is created, its rules are evaluated against all transit and terminating IPv4 or IPv6 traffic that is arriving on any subinterface of the router, regardless of where that traffic entered in terms of network-instance, subinterface, and so on.

The system-filter matches the outer header of tunneled packets; they do not filter the payload of VXLAN tunnels. If the system-filter does not drop the VXLAN-terminated packets, only egress IRB ACLs can match the inner packets. System-filters can be applied only at ingress, not egress.

See the SR Linux Configuration Basics Guide for information on configuring system-filter ACLs.

## 4.4. QoS for VXLAN tunnels
When the SR Linux receives a terminating VXLAN packet on a subinterface, it classifies the packet to one of eight forwarding classes and one of three drop probabilities (low, medium, or high). The classification is based on the following considerations:

- The outer IP header DSCP is not considered.
- If the payload packet is non-IP, the classified FC is fc0 and the classified drop probability is lowest.
- If the payload packet is IP, and there is a classifier policy referenced by the qos classifiers vxlan-default command, that policy is used to determine the FC and drop probability from the header fields of the payload packet.
- If the payload packet is IP, and there is no classifier policy referenced by the qos classifiers vxlan-default command, the default DSCP classifier policy is used to determine the FC and drop probability from the header fields of the payload packet.

When the SR Linux adds VXLAN encapsulation to a packet and forwards it out a subinterface, the inner header IP DSCP value is not modified if the payload packet is IP, even if the egress routed subinterface has a DSCP rewrite rule policy bound to it that matches the packet FC and drop probability. The outer header IP DSCP is set to a static value or copied from the inner header IP DSCP. However, this static or copied value is modified by the DSCP rewrite rule policy that is bound to the egress routed subinterface, if the rule policy exists.

Example:

You can specify a classifier policy that applies to ingress packets received from any remote VXLAN VTEP. The policy applies to payload packets after VXLAN decapsulation has been performed.

The following example specifies a VXLAN classifier policy:
```
--{ * candidate shared default }--[  ]--
# info qos
    qos {
        classifiers {
            vxlan-default p1 {
                traffic-class 1 {
                    forwarding-class fc0
                }
            }
        }
    }
```
See the SR Linux Configuration Basics Guide for information on configuring QoS.

## 4.5. VXLAN statistics
To display statistics for all VXLAN tunnels or for a specified VTEP, use the info from state command in candidate or running mode, or the info command in state mode.

Examples:

The following example displays statistics for all VXLAN tunnels:
```
--{ running }--[  ]--
# info from state vxlan-tunnel statistics
    vxlan-tunnel {
        statistics {
            in-octets 7296882
            in-packets 83012
            in-discarded-packets 5
            out-octets 7297496
            out-packets 83007
            last-clear 2021-01-29T21:58:40.919Z
        }
    }
```
The following example displays statistics for a specified VTEP:
```
--{ running }--[  ]--
# info from state vxlan-tunnel vtep 10.22.22.2
    vxlan-tunnel {
        vtep {
            address 10.22.22.2
            index 677716962894
            last-change 2021-01-29T21:52:34.151Z
            statistics {
                in-octets 7296882
                in-packets 83012
                in-discarded-packets 5
                out-octets 7297496
                out-packets 83007
                last-clear 2021-01-29T21:58:40.919Z
            }
        }
    }
```

### 4.5.1. Clearing VXLAN statistics
You can clear the statistics for all VXLAN tunnels or for a specific VTEP.

Examples:

To clear statistics for all VXLAN tunnels:
```
--{ running }--[  ]--
# tools vxlan-tunnel statistics clear
```
To clear statistics for a specific VTEP:
```
--{ running }--[  ]--
# tools vxlan-tunnel vtep 10.22.22.2 clear
```