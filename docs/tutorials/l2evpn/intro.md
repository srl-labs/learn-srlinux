---
comments: true
---

<script type="text/javascript" src="https://cdn.jsdelivr.net/gh/hellt/drawio-js@main/embed2.js" async></script>

|                                |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tutorial name**              | L2 EVPN-VXLAN with SR Linux                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **Lab components**             | 3 SR Linux nodes                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| **Resource requirements**      | :fontawesome-solid-microchip: 2vCPU <br/>:fontawesome-solid-memory: 6 GB                                                                                                                                                                                                                                                                                                                                                                                                                    |
| **Containerlab topology file** | [evpn01.clab.yml][topofile]                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **Lab name**                   | evpn01                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **Packet captures**            | [EVPN IMET routes exchange][capture-imets], [RT2 routes exchange with ICMP in datapath][capture-rt2-datapath]                                                                                                                                                                                                                                                                                                                                                                               |
| **Main ref documents**         | [RFC 7432 - BGP MPLS-Based Ethernet VPN](https://www.rfcreader.com/#rfc7432)<br/>[RFC 8365 - A Network Virtualization Overlay Solution Using Ethernet VPN (EVPN)](https://www.rfcreader.com/#rfc8365)<br/>[Nokia 7220 SR Linux Advanced Solutions Guide](https://documentation.nokia.com/srlinux/22-11/SR_Linux_Book_Files/Advanced_Solutions_Guide/evpn-l2-multihome.html)<br/>[Nokia 7220 SR Linux EVPN-VXLAN Guide](https://documentation.nokia.com/srlinux/22-11/title/evpn_vxlan.html) |
| **Version information**[^1]    | [`containerlab:0.34.0`][clab-install], [`srlinux:22.11.1`][srlinux-container], [`docker-ce:20.10.2`][docker-install]                                                                                                                                                                                                                                                                                                                                                                        |

Ethernet Virtual Private Network (EVPN) is a standard technology in multi-tenant Data Centers (DCs) and provides a control plane framework for many functions.  
In this tutorial we will configure a **VXLAN based Layer 2 EVPN service**[^3] in a tiny CLOS fabric and at the same get to know SR Linux better!

The DC fabric that we will build for this tutorial consists of the two leaf switches (acting as Top-Of-Rack) and a single spine:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:0,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/quickstart.drawio&quot;}"></div>

The two servers are connected to the leafs via an L2 interface. Service-wise the servers will appear to be on the same L2 network by means of the deployed EVPN Layer 2 service.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:1,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/quickstart.drawio&quot;}"></div>

The tutorial will consist of the following major parts:

* [Fabric configuration](fabric.md) - here we will configure the routing protocol in the underlay of a fabric to advertise the Virtual Tunnel Endpoints (VTEP) of the leaf switches.
* [EVPN configuration](evpn.md) - this chapter is dedicated to the EVPN service configuration and validation.

## Lab deployment

To let you follow along the configuration steps of this tutorial we created a lab that you can deploy on any Linux VM:

The [containerlab file][topofile] that describes the lab topology is referenced below in full:

```yaml
name: evpn01

topology:
  kinds:
    srl:
      image: ghcr.io/nokia/srlinux
    linux:
      image: ghcr.io/hellt/network-multitool

  nodes:
    leaf1:
      kind: srl
      type: ixrd2
    leaf2:
      kind: srl
      type: ixrd2
    spine1:
      kind: srl
      type: ixrd3
    srv1:
      kind: linux
    srv2:
      kind: linux

  links:
    # inter-switch links
    - endpoints: ["leaf1:e1-49", "spine1:e1-1"]
    - endpoints: ["leaf2:e1-49", "spine1:e1-2"]
    # server links
    - endpoints: ["srv1:eth1", "leaf1:e1-1"]
    - endpoints: ["srv2:eth1", "leaf2:e1-1"]
```

Save[^2] the contents of this file under `evpn01.clab.yml` name and you are ready to deploy:

```
$ containerlab deploy -t evpn01.clab.yml
INFO[0000] Parsing & checking topology file: evpn01.clab.yml 
INFO[0000] Creating lab directory: /root/learn.srlinux.dev/clab-evpn01 
INFO[0000] Creating root CA                             
INFO[0001] Creating container: srv2                  
INFO[0001] Creating container: srv1                  
INFO[0001] Creating container: leaf2                    
INFO[0001] Creating container: spine1                   
INFO[0001] Creating container: leaf1                    
INFO[0002] Creating virtual wire: leaf1:e1-49 <--> spine1:e1-1 
INFO[0002] Creating virtual wire: srv2:eth1 <--> leaf2:e1-1 
INFO[0002] Creating virtual wire: leaf2:e1-49 <--> spine1:e1-2 
INFO[0002] Creating virtual wire: srv1:eth1 <--> leaf1:e1-1 
INFO[0003] Writing /etc/hosts file                      

+---+--------------------+--------------+---------------------------------+-------+-------+---------+----------------+----------------------+
| # |        Name        | Container ID |              Image              | Kind  | Group |  State  |  IPv4 Address  |     IPv6 Address     |
+---+--------------------+--------------+---------------------------------+-------+-------+---------+----------------+----------------------+
| 1 | clab-evpn01-leaf1  | 4b81c65af558 | ghcr.io/nokia/srlinux           | srl   |       | running | 172.20.20.7/24 | 2001:172:20:20::7/64 |
| 2 | clab-evpn01-leaf2  | de000e791dd6 | ghcr.io/nokia/srlinux           | srl   |       | running | 172.20.20.8/24 | 2001:172:20:20::8/64 |
| 3 | clab-evpn01-spine1 | 231fd97d7e33 | ghcr.io/nokia/srlinux           | srl   |       | running | 172.20.20.6/24 | 2001:172:20:20::6/64 |
| 4 | clab-evpn01-srv1   | 3a2fa1e6e9f5 | ghcr.io/hellt/network-multitool | linux |       | running | 172.20.20.3/24 | 2001:172:20:20::3/64 |
| 5 | clab-evpn01-srv2   | fb722453d715 | ghcr.io/hellt/network-multitool | linux |       | running | 172.20.20.5/24 | 2001:172:20:20::5/64 |
+---+--------------------+--------------+---------------------------------+-------+-------+---------+----------------+----------------------+
```

A few seconds later containerlab finishes the deployment with providing a summary table that outlines connection details of the deployed nodes. In the "Name" column we have the names of the deployed containers and those names can be used to reach the nodes, for example to connect to the SSH of `leaf1`:

```bash
# default credentials admin:admin
ssh admin@clab-evpn01-leaf1
```

With the lab deployed we are ready to embark on our learn-by-doing EVPN configuration journey!

!!!note
    We advise the newcomers not to skip the [SR Linux basic concepts](../../kb/hwtypes.md) chapter as it provides just enough[^4] details to survive in the configuration waters we are about to get.

[topofile]: https://github.com/srl-labs/learn-srlinux/blob/master/labs/evpn01.clab.yml
[clab-install]: https://containerlab.srlinux.dev/install/
[srlinux-container]: https://github.com/orgs/nokia/packages/container/package/srlinux
[docker-install]: https://docs.docker.com/engine/install/
[capture-imets]: https://github.com/srl-labs/learn-srlinux/blob/master/docs/tutorials/l2evpn/evpn01-imet-routes.pcapng
[capture-rt2-datapath]: https://github.com/srl-labs/learn-srlinux/blob/master/docs/tutorials/l2evpn/evpn01-macip-routes.pcapng

[^1]: the following versions have been used to create this tutorial. The newer versions might work, but if they don't, please pin the version to the mentioned ones.
[^2]: Or download it with `curl -LO https://github.com/srl-labs/learn-srlinux/blob/master/labs/evpn01.clab.yml`
[^3]: Per [RFC 8365](https://datatracker.ietf.org/doc/html/rfc8365) & [RFC 7432](https://datatracker.ietf.org/doc/html/rfc7432)
[^4]: For a complete documentation coverage don't hesitate to visit our [documentation portal](https://bit.ly/iondoc).
