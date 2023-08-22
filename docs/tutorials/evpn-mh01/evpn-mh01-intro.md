---
comments: true
tags:
  - evpn
  - multi-homing
---


|                                |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tutorial name**              | EVPN L2 Multi-homing with SR Linux                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **Lab components**             | 4 SR Linux nodes, 2 Alpine Linux                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| **Resource requirements**      | :fontawesome-solid-microchip: 3vCPU <br/>:fontawesome-solid-memory: 6 GB                                                                                                                                                                                                                                                                                                                                                                                                                    |
| **Containerlab topology file** | [evpn-mh01.clab.yml][topofile]                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **Lab name**                   | evpn-mh01                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **Main ref documents**         | [RFC 7432 - BGP MPLS-Based Ethernet VPN](https://datatracker.ietf.org/doc/html/rfc7432)<br/>[RFC 8365 - A Network Virtualization Overlay Solution Using Ethernet VPN (EVPN)](https://datatracker.ietf.org/doc/html/rfc8365)<br/>[Nokia 7220 SR Linux Advanced Solutions Guide](https://documentation.nokia.com/srlinux/23-3/books/advanced-solutions)<br/>[Nokia 7220 SR Linux EVPN-VXLAN Guide](https://documentation.nokia.com/srlinux/23-7/title/evpn_vxlan.html) |
| **Version information**[^1]    | [`containerlab:0.44.0`][clab-install], [`srlinux:23.3.2`][srlinux-container], [`docker-ce:23.0.3`][docker-install]                                                                                                                                                                                                                                                                                                                                                                        |
One of the many advantages of EVPN is its built-in multi-homing (MH) capability, which is standards-based and defined by RFCs 7432, 8365. 

This tutorial will help you learn about L2 multi-homing with EVPN and guide you on how to configure it in an EVPN-based SR Linux fabric.

EVPN provides multi-homing with the Ethernet Segments (ES), which may be a new concept to some readers. Therefore, the terminology will also be discussed in the following chapters.

The lab comprises a spine, three leaf(PEs) routers, and two Alpine Linux hosts(CEs). A multi-homed CE is connected to leaf1, while another is linked to leaf3 for testing purposes.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/evpn-mh01.drawio"}'></div>
  <figcaption>EVPN multi-homing lab topology</figcaption>
</figure>

## Lab deployment

As usual, this lab is powered by containerlab and can be deployed on any Linux VM with enough resources mentioned in the table at the beginning.

This lab comes with pre-configurations that are explained in [L2 EVPN tutorial](https://learn.srlinux.dev/tutorials/l2evpn/evpn/#mac-vrf), which is highly recommended if you haven't played with SR Linux or EVPN yet.

The topology and pre-configurations are defined in the containerlab topology file.

The SR Linux configurations are referred to as [config files][configs] (.cfg), and Alpine Linux configurations are defined in the [topology file][topofile] to be directly executed at the deployment.

```yaml
--8<-- "labs/evpn-mh/evpn-mh01.clab.yml"
```

The SR Linux configurations are 
=== "leaf1"
    ```yaml
    --8<-- "labs/evpn-mh/leaf1.cfg"
    ```
=== "leaf2"
    ```yaml
    --8<-- "labs/evpn-mh/leaf2.cfg"
    ```
=== "leaf3"
    ```yaml
    --8<-- "labs/evpn-mh/leaf3.cfg"
    ```
=== "spine1"
    ```yaml
    --8<-- "labs/evpn-mh/spine1.cfg"
    ```

Save [these][path-evpn-mh] to your Linux machine and deploy:

```
# containerlab deploy -t evpn-mh01.clab.yml
[root@clab-vm1 evpn-mh01]# containerlab deploy
INFO[0000] Containerlab v0.44.0 started
INFO[0000] Parsing & checking topology file: evpn-mh01.clab.yml
INFO[0000] Creating docker network: Name="clab", IPv4Subnet="172.20.20.0/24", IPv6Subnet="2001:172:20:20::/64", MTU="1500"
WARN[0000] Unable to load kernel module "ip_tables" automatically "load ip_tables failed: exec format error"
INFO[0000] Creating lab directory: /root/demo/learn.srlinux/clab/evpn-mh01/clab-evpn-mh01
WARN[0000] SSH_AUTH_SOCK not set, skipping pubkey fetching
INFO[0000] Creating container: "ce2"
INFO[0000] Creating container: "ce1"
INFO[0000] Creating container: "spine1"
INFO[0000] Creating container: "leaf3"
INFO[0000] Creating container: "leaf1"
INFO[0000] Creating container: "leaf2"
INFO[0003] Creating link: leaf1:e1-49 <--> spine1:e1-1
INFO[0003] Creating link: ce1:eth1 <--> leaf1:e1-1
INFO[0003] Creating link: leaf3:e1-49 <--> spine1:e1-3
INFO[0003] Creating link: leaf2:e1-49 <--> spine1:e1-2
INFO[0003] Creating link: ce2:eth1 <--> leaf3:e1-1
INFO[0003] Creating link: ce1:eth2 <--> leaf2:e1-1
INFO[0004] Creating link: ce2:eth2 <--> leaf3:e1-2
INFO[0004] Creating link: ce2:eth3 <--> leaf3:e1-3
INFO[0004] Running postdeploy actions for Nokia SR Linux 'leaf3' node
INFO[0004] Running postdeploy actions for Nokia SR Linux 'leaf1' node
INFO[0004] Running postdeploy actions for Nokia SR Linux 'spine1' node
INFO[0004] Running postdeploy actions for Nokia SR Linux 'leaf2' node
INFO[0025] Adding containerlab host entries to /etc/hosts file
INFO[0026] Executed command "ip link add bond0 type bond mode 802.3ad" on the node "ce1". stdout:
INFO[0026] Executed command "ip link set address 00:c1:ab:00:00:11 dev bond0" on the node "ce1". stdout:
INFO[0026] Executed command "ip addr add 192.168.0.11/24 dev bond0" on the node "ce1". stdout:
INFO[0026] Executed command "ip link set eth1 down" on the node "ce1". stdout:
INFO[0026] Executed command "ip link set eth2 down" on the node "ce1". stdout:
INFO[0026] Executed command "ip link set eth1 master bond0" on the node "ce1". stdout:
INFO[0026] Executed command "ip link set eth2 master bond0" on the node "ce1". stdout:
INFO[0026] Executed command "ip link set eth1 up" on the node "ce1". stdout:
INFO[0026] Executed command "ip link set eth2 up" on the node "ce1". stdout:
INFO[0026] Executed command "ip link set bond0 up" on the node "ce1". stdout:
INFO[0026] Executed command "ip link set address 00:c1:ab:00:00:21 dev eth1" on the node "ce2". stdout:
INFO[0026] Executed command "ip link set address 00:c1:ab:00:00:22 dev eth2" on the node "ce2". stdout:
INFO[0026] Executed command "ip link set address 00:c1:ab:00:00:23 dev eth3" on the node "ce2". stdout:
INFO[0026] Executed command "ip link add dev vrf-1 type vrf table 1" on the node "ce2". stdout:
INFO[0026] Executed command "ip link set dev vrf-1 up" on the node "ce2". stdout:
INFO[0026] Executed command "ip link set dev eth1 master vrf-1" on the node "ce2". stdout:
INFO[0026] Executed command "ip link add dev vrf-2 type vrf table 2" on the node "ce2". stdout:
INFO[0026] Executed command "ip link set dev vrf-2 up" on the node "ce2". stdout:
INFO[0026] Executed command "ip link set dev eth2 master vrf-2" on the node "ce2". stdout:
INFO[0026] Executed command "ip link add dev vrf-3 type vrf table 3" on the node "ce2". stdout:
INFO[0026] Executed command "ip link set dev vrf-3 up" on the node "ce2". stdout:
INFO[0026] Executed command "ip link set dev eth3 master vrf-3" on the node "ce2". stdout:
INFO[0026] Executed command "ip addr add 192.168.0.21/24 dev eth1" on the node "ce2". stdout:
INFO[0026] Executed command "ip addr add 192.168.0.22/24 dev eth2" on the node "ce2". stdout:
INFO[0026] Executed command "ip addr add 192.168.0.23/24 dev eth3" on the node "ce2". stdout:
+---+-----------------------+--------------+------------------------------+-------+---------+----------------+----------------------+
| # |         Name          | Container ID |            Image             | Kind  |  State  |  IPv4 Address  |     IPv6 Address     |
+---+-----------------------+--------------+------------------------------+-------+---------+----------------+----------------------+
| 1 | clab-evpn-mh01-ce1    | 11d8ad808671 | akpinar/alpine:latest        | linux | running | 172.20.20.2/24 | 2001:172:20:20::2/64 |
| 2 | clab-evpn-mh01-ce2    | f563402d339f | akpinar/alpine:latest        | linux | running | 172.20.20.7/24 | 2001:172:20:20::7/64 |
| 3 | clab-evpn-mh01-leaf1  | dfcf20665a6a | ghcr.io/nokia/srlinux:23.3.1 | srl   | running | 172.20.20.4/24 | 2001:172:20:20::4/64 |
| 4 | clab-evpn-mh01-leaf2  | fee169425f04 | ghcr.io/nokia/srlinux:23.3.1 | srl   | running | 172.20.20.6/24 | 2001:172:20:20::6/64 |
| 5 | clab-evpn-mh01-leaf3  | 115bbac271c9 | ghcr.io/nokia/srlinux:23.3.1 | srl   | running | 172.20.20.5/24 | 2001:172:20:20::5/64 |
| 6 | clab-evpn-mh01-spine1 | d825b06fe483 | ghcr.io/nokia/srlinux:23.3.1 | srl   | running | 172.20.20.3/24 | 2001:172:20:20::3/64 |
+---+-----------------------+--------------+------------------------------+-------+---------+----------------+----------------------+
```

A few seconds later containerlab finishes the deployment with providing a summary table that outlines connection details of the deployed nodes. In the "Name" column we have the names of the deployed containers and those names can be used to reach the nodes, for example to connect to the SSH of `leaf1`:

```bash
# default credentials admin:NokiaSrl1!
ssh admin@clab-evpn01-leaf1
```

To connect Alpine Linux (CEs):

=== "srv1"
    ```
    docker exec -it clab-evpn-mh01-ce1 bash
    ```
=== "srv2"
    ```
    docker exec -it clab-evpn-mh01-ce1 bash
    ```

## EVPN Multi-homing Terminology

Before diving into the hands-on, let's see some terms that would help us better understand the configurations.

+ **Ethernet Segment (ES):** Defines the CE links connected to multiple PEs. An ES is configured in all PEs that a CE is connected and has a unique identifier (ESI) advertised via EVPN.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":1,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/evpn-mh01.drawio"}'></div>
  <figcaption>Ethernet segments</figcaption>
</figure>

+ **Multi-homing Modes:** The standard defines two modes: single-active and all-active. Single-active mode has only one active link, while all-active mode uses all links and provides load balancing. This tutorial covers an example of all-active multi-homing.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":2,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/evpn-mh01.drawio"}'></div>
  <figcaption>EVPN multi-homing modes</figcaption>
</figure>

+ **Link Aggregation Group (LAG):** A LAG is required for all-active but optional for single-active multi-homing.

+ **MAC-VRF:** It is the L2 network-instance, basically a broadcast domain in SR Linux. Interface(s) or LAG must be attached to a MAC-VRF for L2 multi-homing.

The following procedures are essential to EVPN multi-homing but they're not one of the typical configuration items;

+ **Designated Forwarder (DF):** The leaf that is elected to forward BUM traffic. The election is based on the route-type 4 (RT4) exchange, known as the ES routes of EVPN.
+ **Split-horizon (Local bias):** A mechanism to avoid looping the BUM traffic received from the CE back to itself by a peer PE. Local bias is used for all-active and based on RT4 exchange. 
+ **Aliasing:** For remote PEs that are not part of ES to load-balance traffic to the multi-homed CE. RT1 (Auto-discovery) is advertised for aliasing.

EVPN route types 1 and 4 are used to implement the multi-homing procedures. You can check [this](https://documentation.nokia.com/srlinux/23-3/books/evpn-vxlan/evpn-vxlan-tunnels-layer-2.html?hl=designated%2Cforwarder#evpn-l2-multi-hom-procedures) out for more about EVPN multi-homing procedures and route-types.

Now, let's move on to the configuration part.

[topology]: https://github.com/srl-labs/learn-srlinux/blob/main/docs/tutorials/evpn-mh/
[clab-install]: https://containerlab.srlinux.dev/install/
[srlinux-container]: https://github.com/orgs/nokia/packages/container/package/srlinux
[docker-install]: https://docs.docker.com/engine/install/
[configs]: https://github.com/srl-labs/learn-srlinux/blob/main/docs/tutorials/evpn-mh/leaf1.cfg
[path-evpn-mh]: https://github.com/srl-labs/learn-srlinux/blob/main/docs/tutorials/evpn-mh

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
