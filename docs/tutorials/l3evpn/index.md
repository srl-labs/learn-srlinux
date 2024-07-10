---
comments: true
tags:
  - evpn
---
# Introduction

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>

|                             |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tutorial name**           | L3 EVPN-VXLAN with SR Linux                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| **Lab components**          | 3 SR Linux nodes & 2 [FRR](https://frrouting.org)                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **Resource requirements**   | :fontawesome-solid-microchip: 3vCPU <br/>:fontawesome-solid-memory: 8 GB                                                                                                                                                                                                                                                                                                                                                                                                          |
| **Lab Repo**                | [srl-l3evpn-basics-lab][lab-repo]                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **Packet captures**         | [EVPN IP Prefix routes exchange][capture-evpn-rt5]                                                                                                                                                                                                                                                                                                                                                                                                                                |
| **Main ref documents**      | [RFC 7432 - BGP MPLS-Based Ethernet VPN](https://datatracker.ietf.org/doc/html/rfc7432)<br/>[RFC 8365 - A Network Virtualization Overlay Solution Using Ethernet VPN (EVPN)](https://datatracker.ietf.org/doc/html/rfc8365)<br/>[RFC 9136 - IP Prefix Advertisement in Ethernet VPN (EVPN)](https://datatracker.ietf.org/doc/html/rfc9136)<br/>[Nokia 7220 SR Linux Advanced Solutions Guide][adv-sol-guide-evpn-l3]<br/>[Nokia 7220 SR Linux EVPN-VXLAN Guide][evpn-vxlan-guide] |
| **Version information**[^1] | [`containerlab:v0.56.0`][clab-install], [`srlinux:24.3.3`][srlinux-container], [`frr:9.0.2`][frr-container] [`docker-ce:26.1.4`][docker-install]                                                                                                                                                                                                                                                                                                                                  |

EVPN serves as a control plane protocol for MAC address dissemination among routers, offering a scalable and efficient solution.
VxLAN is a datapath encapsulation, addresses the scalability issues of conventional VLANs by encapsulating Ethernet frames within UDP packets.
Together, EVPN and VxLAN facilitate the encapsulation of Layer 2 and Layer 3 traffic over an underlying IP network.

This tutorial will lead you through configuring the DC fabric underlay. It will then cover the creation of an L3 EVPN overlay across two routers functioning as a unified virtual router. In the final chapter, it details how to peer the client with the EVPN overlay for route exchange.

Our lab setup will resemble the following configuration: it will feature two Leaf devices linked to a Spine, collectively referred to as the DC Fabric. Attached to each Leaf, there will be a client that also functions as a CE router, capable of communicating routing protocols with the fabric. We will employ FRR for this task. For detailed information on the CE Router (Client), please check https://frrouting.org.

<p align="center">
  <img src="https://raw.githubusercontent.com/srl-labs/srl-l3evpn-tutorial-lab/main/images/initial-to-final.png" alt="Fabric Diagram">
</p>

## Lab deployment

To let you follow along the configuration steps of this tutorial we created a lab that you can deploy on any Linux VM:

The containerlab topo file and Client (FRR) startup configs can be found in the [git repo](https://github.com/srl-labs/srl-l3evpn-tutorial-lab/):

You can deploy the lab on your Linux machine like:

```
clab deploy -t https://github.com/srl-labs/srl-l3evpn-tutorial-lab.git
INFO[0000] Containerlab v0.56.0 started                 
INFO[0000] Parsing & checking topology file: l3evpn-tutorial.clab.yml 
WARN[0000] Unable to load kernel module "ip_tables" automatically "load ip_tables failed: exec format error" 
INFO[0000] Creating lab directory: /home/srl-l3evpn-tutorial-lab/clab-l3evpn 
INFO[0000] Creating container: "leaf1"                  
INFO[0000] Creating container: "frr1"                   
INFO[0000] Creating container: "frr2"                   
INFO[0000] Creating container: "spine"                  
INFO[0000] Creating container: "leaf2"                  
INFO[0001] Created link: leaf1:e1-1 <--> frr1:eth1      
INFO[0001] Running postdeploy actions for Nokia SR Linux 'leaf1' node 
INFO[0001] Created link: spine:e1-1 <--> leaf1:e1-49    
INFO[0001] Created link: spine:e1-2 <--> leaf2:e1-49    
INFO[0001] Running postdeploy actions for Nokia SR Linux 'spine' node 
INFO[0001] Created link: leaf2:e1-1 <--> frr2:eth1      
INFO[0001] Running postdeploy actions for Nokia SR Linux 'leaf2' node 
INFO[0032] Executed command "ip link set dev eth0 down" on the node "frr1". stdout: 
INFO[0032] Executed command "ip link set dev eth0 down" on the node "frr2". stdout: 
INFO[0032] Adding containerlab host entries to /etc/hosts file 
INFO[0032] Adding ssh config for containerlab nodes     
+---+-------------------+--------------+------------------------------+---------------+---------+----------------+----------------------+
| # |       Name        | Container ID |            Image             |     Kind      |  State  |  IPv4 Address  |     IPv6 Address     |
+---+-------------------+--------------+------------------------------+---------------+---------+----------------+----------------------+
| 1 | clab-l3evpn-frr1  | faa938ea15f3 | quay.io/frrouting/frr:9.0.2  | linux         | running | 172.20.20.3/24 | 2001:172:20:20::3/64 |
| 2 | clab-l3evpn-frr2  | c719385f191d | quay.io/frrouting/frr:9.0.2  | linux         | running | 172.20.20.6/24 | 2001:172:20:20::6/64 |
| 3 | clab-l3evpn-leaf1 | db43362a1c1f | ghcr.io/nokia/srlinux:24.3.3 | nokia_srlinux | running | 172.20.20.2/24 | 2001:172:20:20::2/64 |
| 4 | clab-l3evpn-leaf2 | d0ac084367fd | ghcr.io/nokia/srlinux:24.3.3 | nokia_srlinux | running | 172.20.20.4/24 | 2001:172:20:20::4/64 |
| 5 | clab-l3evpn-spine | 79bf719d2df4 | ghcr.io/nokia/srlinux:24.3.3 | nokia_srlinux | running | 172.20.20.5/24 | 2001:172:20:20::5/64 |
+---+-------------------+--------------+------------------------------+---------------+---------+----------------+----------------------+
```

Containerlab will pull the git repo to your local working directory and a few seconds later containerlab finishes the deployment with providing a summary table that outlines connection details of the deployed nodes like shown above. In the "Name" column we have the names of the deployed containers and those names can be used to reach the nodes, for example to connect to the SSH of `leaf1`:

```bash
# default credentials admin:NokiaSrl1!
ssh clab-l3evpn-leaf1
```

With the lab deployed we are ready to embark on our learn-by-doing EVPN configuration journey!

/// note
We advise the newcomers not to skip the [Configuration Basics Guide][conf-basics-guide] as it provides just enough details to survive in the configuration waters we are about to get in.
///

[lab-repo]: https://github.com/srl-labs/srl-l3evpn-tutorial-lab/
[clab-install]: https://containerlab.dev/install/
[srlinux-container]: https://github.com/orgs/nokia/packages/container/package/srlinux
[frr-container]: https://quay.io/repository/frrouting/frr?tab=tags
[docker-install]: https://docs.docker.com/engine/install/
[capture-evpn-rt5]: https://github.com/srl-labs/srl-l3evpn-tutorial-lab/blob/main/evpn_rt5.pcap
[adv-sol-guide-evpn-l3]: https://documentation.nokia.com/srlinux/24-3/books/advanced-solutions/evpn-vxlan-layer-3.html#evpn-vxlan-layer-3
[evpn-vxlan-guide]: https://documentation.nokia.com/srlinux/24-3/books/evpn-vxlan/evpn-vxlan-tunnels-layer-3.html#evpn-vxlan-tunnels-layer-3
[conf-basics-guide]: https://documentation.nokia.com/srlinux/24-3/title/basics.html

[^1]: the following versions have been used to create this tutorial. The newer versions might work, but if they don't, please pin the version to the mentioned ones.
