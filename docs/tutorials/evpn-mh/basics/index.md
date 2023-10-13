---
comments: true
tags:
  - evpn
  - multihoming
---


|                           |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tutorial name**         | EVPN L2 Multihoming with SR Linux                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| **Lab components**        | 4 SR Linux nodes, 2  Linux nodes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| **Resource requirements** | :fontawesome-solid-microchip: 4 vCPU <br/>:fontawesome-solid-memory: 8 GB                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |  |
| **Lab**                   | [srl-labs/srl-evpn-mh-lab][lab]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| **Main ref documents**    | [RFC 7432 - BGP MPLS-Based Ethernet VPN](https://datatracker.ietf.org/doc/html/rfc7432)<br/>[RFC 8365 - A Network Virtualization Overlay Solution Using Ethernet VPN (EVPN)](https://datatracker.ietf.org/doc/html/rfc8365)<br/>[Nokia 7220 SR Linux Advanced Solutions Guide](https://documentation.nokia.com/srlinux/23-7/books/advanced-solutions/evpn-vxlan-layer-2-multi-hom.html)<br/>[Nokia 7220 SR Linux EVPN-VXLAN Guide](https://documentation.nokia.com/srlinux/23-7/books/evpn-vxlan/evpn-vxlan-tunnels-layer-2.html#evpn-l2-multi-hom) |
| **Version information**   | [`containerlab:0.44.0`][clab-install], [`srlinux:23.7.1`][srlinux-container], [`docker-ce:23.0.3`][docker-install]                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| **Authors**               | Alperen Akpinar [:material-linkedin:][aakpinar-linkedin]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |

Multihoming is a common networking feature that allows a customer edge (CE) device to be connected to two or more provider edge (PE) devices in a network. This provides redundant connectivity, efficient link utilization and allows the network to continue providing services even if one of the PE devices or links fails.

In the pre-EVPN era multihoming was enabled by Multi-chassis LAG (MC-LAG) or Virtual Port Channel (vPC) technologies. These technologies are still used in many networks, but they have some limitations and started to show their age.  
For example, MC-LAG and vPC are proprietary technologies and are not standardized, that makes it hard to build DC fabrics on a multivendor gear. They are also not quite suitable for large-scale deployments and have more limitations that we covered in the [**:material-book: Single Tier Datacenters - Evolving Away From Multi-chassis LAG**](../../../blog/posts/2023/single-tier-dc.md) blog post.

EVPN has built-in multihoming (MH) capability, which is defined by RFCs [7432](https://datatracker.ietf.org/doc/html/rfc7432), [8365](https://datatracker.ietf.org/doc/html/rfc8365). EVPN MH can be used to improve the reliability, performance, and manageability of networks. It is particularly well-suited for data center networks, where high availability and performance are critical.

In this tutorial, you will learn about L2 multihoming with EVPN and how to configure it in an SR Linux-based fabric.

EVPN provides multihoming with the Ethernet segments (ES), which might be a new concept for some readers. Therefore, the terminology is also discussed in the following chapters.

## Lab

To familiarize ourselves with EVPN multihoming and get some hands-on experience we will use the [evpn-multihoming lab](https://github.com/srl-labs/srl-evpn-mh-lab) that consists of one Spine, three Leaf (PE[^1]) switches, and two Linux hosts (CE[^2]). One multi-homed CE is connected to `leaf1` and `leaf2`, and another is connected to only `leaf3` with three links.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/images/evpn-mh.drawio"}'></div>
  <figcaption>EVPN multihoming lab topology</figcaption>
</figure>

As usual, this lab is deployed by [containerlab](https://containerlab.dev) and can be used on any Linux VM with the resources listed in the table at the beginning.

The lab comes with [startup configuration files][configs] provided for SR Linux leaf and spine switches. These files contain basic L2 EVPN configuration as explained in [L2 EVPN Basics tutorial](https://learn.srlinux.dev/tutorials/l2evpn/evpn/#mac-vrf). It is recommended to read the basics tutorial if you have not yet played with SR Linux or EVPN.

Besides the SR Linux startup configurations, the config directory also contains interface configurations for the CE hosts (Linux containers).

```yaml
--8<-- "https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/evpn-mh.clab.yml"
```

???tip "Configurations"
    Below are the startup configuration files used by the fabric switches and CE hosts.

    === "spine1"
        ```srl
        --8<-- "https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/configs/spine1.cfg"
        ```
    === "leaf1"
        ```srl
        --8<-- "https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/configs/leaf1.cfg"
        ```
    === "leaf2"
        ```srl
        --8<-- "https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/configs/leaf2.cfg"
        ```
    === "leaf3"
        ```srl
        --8<-- "https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/configs/leaf3.cfg"
        ```
    === "ce1"
        ```bash
        --8<-- "https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/configs/ce1-config.sh"
        ```
    === "ce2"
        ```bash
        --8<-- "https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/configs/ce2-config.sh"
        ```

### Deployment

Courtesy of containerlab, lab deployment is just one click away:

```bash
git clone https://github.com/srl-labs/srl-evpn-mh-lab.git && \
cd srl-evpn-mh-lab && \
sudo containerlab deploy
```

<div class="embed-result">
```bash
INFO[0000] Containerlab v0.44.0 started
INFO[0000] Parsing & checking topology file: evpn-mh01.clab.yml
INFO[0000] Creating docker network: Name="clab", IPv4Subnet="172.20.20.0/24", IPv6Subnet="2001:172:20:20::/64", MTU="1500"
INFO[0000] Creating container: "ce2"
INFO[0000] Creating container: "ce1"
INFO[0000] Creating container: "spine1"
INFO[0000] Creating container: "leaf3"
INFO[0000] Creating container: "leaf1"
INFO[0000] Creating container: "leaf2"
# -- snip --
+---+---------------------+--------------+--------------------------------+-------+---------+----------------+----------------------+
| # |        Name         | Container ID |             Image              | Kind  |  State  |  IPv4 Address  |     IPv6 Address     |
+---+---------------------+--------------+--------------------------------+-------+---------+----------------+----------------------+
| 1 | clab-evpn-mh-ce1    | 459de7e146a1 | ghcr.io/srl-labs/alpine:latest | linux | running | 172.20.20.6/24 | 2001:172:20:20::6/64 |
| 2 | clab-evpn-mh-ce2    | 64fb2845aa60 | ghcr.io/srl-labs/alpine:latest | linux | running | 172.20.20.7/24 | 2001:172:20:20::7/64 |
| 3 | clab-evpn-mh-leaf1  | 73ef7e76ef36 | ghcr.io/nokia/srlinux:23.7.1   | srl   | running | 172.20.20.3/24 | 2001:172:20:20::3/64 |
| 4 | clab-evpn-mh-leaf2  | 549668d25122 | ghcr.io/nokia/srlinux:23.7.1   | srl   | running | 172.20.20.5/24 | 2001:172:20:20::5/64 |
| 5 | clab-evpn-mh-leaf3  | 9d67b788a7a2 | ghcr.io/nokia/srlinux:23.7.1   | srl   | running | 172.20.20.4/24 | 2001:172:20:20::4/64 |
| 6 | clab-evpn-mh-spine1 | 244a0dd574a2 | ghcr.io/nokia/srlinux:23.7.1   | srl   | running | 172.20.20.8/24 | 2001:172:20:20::8/64 |
+---+---------------------+--------------+--------------------------------+-------+---------+----------------+----------------------+
```
</div>

When containerlab completes the deployment, you get a summary table with the connection details of the deployed nodes. In the "Name" column, you will find the names of the deployed containers. You can use these names to reach the nodes, e.g. to connect to the SSH of `leaf1`:

```bash
ssh admin@clab-evpn-mh-leaf1 #(1)!
```

1. Default credentials `admin:NokiaSrl1!`

To connect to the Linux hosts (CEs):

=== "ce1"

    ```bash
    ssh admin@clab-evpn-mh-ce1 #(1)!
    ```

    1. Credentials `admin:srllabs@123`

    or

    ```bash
    docker exec -it clab-evpn-mh-ce1 bash
    ```

=== "ce2"

    ```bash
    docker exec -it clab-evpn-mh-ce2 bash
    ```

The fabric comes up with L2 EVPN service deployed and operational. You can check the status of the EVPN service using verification commands listed in the [L2 EVPN Basics tutorial](https://learn.srlinux.dev/tutorials/l2evpn/evpn/#verification).

## EVPN Multihoming Terminology

Before we dive into the practicalities, let's look at some terms specific to EVPN multihoming.

### Ethernet Segment (ES)

Defines the CE links associated with multiple PEs (up to 4). An ES is configured in all PEs that the multi-homed CE is connected to and has a unique Ethernet Segment Identifier (ESI) that is advertised via EVPN.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":1,"zoom":2.5,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/images/evpn-mh.drawio"}'></div>
  <figcaption>Ethernet segments</figcaption>
</figure>

### Multihoming Modes

The standard defines two multihoming modes: single-active and all-active. In single-active mode, the CE device only utilizes one uplink towards the leaves, while in all-active mode, all links are used, and load balancing occurs. This tutorial covers the all-active multihoming scenario.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":2,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/images/evpn-mh.drawio"}'></div>
  <figcaption>EVPN multihoming modes</figcaption>
</figure>

### Link Aggregation Group (LAG)

A LAG is logical bundle of individual interfaces/ports and is required for an all-active mode but is optional for a single-active mode.

### MAC-VRF

An L2 network instance, essentially a broadcast domain in SR Linux. Interface(s) or LAG must be connected to a MAC-VRF for L2 multihoming.

### Advanced Multihoming Procedures

The following procedures are essential for EVPN multihoming, but aren't typical configuration items:

+ **Designated Forwarder (DF):** The leaf that is elected to forward BUM traffic. The election is based on the route-type 4 (RT4) exchange, known as the ES routes of EVPN.
+ **Split-horizon (Local bias):** A mechanism to prevent BUM traffic received by CE from being looped back to itself by a peer leaf. Local bias is used for all-active and is based on RT4 exchange.
+ **Aliasing:** Aliasing allows remote leaf to balance traffic across the leaf peers that advertise the same ESI via RT1.
+ **Fast convergence:** Fast convergence ensures that traffic is quickly rerouted in the event of a failure. With RT1 updates, the remote leaf can quickly remove a failed destination from the ESI, without depending on individual RT2 withdrawals.

EVPN route types 1 and 4 are used to implement the multihoming procedures.

For more information about EVPN multihoming procedures and route-types, consult with the [EVPN VXLAN Guide](https://documentation.nokia.com/srlinux/23-7/books/evpn-vxlan/evpn-vxlan-tunnels-layer-2.html#evpn-l2-multi-hom).

Let's now move on to the configuration part.

[lab]: https://github.com/srl-labs/srl-evpn-mh-lab
[topofile]: https://github.com/srl-labs/srl-evpn-mh-lab/blob/main/evpn-mh.clab.yml
[clab-install]: https://containerlab.srlinux.dev/install/
[srlinux-container]: https://github.com/orgs/nokia/packages/container/package/srlinux
[docker-install]: https://docs.docker.com/engine/install/
[configs]: https://github.com/srl-labs/srl-evpn-mh-lab/tree/main/configs
[path-evpn-mh]: https://github.com/srl-labs/srl-evpn-mh-lab.git
[aakpinar-linkedin]: https://www.linkedin.com/in/alperenakpinar/

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>

[^1]: Provider Edge device
[^2]: Customer Edge device
