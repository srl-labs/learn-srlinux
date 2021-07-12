<script type="text/javascript" src="https://cdn.jsdelivr.net/gh/hellt/drawio-js@main/embed2.js" async></script>

Ethernet Virtual Private Network (EVPN) is a standard technology in multi-tenant Data Centers (DCs) and provides a control plane framework for many functions.  
In this quickstart tutorial we will configure a **VXLAN based EVPN service** in a tiny CLOS fabric and at the same get to know SR Linux better!

The DC fabric that we will build consists of the two leaf switches (acting as TOR) and a single spine:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:0,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/learn-srlinux/site/diagrams/quickstart.drawio&quot;}"></div>

The two servers are connected to the leafs via a L2 interface. Service-wise the servers will appear to be on the same L2 network by means of the deployed EVPN service.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:1,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/learn-srlinux/site/diagrams/quickstart.drawio&quot;}"></div>

The tutorial will consist of the following major parts:

* [Fabric configuration](fabric.md) - here we will configure the routing protocol (eBGP) in the underlay of a fabric to advertise the Virtual Tunnel Endpoints (VTEP) of the leaf switches.
* [EVPN configuration](evpn.md) - this chapter is dedicated to the actual EVPN service configuration.

## Lab

To let you follow along the configuration steps of this tutorial we created a lab that you can deploy on any Linux VM:

|                             |                                                                          |
| --------------------------- | ------------------------------------------------------------------------ |
| **Description**             | L2 EVPN with SR Linux                                                    |
| **Resource requirements**   | :fontawesome-solid-microchip: 2vCPU <br/>:fontawesome-solid-memory: 4 GB |
| **Topology file**           | [evpn01.clab.yml][topofile]                                              |
| **Lab name**                | evpn01                                                                   |
| **Version information**[^3] | `containerlab:0.15.0`, `srlinux:21.6.1-235`, `docker-ce:20.10.2`         |

The containerlab file contents are outlined below:

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

Save[^4] the contents of this file under `evpn01.clab.yml` name and you are ready to deploy:
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

Containerlab will finish the deployment with providing a summary table that outlines connection details of the deployed nodes. In the "Name" column we have the names of the deployed containers and those names can be used to reach the nodes, for example:

```bash
# connecting to the leaf1 device via SSH
ssh admin@clab-evpn01-leaf1
```

With the lab deployed we are ready to embark on our learn-by-doing EVPN configuration journey!

!!!note
    We advise the newcomers not to skip the next stop at [SR Linux basic concepts](../basics/hwtypes.md) as it provides just enough[^2] details to survive in the configuration waters we are about to get.

[topofile]: https://github.com/learn-srlinux/site/blob/master/labs/evpn01.clab.yml

[^1]: To ensure reproducibility and consistency of the examples provided in this quickstart, we will pin to a particular SR Linux version in the containerlab file.
[^2]: For a complete documentation coverage don't hesitate to visit our [documentation portal](https://bit.ly/iondoc).
[^3]: the following versions have been used to create this tutorial. The newer versions might work, but if they pin the version to the mentioned ones.
[^4]: Or download it with `curl -LO https://github.com/learn-srlinux/site/blob/master/labs/evpn01.clab.yml`