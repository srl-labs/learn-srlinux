This chapter describes the components of EVPN-VXLAN Layer 2 on SR Linux.

## 5.1. EVPN-VXLAN L2 basic configuration
Basic configuration of EVPN-VXLAN L2 on SR Linux consists of the following:

- A vxlan-interface, which contains the ingress VNI of the incoming VXLAN packets associated to the vxlan-interface
- A MAC-VRF network-instance, where the vxlan-interface is attached. Only one vxlan-interface can be attached to a MAC-VRF network-instance.
- BGP-EVPN is also enabled in the same MAC-VRF with a minimum configuration of the EVI and the network instance vxlan-interface associated to it.  
    The BGP instance under BGP-EVPN has an encapsulation-type leaf, which is VXLAN by default.  
    For EVPN, this determines that the BGP encapsulation extended community is advertised with value VXLAN and the value encoded in the label fields of the advertised NLRIs is a VNI.  
    If the route-distinguisher and/or route-target/policies are not configured, the required values are automatically derived from the configured EVI as follows:
      - The route-distinguisher is derived as <ip-address:evi>, where the ip-address is the IPv4 address of the default network-instance sub-interface system0.0.
      - The route-target is derived as <asn:evi>, where the asn is the autonomous system configured in the default network-instance.
Example:

The following example shows a basic EVPN-VXLAN L2 configuration consisting of a vxlan-interface, MAC-VRF network-instance, and BGP-EVPN configuration:
```
--{ candidate shared default }--[ ]--
# info
...
    tunnel-interface vxlan1 {
        vxlan-interface 1 {
            type bridged
            ingress {
                vni 10
            }
            egress {
                source-ip use-system-ipv4-address
            }
        }
    }
  
// In the network-instance:
  
A:dut2#  network-instance blue
--{ candidate shared default }--[ network-instance blue ]--
# info
    type mac-vrf
    admin-state enable
    description "Blue network instance"
    interface ethernet-1/2.1 {
    }
    vxlan-interface vxlan1.1 {
    }
    protocols {
        bgp-evpn {
            bgp-instance 1 {
                admin-state enable
                vxlan-interface vxlan1.1
                evi 10
            }
        }
        bgp-vpn {
            bgp-instance 1 {
     // rd and rt are auto-derived from evi if this context is not configured
                export-policy pol-def-1
                import-policy pol-def-1
                route-distinguisher {
                    route-distinguisher 64490:200
                }
                route-target {
                    export-rt target:64490:200
                    import-rt target:64490:100
                }
            }
        }
    }
```

### 5.1.1. EVPN L2 basic routes
EVPN Layer 2 (without multi-homing) includes the implementation of the BGP-EVPN address family and support for the following route types:

- EVPN MAC/IP route (or type 2, RT2)
- EVPN Inclusive Multicast Ethernet Tag route (IMET or type 3, RT3)

The MAC/IP route is used to convey the MAC and IP information of hosts connected to subinterfaces in the MAC-VRF. The IMET route is advertised as soon as bgp-evpn is enabled in the MAC-VRF; it has the following purpose:

- Auto-discovery of the remote VTEPs attached to the same EVI
- Creation of a default flooding list in the MAC-VRF so that BUM frames are replicated

Advertisement of the MAC/IP and IMET routes is configured on a per-MAC-VRF basis. The following example shows the default setting advertise true, which advertises MAC/IP and IMET routes.

Note that changing the setting of the advertise parameter and committing the change internally flaps the BGP instance.

Example:
```
--{ candidate shared default }--[ network-instance blue protocols bgp-evpn bgp-
instance 1 ]--
A:dut1# info detail
    admin-state enable
    vxlan-interface vxlan1.1
    evi 1
    ecmp 1
    default-admin-tag 0
    routes {
        next-hop use-system-ipv4-address
        mac-ip {
            advertise true
        }
        inclusive-mcast {
            advertise true
        }
    }
```
### 5.1.2. Creation of VXLAN destinations based on received EVPN routes
The creation of VXLAN destinations of type unicast, unicast ES (Ethernet segment), and multicast for each vxlan-interface is driven by the reception of EVPN routes.

The created unicast, unicast ES, and multicast VXLAN destinations are visible in state. Each destination is allocated a system-wide unique destination index and is an internal NHG-ID (next-hop group ID). The destination indexes for the VXLAN destinations are shown in the following example for destination 10.22.22.4, vni 1
```
--{ [FACTORY] + candidate shared default }--[  ]--
# info from state tunnel-interface vxlan1 vxlan-interface 1 bridge-table unicast-
destinations destination * vni *
    tunnel-interface vxlan1 {
        vxlan-interface 1 {
            bridge-table {
                unicast-destinations {
                    destination 10.44.44.4 vni 1 {
                        destination-index 677716962904 // destination index
                        statistics {
                        }
                        mac-table {
                            mac 00:00:00:01:01:04 {
                                type evpn-static
                                last-update "16 hours ago"
                            }
                        }
                    }
                }
            }
        }
    }
--{ [FACTORY] + candidate shared default }--[  ]--
# info from state network-instance blue bridge-table mac-table mac 00:00:00:01:01:04
    network-instance blue {
        bridge-table {
            mac-table {
                mac 00:00:00:01:01:04 {
                    destination-type vxlan
                    destination-index 677716962904 // destination index
                    type evpn-static
                    last-update "16 hours ago"
                    destination "vxlan-interface:vxlan1.1 vtep:10.44.44.4 vni:1"
                }
            }
        }
    }
```
The following is an example of dynamically created multicast destinations for a vxlan-interface:
```
--{ [FACTORY] + candidate shared default }--[  ]--
A:dut1# info from state tunnel-interface vxlan1 vxlan-interface 1 bridge-
table multicast-destinations
    tunnel-interface vxlan1 {
        vxlan-interface 1 {
            bridge-table {
                multicast-destinations {
                    destination 40.1.1.2 vni 1 {
                        multicast-forwarding BUM
                        destination-index 46428593833
                    }
                    destination 40.1.1.3 vni 1 {
                        multicast-forwarding BUM
                        destination-index 46428593835
                    }
                    destination 40.1.1.4 vni 1 {
                        multicast-forwarding BUM
                        destination-index 46428593829
                    }
                }
            }
        }
    }
```

### 5.1.3. EVPN route selection
When a MAC is received from multiple sources, the route is selected based on the priority listed in MAC selection. Learned and EVPN-learned routes have equal priority; the latest received route is selected.

When multiple EVPN-learned MAC/IP routes arrive for the same MAC but with a different key (for example, two routes for MAC M1 with different route-distinguishers), a selection is made based on the following priority:

1. EVPN MACs with higher SEQ number
1. EVPN MACs with lower IP next-hop
1. EVPN MACs with lower Ethernet Tag
1. EVPN MACs with lower RD

### 5.1.4. Configuring BGP next hop for EVPN routes
You can configure the BGP next hop to be used for the EVPN routes advertised for a network-instance. This next hop is by default the IPv4 address configured in interface system 0.0 of the default network-instance. However, the next-hop address can be changed to any IPv4 address.

The system does not check that the configured IP address exists in the default network-instance. Any valid IP address can be used as next hop of the EVPN routes advertised for the network-instance, irrespective of its existence in any subinterface of the system. However, the receiver leaf nodes create their unicast, multicast and ES destinations to this advertised next-hop, so it is important that the configured next-hop is a valid IPv4 address that exists in the default network-instance.

When the system or loopback interface configured for the BGP next-hop is administratively disabled, EVPN still advertises the routes, as long as a valid IP address is available for the next-hop. However, received traffic on that interface is dropped.

Example:

The following example configures a BGP next hop to be used for the EVPN routes advertised for a network-instance.
```
--{ candidate shared default }--[ network-instance 1 protocols bgp-evpn bgp-
instance 1 ]--
A:dut2# info
    routes {
        next-hop 1.1.1.1
        }
    }
```
## 5.2. MAC duplication detection for Layer 2 loop prevention in EVPN
MAC loop prevention in EVPN broadcast domains is based on the SR Linux MAC duplication feature (see MAC duplication detection and actions), but considers MACs that are learned via EVPN as well. The feature detects MAC duplication for MACs moving among bridge subinterfaces of the same MAC-VRF, as well as MACs moving between bridge subinterfaces and EVPN in the same MAC-VRF, but not for MACs moving from a VTEP to a different VTEP (via EVPN) in the same MAC-VRF.

Also, when a MAC is declared as duplicate, and the blackhole configuration option is added to the interface, then not only incoming frames on bridged subinterfaces are discarded if their MAC SA or DA match the blackhole MAC, but also frames encapsulated in VXLAN packets are discarded if their source MAC or destination MAC match the blackhole MAC in the mac-table.

When a MAC exceeds the allowed num-moves, the MAC is moved to a type duplicate (irrespective of the type of move: EVPN-to-local, local-to-local, local-to-EVPN), the EVPN application receives an update that advertises the MAC with a higher sequence number (which might trigger the duplication in other nodes). The “duplicate” MAC can be overwritten by a higher priority type, or flushed by the tools command (see Deleting entries from the bridge table).

## 5.3. EVPN L2 multi-homing
The EVPN multi-homing implementation uses the following SR Linux features:

- System network-instance  
    A system network-instance container hosts the configuration and state of EVPN for multi-homing.
- Network-instance BGP instance  
    The ES model uses a BGP instance from where the RD/RT and export/import policies are taken to advertise and process the multi-homing ES routes. Only one BGP instance is allowed, and all the Ethernet Segments are configured under this BGP instance. The RD/RTs cannot be configured when the BGP instance is associated to the system network-instance, however the operational RD/RTs are still shown in state.
- Ethernet Segments (ES)  
    An ES has an admin-state (disabled by default) setting that must be toggled in order to change any of the parameters that affect the EVPN control plane. In particular, the Ethernet Segments support:
    - General and per-ES boot and activation timers.
    - Manual 10-byte ESI configuration.
    - All-active multi-homing mode.
    - DF Election algorithm type Default (modulo based).
    - Configuration of ES and AD per-ES routes next-hop, and ES route originating-IP per ES.
    - An AD per ES route is advertised per mac-vrf, where the route carries the network-instance RD and RT.
    - Association to an interface that can be of type ethernet or lag. When associated to a LAG, the LAG can be static or LACP-based. In case of LACP, the same system-id/system-priority/port-key settings must be configured on all the nodes attached to the same Ethernet segment.
- Aliasing load balancing  
    This hashing operation for aliasing load balancing uses the following hash fields in the incoming frames by default:
    - For IP traffic: IP DA and IP SA, L4 Source and Destination Ports, Protocol, VLAN ID.
    - For Ethernet (non-IP) traffic: MAC DA and MAC SA, VLAN ID, ethertype.
    For IPv6 addresses, 32 bit fields are generated by XORing and Folding the 128 bit address. The packet fields are given as input to the hashing computation.

### 5.3.1. EVPN L2 multi-homing procedures
EVPN relies on three different procedures to handle multi-homing: DF election, split-horizon and aliasing.

- DF Election – the Designated Forwarder (DF) is the leaf that will forward BUM traffic in the Ethernet Segment (ES). Only one DF can exist per ES at the time, and is elected based on the exchange of ES routes (type 4) and the subsequent DF Election Algorithm.
- Split-horizon – the mechanism by which BUM traffic received from a peer ES PE is filtered so that it is not looped back to the CE that first transmitted the frame. Local Bias is applied in VXLAN services, as described in RFC 8365.
- Aliasing – the procedure by which PEs that are not attached to the ES can process non-zero ESI MAC/IP routes and AD routes and create ES destinations to which per-flow ECMP can be applied.

To support multi-homing, EVPN-VXLAN supports two additional route types:

- ES routes (type 4) – Used for ES discovery on all the leafs attached to the ES and DF Election.  
    ES routes use an ES-import route target extended community (its value derived from the ESI), so that its distribution is limited to only the Leafs that are attached to the ES.
    The ES route is advertised with the DF Election extended community, which indicates the intend to use a specific DF Alg and capabilities.
    Upon reception of the remote ES routes, each PE builds a DF candidate list based on the originator IP of the ES routes. Then, based on the agreed DF Election Alg, each PE elects one of the candidates as DF for each mac-vrf where the ES is defined.
- AD route (type 1) – Advertised to the leafs attached to an ES. There are two versions of AD routes:
    - AD per-ES route – Used to advertise the multi-homing mode (all-active only) and the ESI label, which is not advertised or processed in case of VXLAN. Its withdrawal enables the mass withdrawal procedures in the remote PEs.
    - AD per-EVI route – Used to advertise the availability of an ES in a given EVI and its VNI. It is needed by the remote leafs for the aliasing procedures.

Both versions of AD routes can influence the DF Election. Their withdrawal from a given leaf results in removing that leaf from consideration for DF Election for the associated EVI.

### 5.3.2. Local bias for EVPN multi-homing
Local bias for EVPN multi-homing is based on the following behavior at the ingress and egress leafs:

- At the ingress leaf, any BUM traffic received on an all-active multi-homing LAG sub-interface (associated to an EVPN-VXLAN mac-vrf) is flooded to all local subinterfaces, irrespective of their DF or NDF status, and VXLAN tunnels.
- At the egress leaf, any BUM traffic received on a VXLAN subinterface (associated to an EVPN-VXLAN mac-vrf) is flooded to single-homed subinterfaces and multi-homed subinterfaces whose ES is not shared with the owner of the source VTEP if the leaf is DF for the ES.

In SR Linux, the local bias filtering entries on the egress leaf are added or removed based on the ES routes, and they are not modified by the removal of AD per EVI/ES routes. This may cause blackholes in the multi-homed CE for BUM traffic if the local subinterfaces are administratively disabled.

### 5.3.3. EVPN multi-homing configuration example
The following is an example of an EVPN multi-homing configuration. In this example, the system network-instance is configured with an Ethernet segment, which is associated to all network-instances of type mac-vrf that contain a specified subinterface.

The system network-instance is configured with Ethernet segment ES-1 as follows:
```
--{ [FACTORY] + candidate shared default }--[  ]--
# info system network-instance
    system {
        network-instance {
            protocols {
                evpn {
                    ethernet-segments {
                        bgp-instance 1 {
                            ethernet-segment ES-1 {
                                admin-state enable
                                esi 00:11:22:33:44:55:66:77:88:99
                                interface ethernet-1/2
                            }
                        }
                    }
                }
                bgp-vpn {
                    bgp-instance 1 {
                    }
                }
            }
        }
    }
```
The following configuration causes Ethernet segment ES-1 to be associated to all network-instances of type mac-vrf that contain a subinterface in ethernet-1/2:
```
--{ [FACTORY] + candidate shared default }--[  ]--
# info network-instance blue
    network-instance blue {
        type mac-vrf
        admin-state enable
        description "network instance blue"
        interface ethernet-1/2.1 {
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
                bgp-instance 1 {
                }
            }
        }
    }
```
To display information about the ES, use the show system network-instance ethernet-segments command. For example:
```
--{ [FACTORY] + candidate shared default }--[  ]--
# show system network-instance ethernet-segments
------------------------------------------------------------------------------------
testing is up, all-active
  ESI  : 00:11:22:33:44:55:66:77:88:99
  Alg  : default
  Peers: 40.1.1.2, 40.1.1.3
  Network-instances:
     blue
      Candidates : 40.1.1.1, 40.1.1.2 (DF), 40.1.1.3
      Interface : irb0.1
------------------------------------------------------------------------------------
Summary
 1 Ethernet Segments Up
 0 Ethernet Segments Down
------------------------------------------------------------------------------------
```
The detail option displays additional information about the ES. For example:
```
--{ [FACTORY] + candidate shared default }--[  ]--
# show system network-instance ethernet-segments detail
====================================================================================
Ethernet Segment
====================================================================================
Name                 : testing
40.1.1.2 (DF)
Admin State          : enable              Oper State        : up
ESI                  : 00:11:22:33:44:55:66:77:88:99
Multi-homing         : all-active          Oper Multi-homing : all-active
Interface            : ethernet-1/2
ES Activation Timer  : None
DF Election          : default             Oper DF Election  : default
Last Change          : 2021-01-19T11:24:33.330Z
====================================================================================
MAC-VRF   Actv Timer Rem   DF
testing   0                Yes
------------------------------------------------------------------------------------
DF Candidates
------------------------------------------------------------------------------------
Network-instance       ES Peers
blue                   40.1.1.1
blue                   40.1.1.2 (DF)
blue                   40.1.1.3
====================================================================================
--{ [FACTORY] + candidate shared default }--[  ]-- 
```