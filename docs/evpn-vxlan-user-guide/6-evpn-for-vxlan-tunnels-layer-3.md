This chapter describes the components of EVPN-VXLAN Layer 3 on SR Linux.

## 6.1. EVPN L3 basic configuration
The basic EVPN Layer 3 configuration model builds on the model for EVPN routes described in EVPN for VXLAN tunnels (Layer 2), extending it with an additional route type to support inter-subnet forwarding: EVPN IP prefix route (or type 5, RT5).

The EVPN IP prefix route conveys IP prefixes of any length and family that need to be installed in the ip-vrfs of remote leaf nodes. The EVPN Layer 3 configuration model has two modes of operation:

- Asymmetric IRB  
    This is a basic mode of operation EVPN L3 using IRB interfaces. The term “asymmetric” refers to how there are more lookups performed at the ingress leaf than at the egress leaf (as opposed to “symmetric”, which implies the same number of lookups at ingress and egress).
    While the asymmetric model allows inter-subnet-forwarding in EVPN-VXLAN networks in a very simple way, it requires the instantiation of all the mac-vrfs of all the tenant subnets on all the leafs attached to the tenant. Since all the mac-vrfs of the tenant are instantiated, FDB and ARP entries are consumed for all the hosts in all the leafs of the tenant.
    These scale implications may make the symmetric model a better choice for data center deployment.
- Symmetric IRB  
    The term “symmetric” refers to how MAC and IP lookups are needed at ingress, and MAC and IP lookups are performed at egress.
    SR Linux support for symmetric IRB includes the prefix routing model using RT5s as in draft-ietf-bess-evpn-prefix-advertisement, including the following:
      - Interface-less ip-vrf-to-ip-vrf model (IFL model)

Compared to the asymmetric model, the symmetric model scales better since hosts’ ARP and FDB entries are installed only on the directly attached leafs and not on all the leafs of the tenant.

The following sections illustrate asymmetric and symmetric interface-less forwarding configurations.

### 6.1.1. Asymmetric IRB
The asymmetric IRB model is the basic Layer 3 forwarding model when the ip-vrf (or default network-instance) interfaces are all IRB-based. The asymmetric model assumes that all the subnets of a tenant are local in the ip-vrf/default route table, so there is no need to advertise EVPN RT5 routes.

Figure 5 illustrates the asymmetric IRB model.


<figure>
  <img id="fig5" src="https://infocenter.nokia.com/public/SRLINUX213R1A/topic/com.srlinux.evpnl2l3/html/graphics/sw4055.gif"/>
  <figcaption>Figure 5:  EVPN-VXLAN L3 asymmetric forwarding </figcaption>
</figure>

In this example, the host with IP address 10.1 (abbreviation of 10.0.0.1) sends a unicast packet with destination 20.1 (a host in a different subnet and remote leaf). Since the IP destination address (DA) is in a remote subnet, the MAC DA is resolved to the local default gateway MAC, M-IRB1. The frame is classified for MAC lookup on mac-vrf 1, and the result is IRB.1, which indicates that an IP DA lookup is required in ip-vrf red.

An IP DA longest-prefix match in the route table yields IRB.2, a local IRB interface, so an ARP and MAC DA lookup are required in the corresponding IRB interface and mac-vrf bridge table.

The ARP lookup yields M2 on mac-vrf 2, and the M2 lookup yields VXLAN destination [VTEP:VNI]=[2.2.2.2:2]. The routed packet is encapsulated with the corresponding inner MAC header and VXLAN encapsulation before being sent to the wire.

In the asymmetric IRB model, if the ingress leaf routes the traffic via the IRB to a local subnet, and the destination MAC is aliased to multiple leaf nodes in the same ES destination, SR Linux can do load balancing on a per-flow basis.

EVPN Leaf 1 in Figure 5 has the following configuration:
```
--{ [FACTORY] + candidate shared default }--[  ]--
    interface ethernet-1/2 {
        admin-state enable
        vlan-tagging true
        subinterface 1 {
            type bridged
            admin-state enable
            vlan {
                encap {
                    single-tagged {
                        vlan-id 1
                    }
                }
            }
        }
    }
    interface irb0 {
        subinterface 1 {
            ipv4 {
                address 10.0.0.254/24 {
                    anycast-gw true
                }
            }
            anycast-gw {
            }
        }
        subinterface 2 {
            ipv4 {
                address 20.0.0.254/24 {
                    anycast-gw true
                }
            }
            anycast-gw {
            }
        }
    }
    network-instance ip-vrf-red {
        type ip-vrf
        interface irb0.1 {
        }
        interface irb0.2 {
        }
    }
    network-instance mac-vrf-1 {
        type mac-vrf
        admin-state enable
        interface ethernet-1/2.1 {
        }
        interface irb0.1 {
        }
        vxlan-interface vxlan1.1 {
        }
        protocols {
            bgp-evpn {
                bgp-instance 1 {
                    admin-state enable
                    vxlan-interface vxlan1.1
                    evi 1
                }
            }
            bgp-vpn {
            }
        }
    }
    network-instance mac-vrf-2 {
        type mac-vrf
        admin-state enable
        interface irb0.2 {
        }
        vxlan-interface vxlan1.2 {
        }
        protocols {
            bgp-evpn {
                bgp-instance 1 {
                    admin-state enable
                    vxlan-interface vxlan1.2
                    evi 2
                }
            }
            bgp-vpn {
            }
        }
    }
    tunnel-interface vxlan1 {
        vxlan-interface 1 {
            type bridged
            ingress {
                vni 1
            }
        }
        vxlan-interface 2 {
            type bridged
            ingress {
                vni 2
            }
        }
    }
```
EVPN Leaf 2 in Figure 5 has the following configuration:
```
--{ [FACTORY] + candidate shared default }--[  ]--
A:LEAF2# info
    interface ethernet-1/12 {
        admin-state enable
        vlan-tagging true
        subinterface 1 {
            type bridged
            admin-state enable
            vlan {
                encap {
                    single-tagged {
                        vlan-id 2
                    }
                }
            }
        }
    }
    interface irb0 {
        subinterface 1 {
            ipv4 {
                address 10.0.0.254/24 {
                    anycast-gw true
                }
            }
            anycast-gw {
            }
        }
        subinterface 2 {
            ipv4 {
                address 20.0.0.254/24 {
                    anycast-gw true
                }
            }
            anycast-gw {
            }
        }
    }
    network-instance ip-vrf-red {
        type ip-vrf
        interface irb0.1 {
        }
        interface irb0.2 {
        }
    }
    network-instance mac-vrf-1 {
        type mac-vrf
        admin-state enable
        interface irb0.1 {
        }
        vxlan-interface vxlan1.1 {
        }
        protocols {
            bgp-evpn {
                bgp-instance 1 {
                    admin-state enable
                    vxlan-interface vxlan1.1
                    evi 1
                }
            }
            bgp-vpn {
            }
        }
    }
    network-instance mac-vrf-2 {
        type mac-vrf
        admin-state enable
        interface irb0.2 {
        }
        vxlan-interface vxlan1.2 {
        }
        protocols {
            bgp-evpn {
                bgp-instance 1 {
                    admin-state enable
                    vxlan-interface vxlan1.2
                    evi 2
                }
            }
            bgp-vpn {
            }
        }
    }
    tunnel-interface vxlan1 {
        vxlan-interface 1 {
            type bridged
            ingress {
                vni 1
            }
        }
        vxlan-interface 2 {
            type bridged
            ingress {
                vni 2
            }
        }
    }
```

### 6.1.2. Symmetric IRB interface-less IP-VRF-to-IP-VRF model
SR Linux support for symmetric IRB is based on the prefix routing model using RT5s, and implements the EVPN interface-less (EVPN IFL) ip-vrf-to-ip-vrf model.

In the EVPN IFL model, all interface and local routes (static, ARP-ND, BGP, and so on) are automatically advertised in RT5s without the need for any export policy. Interface host and broadcast addresses are not advertised. On the ingress PE, RT5s are installed in the route table as indirect with owner “bgp-evpn”.

Figure 6 illustrates the forwarding for symmetric IRB.



<figure>
  <img id="fig6" src="https://infocenter.nokia.com/public/SRLINUX213R1A/topic/com.srlinux.evpnl2l3/html/graphics/sw4056.gif"/>
  <figcaption>Figure 6:  EVPN-VXLAN L3 symmetric forwarding</figcaption>
</figure>

As in the asymmetric model, the frame is classified for bridge-table lookup on the mac-vrf and processed for routing in ip-vrf red.

In contrast to the asymmetric model, a longest prefix match does not yield a local subnet, but a remote subnet reachable via [VTEP:VNI]=[2.2.2.2:3] and inner MAC DA R-MAC2. SR Linux supports the EVPN interface-less (EVPN IFL) model, so that information is found in the ip-vrf route-table directly; a route lookup on the ip-vrf-red route-table yields a VXLAN tunnel and VNI.

- Packets are encapsulated with an inner Ethernet header and the VXLAN tunnel encapsulation.
- The inner Ethernet header uses the system-mac as MAC source address (SA), and the MAC advertised along with the received RT5 as MAC DA. No VLAN tag is transmitted or received in this inner Ethernet header.

At the egress PE, the packet is classified for an IP lookup on the ip-vrf red (the inner Ethernet header is ignored).

The inner and outer IP headers are updated as follows:

- The inner IP header TTL is decremented.
- The outer IP header TTL is set to 255.
- The outer DSCP value is marked as described in QoS for VXLAN tunnels.
- No IP MTU check is performed before or after encapsulation.

Since SR Linux supports EVPN IFL, the IP lookup in the ip-vrf-red route-table yields a local IRB interface.

Subsequent ARP and MAC lookups provide the information to send the routed frame to subinterface 2.

EVPN Leaf 1 in Figure 6 has the following configuration:
```
--{ [FACTORY] + candidate shared default }--[  ]--
    interface ethernet-1/2 {
        admin-state enable
        vlan-tagging true
        subinterface 1 {
            type bridged
            admin-state enable
            vlan {
                encap {
                    single-tagged {
                        vlan-id 1
                    }
                }
            }
        }
    }
    interface irb0 {
        subinterface 1 {
            ipv4 {
                address 10.0.0.254/24 {
                    anycast-gw true
                }
            }
            anycast-gw {
            }
        }
    }
    network-instance ip-vrf-red {
        type ip-vrf
        interface irb0.1 {
        }
        vxlan-interface vxlan1.3 {
        }
        protocols {
            bgp-evpn {
                bgp-instance 1 {
                    admin-state enable
                    vxlan-interface vxlan1.3
                    evi 3
                }
            }
            bgp-vpn {
            }
        }
    }
    network-instance mac-vrf-1 {
        type mac-vrf
        admin-state enable
        interface ethernet-1/2.1 {
        }
        interface irb0.1 {
        }
        vxlan-interface vxlan1.1 {
        }
        protocols {
            bgp-evpn {
                bgp-instance 1 {
                    admin-state enable
                    vxlan-interface vxlan1.1
                    evi 1
                }
            }
            bgp-vpn {
            }
        }
    }
    tunnel-interface vxlan1 {
        vxlan-interface 1 {
            type bridged
            ingress {
                vni 1
            }
        }
        vxlan-interface 3 {
            type routed
            ingress {
                vni 3
            }
        }
    }
```
EVPN Leaf 2 in Figure 6 has the following configuration:
```
--{ [FACTORY] + candidate shared default }--[  ]--
    interface ethernet-1/12 {
        admin-state enable
        vlan-tagging true
        subinterface 2 {
            type bridged
            admin-state enable
            vlan {
                encap {
                    single-tagged {
                        vlan-id 2
                    }
                }
            }
        }
    }
    interface irb0 {
        subinterface 2 {
            ipv4 {
                address 20.0.0.254/24 {
                    anycast-gw true
                }
            }
            anycast-gw {
            }
        }
    }
    network-instance ip-vrf-red {
        type ip-vrf
        interface irb0.2 {
        }
        vxlan-interface vxlan1.3 {
        }
        protocols {
            bgp-evpn {
                bgp-instance 1 {
                    admin-state enable
                    vxlan-interface vxlan1.3
                    evi 3
                }
            }
            bgp-vpn {
            }
        }
    }
    network-instance mac-vrf-2 {
        type mac-vrf
        admin-state enable
        interface ethernet-1/12.2 {
        }
        interface irb0.2 {
        }
        vxlan-interface vxlan1.2 {
        }
        protocols {
            bgp-evpn {
                bgp-instance 1 {
                    admin-state enable
                    vxlan-interface vxlan1.2
                    evi 2
                }
            }
            bgp-vpn {
            }
        }
    }
    tunnel-interface vxlan1 {
        vxlan-interface 2 {
            type bridged
            ingress {
                vni 2
            }
        }
        vxlan-interface 3 {
            type routed
            ingress {
                vni 3
            }
        }
    }
```

## 6.2. Anycast gateways
Anycast gateways (anycast-GWs) are a common way to configure IRB subinterfaces in DC leaf nodes. Configuring anycast-GW IRB subinterfaces on all leaf nodes of the same BD avoids tromboning for upstream traffic from hosts moving between leaf nodes.

Figure 7 shows an example anycast-GW IRB configuration.

<figure>
  <img id="fig6" src="https://infocenter.nokia.com/public/SRLINUX213R1A/topic/com.srlinux.evpnl2l3/html/graphics/sw4051.gif"/>
  <figcaption>Figure 7:  Anycast-GW IRB configuration</figcaption>
</figure>

Anycast-GWs allow configuration of the same IP and MAC addresses on the IRB interfaces of all leaf switches attached to the same BD; for example, SRL LEAF-1 and SRL LEAF-2 in Figure 7 above. This optimizes the south-north forwarding since a host’s default gateway always belongs to the connected leaf, irrespective of the host moving between leaf switches; for example VM3 moving from SRL LEAF-1 to SRL LEAF-2 in the figure.

When an IRB subinterface is configured as an anycast-GW, it must have one IP address configured as “anycast-gw”. The subinterface may or may not have other non-anycast-GW IP addresses configured.

To simplify provisioning, an option to automatically derive the anycast-gw MAC is supported, as described in draft-ietf-bess-evpn-inter-subnet-forwarding. The auto-derivation uses a virtual-router-id similar to MAC auto-derivation in RFC 5798 (VRRP). Anycast GWs use a default virtual-router-id of 01 (if not explicitly configured). Since only one anycast-gw-mac per IRB sub-interface is supported, the anycast-gwmac for IPv4 and IPv6 is the same in the IRB sub-interface.

The following is an example configuration for an anycast-GW subinterface:
```
// Configuration Example of an anycast-gw IRB sub-interface
 
[interface irb1 subinterface 1 ]
A:leaf-1/2# info
  ipv4 {
    address 10.0.0.254/24 {
      primary true
      anycast-gw true
    }       
  }
  anycast-gw {
    virtual-router-id 2
  }
 
// State Example of an anycast-gw IRB sub-interface
 
[interface irb1 subinterface 1 ]
A:leaf-1/2# info from state  
  ipv4 {
    address 10.0.0.254/24 {
      primary true
      anycast-gw true
    }
  }
  anycast-gw {
    virtual-router-id 2
    anycast-gw-mac 00:00:5e:00:01:02
    anycast-gw-mac-origin auto-derived
  }
```

The anycast-gw true command designates the associated IP address as an anycast-GW address of the subinterface and associates the IP address with the anycast-gw-mac address in the same sub-interface. ARP requests or Neighbor Solicitations received for the anycast-GW IP address are replied using the anycast-gw-mac address, as opposed to the regular system-derived MAC address. Similarly, CPM-originated GARPs or unsolicited neighbor advertisements sent for the anycast-gw IP address use the anycast-gw-mac address as well. Packets routed to the IRB use the anycast-gw-mac as the SA in Ethernet header.

All IP addresses of the IRB subinterface and their associated MACs are advertised in MAC/IP routes with the static flag set. The non-anycast-gw IPs are advertised along with the interface hardware MAC address, and the anycast-gw IP addresses along with the anycast-gw-mac address.

In addition, the anycast-gw true command makes the system skip the ARP/ND duplicate-address-detection procedures for the anycast-GW IP address.

## 6.3. EVPN L3 multi-homing and anycast gateways
In an EVPN L3 scenario, all IRB interfaces facing the hosts must have the same IP address and MAC; that is, an anycast-GW configuration. This avoids inefficiencies for all-active multi-homing or speeds up convergence for host mobility.

The use of anycast-GW along with all-active multi-homing is illustrated in Figure 8.

<figure>
  <img id="fig6" src="https://infocenter.nokia.com/public/SRLINUX213R1A/topic/com.srlinux.evpnl2l3/html/graphics/sw4057.gif"/>
  <figcaption>Figure 8:  EVPN-VXLAN L3 model – multi-homing and anycast GW</figcaption>
</figure>

In this example:

1. Routed unicast traffic is always routed to the directly connected leaf (no tromboning).
2. BUM traffic sent from the IRB interface is sent to all DF and NDF subinterfaces (similar to BUM entering a subinterface).  
    This applies to:
      - System-generated unknown or bcast
      - ARP requests and GARPs
      - Unicast with unkown MAC DA

When a host connected to ES-3 sends a unicast flow to be routed in the ip-vrf, the flow must be routed in the leaf receiving the traffic, irrespective of the server hashing the flow to Leaf-1 or Leaf-2. To do this, the host is configured with only one default gateway, 20.254/24. When the host ARPs for it, it does not matter if the ARP request is sent to Leaf-1 or Leaf-2. Either leaf replies with the same anycast-GW MAC, and when receiving the traffic either leaf can route the packet.

This scenario is supported on ip-vrf network-instances and the default network-instance.

## 6.4. EVPN L3 host route mobility
EVPN host route mobility refers to the procedures that allow the following:

- Learning ARP/ND entries out of unsolicited messages from hosts
- Generating host routes out of those ARP/ND entries
- Refreshing the entries when mobility events occur within the same BD.

EVPN host route mobility is part of basic EVPN Layer 3 functionality as defined in draft-ietf-bess-evpn-inter-subnet-forwarding.

Figure 9 illustrates EVPN host route mobility.

<figure>
  <img id="fig9" src="https://infocenter.nokia.com/public/SRLINUX213R1A/topic/com.srlinux.evpnl2l3/html/graphics/sw4053.gif"/>
  <figcaption>Figure 9:  EVPN host route mobility</figcaption>
</figure>

In Figure 9 a host is attached to PE1, so all traffic from PE3 to that host must be forwarded directly to PE1. When the host moves to PE2, all the tables must be immediately updated so that PE3 sends the traffic to PE2. EVPN host route mobility works by doing the following:

1. Snooping and learning ARP/ND entries for hosts upon receiving unsolicited GARP or NA messages.
1. Creating host routes out of those dynamic ARP/ND entries. These routes only exist in the control plane and are not installed in the forwarding plane to avoid FIB exhaustion with too many /32 or /128 host routes.
1. Advertising the locally learned ARP/ND entries in MAC/IP routes so that ARP/ND caches can be synchronized across leaf nodes.
1. Advertising the host routes as IP prefix routes.
1. Triggering ARP/ND refresh messages for changes in the ARP/ND table or MAC table for a given IP, which allows updating the tables without depending on the ARP/ND aging timers (which can be hours long).

The following configuration enables an anycast-GW IRB subinterface to support mobility procedures:
```
// Example of the configuration of host route mobility features
 
--{ candidate shared default }--[ interface irb1 subinterface 1 ]--
A:-# info
    ipv4 {
        address 10.0.0.254/24 {
            anycast-gw true
            primary
        }
        arp {
            learn-unsolicited true
            host-route {
                populate static 
                populate dynamic 
            }
            evpn {
                advertise static 
                advertise dynamic 
            }
        }
    }
    ipv6 {
        address 200::254/64 {
            anycast-gw true
            primary
        }
        neighbor-discovery {
            learn-unsolicited true
            host-route {
                populate static 
                populate dynamic 
            }
            evpn {
                advertise static 
                advertise dynamic 
            }
        }
    }
    anycast-gw {
    }
--{ candidate shared default }--[ interface irb1 subinterface 1 ]--
# info from state
    admin-state enable
    ip-mtu 1500
    name irb1.1
    ifindex 1082146818
    oper-state up
    last-change "a minute ago"
    ipv4 {
        allow-directed-broadcast false
        address 10.0.0.254/24 {
            anycast-gw true
            origin static
        }
        arp {
            duplicate-address-detection true
            timeout 14400
            learn-unsolicited true
            host-route {
                populate static 
                populate dynamic 
                }
            }
        }
    }
    ipv6 {
        address 200::254/64 {
            anycast-gw true
            origin static
            status unknown
        }
        address fe80::201:1ff:feff:42/64 {
            origin link-layer
            status unknown
        }
        neighbor-discovery {
            duplicate-address-detection true
            reachable-time 30
            stale-time 14400
            learn-unsolicited both
            host-route {
                populate static 
                populate dynamic 
            }
        }
        router-advertisement {
            router-role {
                current-hop-limit 64
                managed-configuration-flag false
                other-configuration-flag false
                max-advertisement-interval 600
                min-advertisement-interval 200
                reachable-time 0
                retransmit-time 0
                router-lifetime 1800
            }
        }
    }
    anycast-gw {
        virtual-router-id 1
        anycast-gw-mac 00:00:5E:00:01:01
        anycast-gw-mac-origin vrid-auto-derived
    }
...
```
In this configuration, when learn-unsolicited is set to true, the node processes all solicited and unsolicited ARP/ND flooded messages received on subinterfaces (no VXLAN) and learns the corresponding ARP/ND entries as dynamic. By default, this setting is false, so only solicited entries are learned by default.

The advertisement of EVPN MAC/IP routes for the learned ARP entries must be enabled/disabled by configuration; it is disabled by default. In the example above, this is configured with the advertise dynamic and advertise static settings.

The creation of host routes in the ip-vrf route table out of the dynamic and/or static ARP entries be enabled/disabled by configuration; it is disabled by default. In the example above, this is configured with the host-route populate dynamic and host-route populate static settings.

The dynamic ARP entries are refreshed without any extra configuration. The system sends ARP requests for the dynamic entries to make sure the hosts are still alive and connected.

## 6.5. EVPN IFL interoperability with EVPN IFF
By default, the SR Linux EVPN IFL (interface-less) model, described in Symmetric IRB interface-less IP-VRF-to-IP-VRF model, does not interoperate with the EVPN IFF (interface-ful) model, as supported on Nuage WBX devices. However, it is possible to configure the SR Linux EVPN IFL model to interoperate with the EVPN IFF model.

To do this, configure the advertise-gateway-mac command for the ip-vrf network instance. When this command is configured, the node will advertise a MAC/IP route using the following:

- The gateway-mac for the ip-vrf (that is, the system-mac)
- The RD/RT, next-hop, and VNI of the ip-vrf where the command is configured
- Null IP address, ESI or Ethernet Tag ID

Nuage WBX devices support two EVPN L3 IPv6 modes: IFF unnumbered and IFF numbered. The SR Linux interoperability mode enabled by the advertise-gateway-mac command only works with Nuage WBX devices that use the EVPN IFF unnumbered model. This is because the EVPN IFL and EVPN IFF unnumbered models both use the same format in the IP prefix route, and they differ only in the additional MAC/IP route for the gateway-mac. The EVPN IFL and EVPN IFF numbered models have different IP prefix route formats, so they cannot interoperate.

The following example enables interoperability with the Nuage EVPN IFF unnumbered model:
```
--{ [FACTORY] + candidate shared default }--[  ]--
# info from state network-instance protocols bgp-vpn
  bgp-evpn {
      bgp-instance 1 {
          admin-state enable
          vxlan-interface vxlan1.2
          routes {
              route-table {
                  mac-ip {
                      advertise-gateway-mac true
                  }
              }
          }
      }
  }
```