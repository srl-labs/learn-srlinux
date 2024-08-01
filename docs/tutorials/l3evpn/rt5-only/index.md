---
comments: true
tags:
  - evpn
---
# RT5-only L3 EVPN Tutorial

|                             |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tutorial name**           | RT5-only (aka Interface-less) L3 EVPN-VXLAN with SR Linux                                                                                                                                                                                                                                                                                                                                                                                                                         |
| **Lab components**          | 3 SR Linux nodes, 2 [FRR](https://frrouting.org), 2 Alpine nodes                                                                                                                                                                                                                                                                                                                                                                                                                  |
| **Resource requirements**   | :fontawesome-solid-microchip: 2vCPU <br/>:fontawesome-solid-memory: 8 GB                                                                                                                                                                                                                                                                                                                                                                                                          |
| **Lab Repo**                | [srl-rt5-l3evpn-basics-lab][lab-repo]                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| **Packet captures**         | [EVPN IP Prefix routes exchange][capture-evpn-rt5]                                                                                                                                                                                                                                                                                                                                                                                                                                |
| **Main ref documents**      | [RFC 7432 - BGP MPLS-Based Ethernet VPN](https://datatracker.ietf.org/doc/html/rfc7432)<br/>[RFC 8365 - A Network Virtualization Overlay Solution Using Ethernet VPN (EVPN)](https://datatracker.ietf.org/doc/html/rfc8365)<br/>[RFC 9136 - IP Prefix Advertisement in Ethernet VPN (EVPN)](https://datatracker.ietf.org/doc/html/rfc9136)<br/>[Nokia 7220 SR Linux Advanced Solutions Guide][adv-sol-guide-evpn-l3]<br/>[Nokia 7220 SR Linux EVPN-VXLAN Guide][evpn-vxlan-guide] |
| **Version information**[^1] | [`containerlab:v0.56.0`][clab-install], [`srlinux:24.3.3`][srlinux-container], [`frr:9.0.2`][frr-container] [`docker-ce:26.1.4`][docker-install]                                                                                                                                                                                                                                                                                                                                  |
| **Authors**                 | Korhan Kayhan [:material-linkedin:][kkayhan-linkedin]<br>Roman Dodin [:material-linkedin:][rd-linkedin] [:material-twitter:][rd-twitter]<br/>and reviewers[^3]                                                                                                                                                                                                                                                                                    |

While EVPN originally emerged as a Layer 2 VPN technology to overcome VPLS limitations, it has since evolved to become a unified control plane for many services, Layer 3 VPN included. Founded upon the BGP protocol, EVPN has [lots of flexibility and features](https://www.nokia.com/networks/ethernet-vpn/) to become a one-stop-shop for all VPN services in various network deployments, but especially fit for the IP fabrics.

In the [Layer 2 EVPN Basics Tutorial][evpn-basics-tutorial] we discussed how to configure EVPN to provide a layer 2 service across an IP fabric. Today' focus will be on deploying a **Layer 3 Ethernet VPN (EVPN)** in the SR Linux-powered DC fabric. We will be working with an _interface-less_[^2] flavor of an L3 EVPN service that does not require the use of Integrated Routing and Bridging (IRB) interfaces, and as such has no need MAC VRF instances, ARP/ND entries synchronization, MAC/IP (RT2) and IMET routes.

As you might expect, the Layer 3 EVPN is designed to provide Layer 3 services across the fabric. As such, there are no _stretched_ broadcast domains across the fabric and the customer equipment is directly connected via L3 interfaces to the leafs and often runs a PE-CE routing protocol to exchange IP prefixes.

To explain the Layer 3 EVPN configuration and concepts we will use a lab representing a tiny fabric built with two leafs, one spine and two pairs of clients devices connected to the leafs; one pair per each tenant. The first pair of clients will represent L3 servers connected to leaf ports directly, while the second pair will be represented by an [FRRouting](https://frrouting.org) routers that act a CE router and announce routes.

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":0,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>

As part of this tutorial we will go over two L3 EVPN scenarios. First, we will demonstrate how we can provide connectivity for directly attached L3 clients of Tenant 1. These are the clients that are addressed with L3 interfaces and connected to the leaf devices directly.

<figure>
  <div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":7,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>
  <figcaption>Directly attached L3 clients</figcaption>
</figure>

The second scenario will demonstrate how to connect CE devices of Tenant 2 that establish a BGP session with the leaf devices to exchange IP prefixes. The BGP EVPN will make sure that the client prefixes are distributed to the participants of the same L3 EVPN service of this tenant.

<figure>
  <div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":1,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>
  <figcaption>BGP-enabled CE clients</figcaption>
</figure>

From the data plane perspective we will be using VXLAN tunnels to transport the encapsulated tenant packets through the IP fabric.

As part of this tutorial we will configure the SR Linux-based DC fabric underlay with BGP Unnumbered. Then we will setup the overlay routing using iBGP with EVPN address family and proceed with the creation of an L3 EVPN service for the two tenants of our fabric.

## Lab deployment

To let you follow along the configuration steps of this tutorial we created [a lab][lab-repo] that you can deploy on any Linux VM with [containerlab][clab-install] or run in the cloud with [Codespaces](../../../blog/posts/2024/codespaces.md):

/// tab | Locally

```
sudo containerlab deploy -c -t srl-labs/srl-l3evpn-basics-lab
```

Containerlab will pull the git repo to your current working directory and start deploying the lab.
///
/// tab | With Codespaces

If you want to run the lab in a free cloud instance, click the button below to open the lab in GitHub Codespaces:

<div align=center markdown>
<a href="https://codespaces.new/srl-labs/srl-rt5-l3evpn-basics-lab?quickstart=1">
<img src="https://gitlab.com/rdodin/pics/-/wikis/uploads/d78a6f9f6869b3ac3c286928dd52fa08/run_in_codespaces-v1.svg?sanitize=true" style="width:50%"/></a>

**[Run](https://codespaces.new/srl-labs/srl-rt5-l3evpn-basics-lab?quickstart=1) this lab in GitHub Codespaces for free**.  
[Learn more](https://containerlab.dev/manual/codespaces) about Containerlab for Codespaces.  
<small>Machine type: 2 vCPU · 8 GB RAM</small>
</div>
///

The lab comes up online with the FRR nodes configured, and no configuration is present on the SR Linux nodes besides the basic setup. During the course of this tutorial we will configure the SR Linux nodes and explain the FRR config bits.

If you want to deploy the lab with all configs already applied, just uncomment the `startup-config` knobs in the topology file.

Once the deployment process is finished you'll see a table with the deployed nodes.  
Using the names provided in the table you can SSH into the nodes to start the configuration process. For example, to connect to the `l3evpn-leaf1` node you can use the following command:

```bash
ssh l3evpn-leaf1 #(1)!
```

1. If you happen to have an SSH key the login will be passwordless. If not, `admin:NokiaSrl1!` is the default username and password.

With the lab deployed we are ready to embark on our [learn-by-doing EVPN configuration journey](underlay.md)!

/// note | Are you new to SR Linux?
We advise the newcomers not to skip the [Configuration Basics Guide][conf-basics-guide] as it provides just enough details to survive in the configuration waters we are about to get in.
///

[lab-repo]: https://github.com/srl-labs/srl-l3evpn-tutorial-lab/
[clab-install]: https://containerlab.dev/install/
[srlinux-container]: https://github.com/orgs/nokia/packages/container/package/srlinux
[frr-container]: https://quay.io/repository/frrouting/frr?tab=tags
[docker-install]: https://docs.docker.com/engine/install/
[capture-evpn-rt5]: https://gitlab.com/rdodin/pics/-/wikis/uploads/e0d9687ad72413769e4407eb4e498f71/bgp-underlay-overlay-ex1.pcapng
[adv-sol-guide-evpn-l3]: https://documentation.nokia.com/srlinux/24-3/books/advanced-solutions/evpn-vxlan-layer-3.html#evpn-vxlan-layer-3
[evpn-vxlan-guide]: https://documentation.nokia.com/srlinux/24-3/books/evpn-vxlan/evpn-vxlan-tunnels-layer-3.html#evpn-vxlan-tunnels-layer-3
[conf-basics-guide]: https://documentation.nokia.com/srlinux/24-3/title/basics.html
[evpn-basics-tutorial]: ../../l2evpn/intro.md
[rd-linkedin]: https://linkedin.com/in/rdodin
[rd-twitter]: https://twitter.com/ntdvps
[kkayhan-linkedin]: https://www.linkedin.com/in/korhan-kayhan-b6b45065/
[mr-linkedin]: https://www.linkedin.com/in/michelredondo/

[^1]: the following versions have been used to create this tutorial. The newer versions might work, but if they don't, please pin the version to the mentioned ones.
[^2]: Two L3 EVPN service models are defined in [RFC 9136](https://datatracker.ietf.org/doc/html/rfc9136#name-ip-vrf-to-ip-vrf-model) - namely Interface-less and Interface-full. The focus of this tutorial is on the Interface-less model.
[^3]: [Michel Redondo](https://learn.srlinux.dev/blog/author/michelredondo), [Sergey Fomin](https://learn.srlinux.dev/blog/author/sfomin), [Anton Zyablov](https://learn.srlinux.dev/blog/author/azyablov), [Jeroen van Bemmel](https://learn.srlinux.dev/blog/author/jbemmel), [Jorge Rabadan](https://datatracker.ietf.org/person/jorge.rabadan@nokia.com).

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
