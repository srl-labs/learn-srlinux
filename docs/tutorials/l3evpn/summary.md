---
comments: true
---

# Summary

While originally designed for layer 2 VPNs, EVPN has been extended to support inter-subnet routing, and subsequently, layer 3 VPNs. This tutorial walked you through the configuration of a non-IRB-based layer 3 EVPN service deployed on top of an IP fabric.

The two scenarios covered in this tutorial included a Layer 3 CE end device connected to a leaf switch and a Layer 3 CE router device that utilized a PE-CE routing protocol to exchange prefixes. In both scenarios, the EVPN service was configured to provide end-to-end Layer 3 reachability between the CE prefixes.

Since no IRB interfaces were used in this tutorial, the EVPN control plane was extremely simple, with only EVPN RT5 routes being exchanged between the leaf switches. No ARP/ND synchronization, no IMET routes, not MAC tables. This is a significant simplification compared to the Layer 2 based services.

However, there are some considerations to keep in mind:

1. When connecting servers to the fabric using L3 routed interfaces (as opposed to L2 interfaces), the servers must be reconfigured to use the leaf switch as the default gateway. You will have to configure routed interfaces on leaf switches per each server. This may become a challenge in certain environments.  
    All active load balancing must be done with ECMP and may require a routing protocol that supports ECMP. This, again, may or may not be feasible.
2. When a PE-CE protocol is used, the configuration tasks are more comples on the CE side when compared to a simple LAG configuration in the case of L2 EVPN service or L3 EVPN with IRB.
3. And lastly, another consideration to keep in mind when opting for pure Layer 3 services is the legacy workloads that may require Layer 2 connectivity. In such cases, a combination of Layer 2 and Layer 3 services may be required.

In a nutsheel, network designers and operators should carefully consider the trade-offs between the simplicity of the EVPN control plane and the additional tasks required on the server and CE device side when deciding on the type of EVPN service to deploy.
