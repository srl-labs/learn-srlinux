# SR Linux EVPN Proxy

|                          |                                                                                                         |
| ------------------------ | ------------------------------------------------------------------------------------------------------- |
| **Description**          | SR Linux EVPN Proxy agent that allows to bridge EVPN domains with domains that only employ static VXLAN |
| **Components**           | [Nokia SR Linux][srl], Cumulus VX                                                                       |
| **Programming Language** | Python                                                                                                  |
| **Source Code**          | [`jbemmel/srl-evpn-proxy`][src]                                                                         |
| **Authors**              | [Jeroen van Bemmel][auth1]                                                                              |

## Introduction

Most data center designs start small before they evolve. At small scale, it may make sense to manually configure static VXLAN tunnels between leaf switches, as implemented on the 2 virtual lab nodes on the left side.

![pic1](https://github.com/jbemmel/srl-evpn-proxy/raw/main/images/EVPN_Agent2.png)

There is nothing wrong with such an initial design, but as the fabric grows and the number of leaves reaches a certain threshold, having to touch every switch each time a device is added can get cumbersome and error prone.

The internet and most modern large scale data center designs use dynamic control plane protocols and volatile in-memory configuration to configure packet forwarding. BGP is a popular choice, and the Ethernet VPN address family ([EVPN RFC8365](https://datatracker.ietf.org/doc/html/rfc8365)) can support both L2 and L3 overlay services. However, legacy fabrics continue to support business critical applications, and there is a desire to keep doing so without service interruptions, and with minimal changes.

So how can we move to the new dynamic world of EVPN based data center fabrics, while transitioning gradually and smoothly from these static configurations?

## EVPN Proxy Agent

The `evpn-proxy` agent developed with [NDK][ndk] can answer the need of gradually transitioning from the static VXLAN dataplane to the EVPN based service. It has a lot of embedded functionality, we will cover the core feature here which is the Static VXLAN <-> EVPN Proxy functionality for point to point tunnels.

The agent gets installed on SR Linux NOS and enables the control plane stitching between static VXLAN VTEP and EVPN-enabled service by generating EVPN routes on behalf of a legacy VTEP device.

![pic2](https://gitlab.com/rdodin/pics/-/wikis/uploads/bc2e0593ce7720656e39cf5cc449626d/CleanShot_2021-11-02_at_21.54.37_2x.png)

[srl]: https://www.nokia.com/networks/products/service-router-linux-NOS/
[src]: https://github.com/jbemmel/srl-evpn-proxy
[ndk]: ../index.md
[auth1]: https://www.linkedin.com/in/jeroenvbemmel/
