---
comments: true
---

<script type="text/javascript" src="https://cdn.jsdelivr.net/gh/hellt/drawio-js@main/embed2.js" async></script>

In this tutorial, the primary focus was deploying Layer 3 Ethernet VPN (EVPN) using Nokia's SR Linux. This networking solution enables the creation of a distributed routing instance spanning across multiple routers leveraging Virtual Extensible LAN (VxLAN) tunnels over an IP backbone.

A critical part of this architecture's success lies in the use of different EVPN route types. These route types facilitate the dissemination of MAC addresses, IP prefixes, and Ethernet segments across the network, contributing to optimal forwarding decisions and redundancy mechanisms. 

In EVPN L3 Network Instances, EVPN RT-5 ( Route Type 5 ) is used to advertise IP prefixes. EVPN RT-2 may also be used for a specific purpose that we will explain in the section below.

There are two models for implementing L3 routing with EVPN.

## Interface-less ( IFL )
Interface-less model only uses EVPN route type 5 to announce prefixes that populate the routing tables. If we look at the packet flow, the packet arrives from the client to the ip-vrf (L3 EVPN instance) and a route-table lookup is done, next hop resolves into a VxLAN tunnel and destination EVPN instance is identified by the VNI (Virtual Network Identifier). This model is simple and very similar to IP-VPN. SRLinux currently supports this model.

<p align="center">
  <img src="https://raw.githubusercontent.com/srl-labs/srl-l3evpn-tutorial-lab/main/images/ip-vrf-wo-pece.png" alt="Overlay Diagram">
</p>


## Interface-ful ( IFF )
Interface-ful model employs a specific L2 EVPN service known as "Supplementary Broadcast Domain" (SBD) to join L3 EVPN instances. Each L3 EVPN instance is linked via an IRB interface to the SBD, which serves as a central backbone connecting all L3 instances throughout the data center. The routing table entries for L3 instances are resolved into local-IRB interfaces, and through a further recursive lookup on the SBD, packets are directed to a remote-IRB interface, with the next hop being a VxLAN tunnel.

Prefixes are announced using EVPN Route Type 5, similar to the Interface-less model. Besides that, IRB interface’s reachability information is announced using Route Type 2. Essentially RT-5 routes (client prefixes) resolve into the destinations (IRB) announced by RT-2.

The advantage of this approach is that if a device fails, all prefixes received by RT-5 need to be invalidated. Since these prefixes resolve into an IRB interface announced by RT-2, we can invalidate all impacted prefixes by withdrawing the RT-2. Instead of sending withdrawal messages for thousands of RT-5 routes, we send a single withdrawal for the RT-2, significantly improving convergence.

Like we said above the reachability information of IRB interfaces are announced using RT-2 ( MAC/IP route ).
The user either has to configure an IP address for each IRB interface and the IRB MAC/IP is announced to other peers via RT-2.
It is also possible to have the IRB interface without an IP address, in this way only a MAC address is announced via RT-2. This is called Interface-ful unnumbered model.

When RT-5 announces prefixes, it must include the IRB-IP or IRB-MAC in the RT-5 communities so that the peer knows which IRB interface to use for prefix resolution.

<p align="center">
  <img src="https://raw.githubusercontent.com/srl-labs/srl-l3evpn-tutorial-lab/main/images/IFF.png" alt="Overlay Diagram">
</p>