---
comments: true
tags:
  - ldp
  - mpls
---

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>

|                                |                                                                                                                                                                                                                  |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tutorial name**              | LDP-based MPLS core                                                                                                                                                                                              |
| **Lab components**             | 3 Nokia SR Linux nodes                                                                                                                                                                                           |
| **Resource requirements**      | :fontawesome-solid-microchip: 2vCPU <br/>:fontawesome-solid-memory: 4 GB                                                                                                                                         |
| **Containerlab topology file** | [mpls-ldp.clab.yml][topofile]                                                                                                                                                                                    |
| **Packet captures**            | [· LDP neighborship][pcap1]<br/>[· MPLS encapsulation][pcap2]                                                                                                                                                    |
| **Main ref documents**         | [· RFC 5036 - LDP Specification](https://datatracker.ietf.org/doc/html/rfc5036)<br/>[· Nokia SR Linux MPLS Guide](https://documentation.nokia.com/srlinux/SR_Linux_HTML_R21-11/MPLS_Guide/mpls-overview.html#mpls-overview) |
| **Version information**[^1]    | [`containerlab:0.24.1`][clab-install], [`srlinux:21.11.2`][srlinux-container], [`docker-ce:20.10.2`][docker-install]                                                                                             |

Multiprotocol Label Switching (MPLS) is a label switching technology that provides the ability to set up connection-oriented paths over a connection-less IP network. MPLS facilitates network traffic flow and provides a mechanism to engineer network traffic patterns independently from routing tables. MPLS sets up a specific path for a sequence of packets. The packets are identified by a label stack inserted into each packet.

This short tutorial will guide you through the steps required to build an [LDP-based](https://datatracker.ietf.org/doc/html/rfc5036) MPLS core consisting of three SR Linux routers. LDP-based MPLS tunnels are commonly used to enable [BGP-free core network](http://bgphelp.com/2017/02/12/bgp-free-core/).

/// warning
MPLS features are currently (at the time of this writing) supported only on SR Linux 7250 IXR-6e/10e and 7730 SXR platforms. Container images emulating these platforms require a license to operate.

Without the license provided, the lab will not start.
///

The topology we will use for this interactive tutorial is quite simple - three routers connected in a point-to-point fashion:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:0,&quot;zoom&quot;:3,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/mpls-ldp.drawio&quot;}"></div>

The MPLS-enabled core will be formed with `srl1` and `srl3` acting as Label Edge Routers (LER) and `srl2` as Label Switch Router (LSR). The loopback `lo0` interfaces configured on LERs will emulate clients talking to each other via an established MPLS tunnel.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:1,&quot;zoom&quot;:3,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/mpls-ldp.drawio&quot;}"></div>

The tutorial will consist of the following configuration parts:

* [Core routing](routing.md) - configuring interfaces, network instances and IS-IS IGP protocol.
* [LDP-based MPLS](ldp.md) - configuring LDP and running control plane and data plane verification steps.

## Lab deployment

The tutorial is augmented with the [containerlab-based](https://containerlab.dev) lab so that you can perform all the steps we do here.  
The [clab file][topofile] describing the topology looks like follows:

```yaml
--8<-- "labs/mpls-ldp/mpls-ldp.clab.yml"
```

Save[^2] the contents of this file under `mpls-ldp.clab.yml` name, and you are ready to deploy:

```bash
$ containerlab deploy -t clab-ldp.clab.yml

# output omitted for brevity

+---+------+--------------+------------------------------+------+---------+----------------+----------------------+
| # | Name | Container ID |            Image             | Kind |  State  |  IPv4 Address  |     IPv6 Address     |
+---+------+--------------+------------------------------+------+---------+----------------+----------------------+
| 1 | srl1 | e2056be1382d | ghcr.io/nokia/srlinux:23.3.1 | srl  | running | 172.20.20.4/24 | 2001:172:20:20::4/64 |
| 2 | srl2 | 99579a0827d4 | ghcr.io/nokia/srlinux:23.3.1 | srl  | running | 172.20.20.3/24 | 2001:172:20:20::3/64 |
| 3 | srl3 | 747a4d80cf9d | ghcr.io/nokia/srlinux:23.3.1 | srl  | running | 172.20.20.7/24 | 2001:172:20:20::7/64 |
+---+------+--------------+------------------------------+------+---------+----------------+----------------------+
```

A few seconds later, containerlab finishes the deployment by providing a summary table that outlines connection details of the deployed nodes. In the "Name" column we have the names of the deployed containers which can be used to reach the nodes. For example to connect to the SSH server of `srl1`:

```bash
# default credentials admin:NokiaSrl1!
ssh admin@srl1
```

With the lab deployed, we are ready to embark on our learn-by-doing LDP-based MPLS configuration journey!

[topofile]: https://github.com/srl-labs/learn-srlinux/blob/main/labs/mpls-ldp/mpls-ldp.clab.yml
[clab-install]: https://containerlab.dev/install/
[srlinux-container]: https://github.com/nokia/srlinux-container-image
[docker-install]: https://docs.docker.com/engine/install/
[pcap1]: https://github.com/srl-labs/learn-srlinux/blob/main/docs/tutorials/mpls/mpls-ldp/ldp-neighborship.pcapng
[pcap2]: https://github.com/srl-labs/learn-srlinux/blob/main/docs/tutorials/mpls/mpls-ldp/icmp-mpls.pcapng

[^1]: the following versions have been used to create this tutorial. The newer versions might work; please pin the version to the mentioned ones if they don't.
[^2]: Or download it with `curl -LO https://github.com/srl-labs/learn-srlinux/blob/main/labs/mpls-ldp/mpls-ldp.clab.yml`
