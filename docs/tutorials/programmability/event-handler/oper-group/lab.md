---
comments: true
---

<script type="text/javascript" src="https://cdn.jsdelivr.net/gh/hellt/drawio-js@main/embed2.js" async></script>

As always, this tutorial will be backed up by a lab that readers can effortlessly deploy on their machine and follow along. Oper-group lab is contained within [srl-labs/oper-group-lab](https://github.com/srl-labs/opergroup-lab) repository and features:

1. A Clos based fabric with 4 leaves and 2 spines, forming the fabric
2. Two dual-homed clients emulated with linux containers and running `iperf` software to generate traffic
3. L2 EVPN service[^1] configured across the leaves of the fabric
4. A telemetry stack to demonstrate oper-group operations in action.

-{{ diagram(url='srl-labs/learn-srlinux/diagrams/opergroup.drawio',zoom=2.1, title='', page=0) }}-

## Physical topology

On a physical layer topology interconnections are laid down as follows:

-{{ diagram(url='srl-labs/learn-srlinux/diagrams/opergroup.drawio',zoom=2.1, title='', page=5) }}-

Each client is dual-homed to corresponding leaves; To achieve that, interfaces `eth1` and `eth2` are formed into a `bond0` interface.  
On the leaves side, the access interface `Ethernet-1/1` is part of a LAG interface that is "stretched" between a pair of leaves, forming a logical construct similar to MC-LAG.

-{{ diagram(url='srl-labs/learn-srlinux/diagrams/opergroup.drawio',zoom=3, title='', page=6) }}-

## Fabric underlay

In the underlay of a fabric leaves and spines run eBGP protocol to enable leaves to exchange reachability information for their `system0` interfaces.

-{{ diagram(url='srl-labs/learn-srlinux/diagrams/opergroup.drawio',zoom=3, title='', page=7) }}-

eBGP peerings are formed between each leaf and spine pair.

## Fabric overlay

To support BGP EVPN service, in the overlay iBGP peerings with EVPN address family are established from each leaf to each spine, with spines acting as route reflectors.

-{{ diagram(url='srl-labs/learn-srlinux/diagrams/opergroup.drawio',zoom=3, title='', page=8) }}-

From the EVPN service standpoint, the mac-vrf instance named `vrf-1` is created on leaves and `ES-1` ethernet segment is formed from a LAG interface.

-{{ diagram(url='srl-labs/learn-srlinux/diagrams/opergroup.drawio',zoom=3, title='', page=9) }}-

Ethernet segments are configured to be in an all-active mode to make sure that every access link is utilized in the fabric.

## Telemetry stack

We have enhanced the lab with a telemetry stack featuring [gnmic](https://gnmic.openconfig.net), prometheus, and grafana - our famous GPG stack. Nothing beats real-time visualization, especially when we want to correlate events happening in the network.

| Element    | Address                |
| ---------- | ---------------------- |
| Grafana    | https://localhost:3000 |
| Prometheus | https://localhost:9090 |

## Lab deployment

Start with cloning lab's repository

```
git clone https://github.com/srl-labs/opergroup-lab.git && cd opergroup-lab
```

Lab repository contains startup configuration files for the fabric nodes, as well as necessary files for the telemetry stack to come up online operational. To deploy the lab:

```
containerlab deploy
```

This will bring up a lab with an already pre-configured fabric using startup configs contained within [`configs`](https://github.com/srl-labs/opergroup-lab/tree/main/configs) directory.

-{{ diagram(url='srl-labs/learn-srlinux/diagrams/opergroup.drawio',zoom=3, title='', page=10) }}-

The deployed lab starts up in a pre-provisioned step, where underlay/overlay configuration has already been done. We proceed with oper-group use case exploration in the next chapter of this tutorial.

[^1]: Check [L2 EVPN tutorial](../../../l2evpn/intro.md) to get the basics of L2 EVPN service configuration.
