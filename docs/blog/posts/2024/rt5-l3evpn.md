---
date: 2024-07-23
tags:
    - evpn
authors:
    - rdodin
---

# Route Type 5 L3 EVPN Tutorial

Since the inception of our Data Center Fabric program in 2019 we have been focusing on EVPN-based deployments as the preferred choice for data centers of all sizes. And historically, EVPN has been associated with Layer 2 services, such as VPLS, VPWS, E-LAN. However, network engineers know it all too well that BGP can take it all, and over time EVPN grew to support inter-subnet routing, and subsequently, layer 3 VPNs.

Now you can deploy L3 VPN services with EVPN, both in and outside of the data center. Yes, a single control plane EVPN umbrella can cover all your needs, or at least most of them.

It was important for us to start with [L2 EVPN basics](../../../tutorials/l2evpn/intro.md) and cover the EVPN origins first, but now more and more workloads ditching the arcane requirement to have layer 2 connectivity, and more and more data centers can be built with pure layer 3 services.

But Layer 3 EVPN services have many flavors... Some, such as RT5-only EVPN, are quite simple, while others offer more advanced features and require symmetric IRBs, SBDs, Interfacefull mode of operation, and ESI support. To ease in the L3 EVPN introduction we chose to start with the simplest form of L3 EVPN - RT5-only EVPN.

To introduce you to the concept of L3 EVPN we prepared a comprehensive tutorial - **[:material-book: RT5-only L3 EVPN Tutorial](../../../tutorials/l3evpn/rt5-only/index.md)** - that covers gets you through a fun lab exercise where you will configure a small but representative multitenant L3 EVPN network:

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":0,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>

You'll get exposed to many interesting concepts, such as:

* eBGP Unnumbered underlay to support the overlay services
* iBGP overlay with EVPN address family
* RT5-only EVPN service configuration for L3 workloads
* EVPN service with BGP PE-CE routing protocol to support clients with routing on the host

So, have your favorite drink ready, and let's have [our first dive](../../../tutorials/l3evpn/rt5-only/index.md) into the world of L3 EVPN!

--8<-- "docs/tutorials/l3evpn/rt5-only/summary.md:linkedin-question"

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
