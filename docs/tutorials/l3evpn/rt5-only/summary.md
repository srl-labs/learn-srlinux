---
comments: true
---

# Summary

While originally designed for layer 2 VPNs, EVPN has been extended to support inter-subnet routing, and subsequently, layer 3 VPNs. This tutorial walked you through the configuration of **a simple, interface-less, RT5-only layer 3 EVPN service**[^1] deployed on top of an IP fabric.

The two scenarios covered in this tutorial included a Layer 3 CE end device connected to a leaf switch and a Layer 3 CE router device that utilized a PE-CE routing protocol to exchange prefixes. In both scenarios, the EVPN service was configured to provide end-to-end Layer 3 reachability between the CE prefixes.

Since no IRB interfaces were used in this tutorial, the EVPN control plane was extremely simple, with only EVPN RT5 routes being exchanged between the leaf switches. No ARP/ND synchronization, no IMET routes, not MAC tables. This is a significant simplification compared to state required to support the Layer 2-based services.

However, there are, as always, some considerations to keep in mind:

1. When connecting servers to the fabric using L3 routed interfaces (as opposed to L2 interfaces), the servers must be reconfigured to use the leaf switch as the default gateway. You will have to configure routed interfaces on leaf switches per each server. This may become a challenge in certain environments.  
    All active load balancing must be done with ECMP and may require a routing protocol that supports ECMP. This, again, may or may not be feasible.
2. When a PE-CE protocol is used, the configuration tasks are more complex on the CE side when compared to a simple LAG configuration in the case of L2 EVPN service or L3 EVPN with IRB.
3. And lastly, another consideration to keep in mind when opting for pure Layer 3 services is the legacy workloads that may _require_ Layer 2 connectivity. In such cases, a Layer 2 EVPN is a must.

In a nutshell, network designers and operators should carefully consider the trade-offs between the simplicity of the EVPN control plane and the additional tasks required on the server and CE device side when deciding on the type of EVPN service to deploy.

<!-- --8<-- [start:linkedin-question] -->
/// admonition | Pure L3 EVPN fabrics in the wild?
    type: quote
We shout out to the community to share their experiences with pure L3 EVPN fabrics. Have you deployed one? What were the challenges? What were the benefits?

Here is a [linkedin post with some pretty interesting comments](https://www.linkedin.com/feed/update/urn:li:activity:7221449552220823552/) on the topic by Pavel Lunin from Scaleway.
///
<!-- --8<-- [end:linkedin-question] -->

We are going to cover more advanced L3 EVPN scenarios with symmetric IRB interfaces, Interface-full mode of operation, and ESI support in the upcoming tutorials. Stay tuned!

/// details | Resulting configs
If you wish to start a lab with the resulting configurations from this tutorial already in place, you need to uncomment the `startup-config` knobs in the [topology file][lab-topo] prior to the lab deployment.

In the repository, you therefore can find the full startup configs per each device in the [`startup_configs`][startup-configs-dir] directory.

///

[lab-topo]: https://github.com/srl-labs/srl-l3evpn-tutorial-lab/tree/main/l3evpn-tutorial.clab.yml
[startup-configs-dir]: https://github.com/srl-labs/srl-l3evpn-tutorial-lab/tree/main/startup_configs

[^1]: A more advanced, feature rich, and therefore complex L3 EVPN service introduces a combination of MAC and IP VRFs with IRB interfaces and ESI support. This tutorial does not cover these advanced topics.
