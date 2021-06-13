This chapter describes extensions added to SR Linux BGP and routing policy configuration to facilitate EVPN configuration.

## 7.1. BGP extensions for EVPN
SR Linux supports Multi-Protocol BGP with AFI/SAFI EVPN. The following BGP features are relevant to EVPN in a VXLAN network:

- The EVPN address family can use eBGP or iBGP.
- eBGP multi-hop is not supported on SR Linux; however, local-as override is supported for iBGP per session.
- A supported configuration/design with eBGP is eBGP with local-as override on the session to an iBGP RR.
- Rapid-update and rapid-withdrawal for EVPN family are supported and are always expected to be enabled, especially along with multi-homing. Note that rapid-update is address-family specific, while rapid-withdrawal is generic for all address families.
- The BGP keep-all-routes option is supported for EVPN to avoid route-refresh messages attracting all EVPN routes when a policy changes or bgp-evpn is enabled.
- The receive-ipv6-next-hops option does not apply to the EVPN address family.
- The prefix-limit max-received-routes and threshold options are supported for EVPN.
- The command network-instance protocols bgp route-advertisement wait-for-fib-install does not apply to EVPN.
- SR Linux BGP resolves BGP-EVPN routes’ next-hops in the network-instance default route-table. If the next-hop is resolved, BGP can mark the route as u*> (u=used, *=valid, >=best) and send the route to evpn_mgr if needed or reflected to other peers.

## 7.2. Routing policy extensions for EVPN
SR Linux includes support for applying routing policies to EVPN routes. You can specify the following match conditions in a policy statement:

- Match routes based on EVPN route type.
- Match routes based on IP addresses and prefixes via prefix-sets for route types 2 and 5.
- Match routes based BGP encapsulation extended community.

For information about configuring routing policies on SR Linux, see the SR Linux Configuration Basics Guide.

The following considerations apply to routing policies for EVPN:

- For IBGP neighbors, EVPN routes are imported and exported without explicit configuration of any policy at either the BGP or network-instance level.
- For EBGP neighbors, by default, routes are imported or exported based on the ebgp-default-policy configuration.
- When an explicit import/export route-target is configured in a network-instance bgp-instance, and an import/export policy is also configured on the same bgp-instance, the configured policy is used, and its route-target is added to the imported/exported route.
- When a network-instance policy and a peer policy are applied, they are executed as follows:
    - For export, the network-instance export policy is applied first, and the peer policy is applied afterwards (sequentially).
    - For import, peer import policy is applied first and network-instance import policy is applied afterwards (sequentially).
- Only one network-instance export and import policy is supported.