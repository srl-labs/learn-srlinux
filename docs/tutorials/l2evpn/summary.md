---
comments: true
---

<script type="text/javascript" src="https://cdn.jsdelivr.net/gh/hellt/drawio-js@main/embed2.js" async></script>
Layer 2 EVPN services with VXLAN dataplane are very common in multi-tenant data centers. In this tutorial we walked through every step that is needed to configure a basic Layer 2 EVPN with VXLAN dataplane service deployed on SR Linux switches:

* [IP fabric config](fabric.md) using eBGP in the underlay
* [EVPN service config](evpn.md) on leaf switches with the control and data plane verification

The highly detailed configuration & verification steps helped us achieve the goal of creating an overlay Layer 2 broadcast domain for the two servers in our topology. So that the high level service diagram transformed into a detailed map of configuration constructs and instances.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:9,&quot;zoom&quot;:4,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/quickstart.drawio&quot;}"></div>

During the verification phases we collected the following packet captures to prove the control/data plane behavior:

* [Exchange of the IMET/RT3 EVPN routes][capture-imets]. IMET/RT3 routes are the starting point in the L2 EVPN-VXLAN services, as they are used to dynamically discover the VXLAN VTEPs participating in the same EVI.
* [Exchange of MAC-IP/RT2 EVPN routes][capture-rt2-datapath] which convey the MAC information of the attached servers. These routes are used to create unicast tunnel destinations that the dataplane frames will use.

!!!info
    The more advanced EVPN topics listed below will be covered in separate tutorials:

    * EVPN L2 multi-homing
    * MAC mobility
    * MAC duplication and loop protection

[capture-imets]: https://github.com/srl-labs/learn-srlinux/blob/master/docs/tutorials/l2evpn/evpn01-imet-routes.pcapng
[capture-rt2-datapath]: https://github.com/srl-labs/learn-srlinux/blob/master/docs/tutorials/l2evpn/evpn01-macip-routes.pcapng
