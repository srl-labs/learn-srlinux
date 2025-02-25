---
tags:
  - event handler
---

<script type="text/javascript" src="https://cdn.jsdelivr.net/gh/hellt/drawio-js@main/embed2.js" async></script>

# Introduction to oper group

|                             |                                                                                                                     |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| **Tutorial name**           | Oper Groups with Event Handler                                                                                      |
| **Lab components**          | 6 Nokia SR Linux nodes, 2 Linux nodes                                                                               |
| **Resource requirements**   | :fontawesome-solid-microchip: 4 vCPU <br/>:fontawesome-solid-memory: 6 GB                                           |
| **Lab**                     | [srl-labs/opergroup-lab][lab]                                                                                       |
| **Main ref documents**      | [Event Handler Guide][eh-guide]                                                                                     |
| **Version information**[^1] | [`containerlab:0.65.1`][clab-install], [`srlinux:24.10.2`][srlinux-container], [`docker-ce:26.0.0`][docker-install] |

[lab]: https://github.com/srl-labs/opergroup-lab
[clab-install]: https://containerlab.dev/install/
[srlinux-container]: https://github.com/nokia/srlinux-container-image
[docker-install]: https://docs.docker.com/engine/install/
[eh-guide]: https://documentation.nokia.com/srlinux/24-10/books/event-handler/event-handler-overview.html

One of the most common use cases that can be covered with the Event Handler framework is known as "Operational group" or "Oper-group" for short. An oper-group feature covers several use cases, but in essence, it creates a relationship between logical elements of a network node so that they become aware of each other - forming a logical group.

In the data center space oper-group feature can tackle the problem of traffic black-holing when leaves lose all connectivity to the spine layer. Consider the following simplified Clos topology where clients are multi-homed to leaves:

-{{ diagram(url='srl-labs/learn-srlinux/diagrams/opergroup.drawio',zoom=2.1, title='', page=1) }}-

With EVPN [all-active multihoming](https://documentation.nokia.com/srlinux/22-3/SR_Linux_Book_Files/Advanced_Solutions_Guide/evpn-l2-multihome.html#ariaid-title22) enabled in fabric traffic from `client1` is load-balanced over the links attached to the upstream leaves and propagates via fabric to its destination.

Since all links of a client' bond interface are active, traffic is hashed to each of the constituent links and thus utilizes all available bandwidth. A problem occurs when a leaf looses connectivity to all upstream spines, as illustrated below:

-{{ diagram(url='srl-labs/learn-srlinux/diagrams/opergroup.drawio',zoom=2.1, title='', page=2) }}-

When `leaf1` loses its uplinks, traffic from `client1` still gets sent to it since the client is not aware of any link loss problems happening on the leaf. This results in traffic blackholing on `leaf1`.

To remedy this particular failure scenario an oper-group can be used. The idea here is to make a logical grouping between certain uplink and downlink interfaces on the leaves so that downlinks would share fate with uplink status. In our example, oper-group can be configured in such a way that leaves will shutdown their downlink interfaces should they detect that uplinks went down. This operational group's workflow depicted below:

-{{ diagram(url='srl-labs/learn-srlinux/diagrams/opergroup.drawio',zoom=3, title='', page=3) }}-

When a leaf loses its uplinks, the oper-group gets notified about that fact and reacts accordingly by operationally disabling the access link towards the client. Once the leaf's downlink transitions to a `down` state, the client's bond interface stops using that particular interface for hashing, and traffic moves over to healthy links. In our example, the client stops sending to `leaf1` and everything gets sent over to `leaf2`.

In this tutorial, we will see how SR Linux's Event Handler framework enables oper-group capability.

[^1]: the following versions have been used to create this tutorial. The newer versions might work; please pin the version to the mentioned ones if they don't.
