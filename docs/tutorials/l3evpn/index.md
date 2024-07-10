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
| **Resource requirements**   | :fontawesome-solid-microchip: 2vCPU <br/>:fontawesome-solid-memory: 8 GB                                                                                                                                                                                                                                                                                                                                                                                                          |
| **Lab Repo**                | [srl-l3evpn-basics-lab][lab-repo]                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **Packet captures**         | [EVPN IP Prefix routes exchange][capture-evpn-rt5]                                                                                                                                                                                                                                                                                                                                                                                                                                |
| **Main ref documents**      | [RFC 7432 - BGP MPLS-Based Ethernet VPN](https://datatracker.ietf.org/doc/html/rfc7432)<br/>[RFC 8365 - A Network Virtualization Overlay Solution Using Ethernet VPN (EVPN)](https://datatracker.ietf.org/doc/html/rfc8365)<br/>[RFC 9136 - IP Prefix Advertisement in Ethernet VPN (EVPN)](https://datatracker.ietf.org/doc/html/rfc9136)<br/>[Nokia 7220 SR Linux Advanced Solutions Guide][adv-sol-guide-evpn-l3]<br/>[Nokia 7220 SR Linux EVPN-VXLAN Guide][evpn-vxlan-guide] |
| **Version information**[^1] | [`containerlab:v0.56.0`][clab-install], [`srlinux:24.3.3`][srlinux-container], [`frr:9.0.2`][frr-container] [`docker-ce:26.1.4`][docker-install]                                                                                                                                                                                                                                                                                                                                  |
| **Authors**                 | Korhan Kayhan [:material-linkedin:][kkayhan-linkedin]<br>Michel Redondo [:material-linkedin:][mr-linkedin]<br/>Roman Dodin [:material-linkedin:][rd-linkedin] [:material-twitter:][rd-twitter]                                                                                                                                                                                                                                                                                    |

While EVPN originally emerged as a Layer 2 VPN technology to overcome VPLS limitations, it has since evolved to support other applications, like Layer 3 VPN services.

We have covered the basics of Layer 2 EVPN in the [Layer 2 EVPN Basics Tutorial][evpn-basics-tutorial] where we discussed how to configure EVPN to provide a layer 2 service across an IP fabric.  
Today' focus will be on deploying a **Layer 3 Ethernet VPN (EVPN)** in the SR Linux-powered DC fabric.  
As you might expect, the Layer 3 EVPN is designed to provide Layer 3 services across the fabric. As such, there are **no** stretched broadcast domains across the fabric and the customer equipment is typically running a BGP PE-CE session with the top of rack switch to exchange IP prefixes.

To explain the Layer 3 EVPN configuration and concepts we will use a small fabric with two leafs, one spine and two clients connected to the leafs. The clients will run FRRouting software as a CE router.

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":0,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>

Service-wise, and in contrast to the Layer 2 EVPN, the CE devices will establish a BGP session with the leaf devices to exchange IP prefixes and the Layer 3 EVPN service will make sure that the client prefixes are reachable across the fabric.

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":1,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>

As part of this tutorial we will configure the SR Linux-based DC fabric underlay. Then cover the creation of an L3 EVPN overlay across two routers functioning as a unified virtual router. In the final chapter, we will get into the details how to peer the client with the EVPN overlay for the route exchange.

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
[evpn-basics-tutorial]: ../l2evpn/intro.md
[rd-linkedin]: https://linkedin.com/in/rdodin
[rd-twitter]: https://twitter.com/ntdvps
[kkayhan-linkedin]: https://www.linkedin.com/in/korhan-kayhan-b6b45065/
[mr-linkedin]: https://www.linkedin.com/in/michelredondo/
[^1]: the following versions have been used to create this tutorial. The newer versions might work, but if they don't, please pin the version to the mentioned ones.
