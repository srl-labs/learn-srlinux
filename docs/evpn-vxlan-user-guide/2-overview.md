This chapter contains the following topics:

## 2.1. About EVPN
Ethernet Virtual Private Network (EVPN) is a technology that allows Layer 2 traffic to be bridged across an IP network. EVPN instances configured on Provider Edge (PE) routers function as virtual bridges, transporting traffic between Customer Edge (CE) devices at separate locations.

At a basic level, the PE routers exchange information about reachability, encapsulate Layer 2 traffic from CE devices, and forward it across the Layer 3 network. EVPN is the de-facto standard technology in multi-tenant Data Centers (DCs).

VXLAN is a means for segmenting a LAN at a scale required by service providers. With the prevalent use of VXLAN in multi-tenant DCs, the EVPN control plane was adapted for VXLAN tunnels in RFC8365.

The SR Linux EVPN-VXLAN solution supports using Layer 2 Broadcast Domains (BDs) in multi-tenant data centers using EVPN for the control plane and VXLAN as the data plane.

## 2.2. About Layer 2 services
Layer 2 services refers to the infrastructure implemented on SR Linux to support tunneling of Layer 2 traffic across an IP network, overlaying the Layer 2 network on top of the IP network.

To do this, SR Linux uses a network instance of type mac-vrf. The mac-vrf network instance is associated with a network instance of type default or ip-vrf via an Integrated Routing and Bridging (IRB) interface.

[Figure 1](#fig1) shows the relationship between an IRB interface and mac-vrf, and ip-vrf network instance types.

<figure>
  <img id="fig1" src="https://infocenter.nokia.com/public/SRLINUX213R1A/topic/com.srlinux.evpnl2l3/html/graphics/l2-services.gif"/>
  <figcaption>Figure 1: MAC-VRF, IRB interface, and IP-VRF</figcaption>
</figure>

See Layer 2 services infrastructure for information about Layer 2 services on SR Linux, including configuring mac-vrfs, ip-vrfs, and IRB interfaces.

## 2.3. About EVPN for VXLAN tunnels (Layer 2)
The primary usage for EVPN for VXLAN tunnels (Layer 2) is the extension of a BD in overlay multi-tenant DCs. This kind of topology is illustrated in [Figure 2](#fig2).

<figure>
  <img id="fig2" src="https://infocenter.nokia.com/public/SRLINUX213R1A/topic/com.srlinux.evpnl2l3/html/graphics/sw4052.gif"/>
  <figcaption>Figure 2: BD extension in overlay DCs</figcaption>
</figure>


SR Linux features that support this topology fall into the following categories:

1. Bridged subinterface extensions, including:
    * Default subinterface, which captures untagged and non-explicitly configured VLAN-tagged frames on tagged subinterfaces.
    * Transparency of inner qtags not being used for service classification.
2. EVPN-VXLAN control and data plane extensions as described in RFC 8365:
    * EVPN routes type MAC/IP and IMET
    * VXLANv4 model for MAC-VRFs
3. Distributed security and protection, including:
    * An extension to the MAC duplication mechanism that can be applied to MACs received from EVPN.
    * Protection of static MACs and learned-static MACs
4. EVPN L2 multi-homing, including:
    * The ES model definition for all-active multi-homing
    * Split Horizon Group (SHG)
    * Load-balancing and redundancy using aliasing

[EVPN for VXLAN tunnels (Layer 2)](5-evpn-for-vxlan-tunnels-layer-2.md) describes the components of EVPN-VXLAN Layer 2 on SR Linux.

## 2.4. About EVPN for VXLAN tunnels (Layer 3)
The primary usage for EVPN for VXLAN tunnels (Layer 3) is inter-subnet-forwarding for unicast traffic within the same tenant infrastructure. This kind of topology is illustrated in Figure 3.

<figure>
  <img id="fig2" src="https://infocenter.nokia.com/public/SRLINUX213R1A/topic/com.srlinux.evpnl2l3/html/graphics/sw4060.gif"/>
  <figcaption>Figure 3: Inter-subnet forwarding with EVPN-VXLAN L3</figcaption>
</figure>


SR Linux features that support this topology fall into the following categories:

1. EVPN-VXLAN L3 control plane (RT5) and data plane as described in draft-ietf-bess-evpn-prefix-advertisement.
2. EVPN L3 multi-homing on MAC-VRFs with IRB interfaces that use anycast GW IP and MAC addresses in all leafs attached to the same BD.
3. Host route mobility procedures to allow fast mobility of hosts between leaf nodes attached to the same BD.

Other supported features include:

* Interface-less (IFL) model interoperability with unnumbered interface-ful (IFF) model
* ECMP over EVPN
* Support for interface-level OAM (ping) in anycast deployments

[EVPN for VXLAN tunnels (Layer 3)](6-evpn-for-vxlan-tunnels-layer-3.md) describes the components of EVPN-VXLAN Layer 3 on SR Linux.