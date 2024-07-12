---
comments: true
---

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>

# Overlay Routing

The BGP EVPN family facilitates the exchange of overlay routes. Further details on EVPN and its mechanisms will be discussed in subsequent chapter. In this section we will focus on how BGP EVPN is configured.

Typically, Route Reflectors (RRs) are used for iBGP peering instead of configuring a full mesh. Utilizing RRs reduces the number of BGP sessions, requiring only peering with RRs. This approach minimizes configuration efforts and allows for centralized application of routing policies.

In our case Spine will be the EVPN RR and Leaves will be the client.

1. **Create BGP peer-group**  
    A BGP peer group simplifies configuring multiple BGP peers with similar requirements by grouping them together.
  
    ```srl
    set / network-instance default protocols bgp group overlay
    ```

1. **Assign Autonomous System Number**  
    We'll use iBGP with the EVPN family, meaning all routers in this data center will share the same AS number for overlay route exchange.

    ```srl
    set / network-instance default protocols bgp group overlay peer-as 55555
    set / network-instance default protocols bgp group overlay local-as as-number 55555
    ```

1. **Enable Address Family**  
    Here we are enabling the EVPN address family and disabling the IPv4 family for the overlay BGP group.

    ```srl
    set / network-instance default protocols bgp group evpn afi-safi evpn admin-state enable
    set / network-instance default protocols bgp group evpn afi-safi ipv4-unicast admin-state disable
    ```

1. **Configure the neighbor**  

    /// tab | leaf1 & leaf2
    Leaf devices uses Spine's System IP for BGP EVPN peering.

    ```srl
    set / network-instance default protocols bgp neighbor 100.100.100.100 admin-state enable
    set / network-instance default protocols bgp neighbor 100.100.100.100 peer-group overlay
    ```

    ///

    /// tab | spine ( RR )
    Spine is configured to establish dynamic peering with any IP address.

    ```srl
    set / network-instance default protocols bgp dynamic-neighbors accept match 0.0.0.0/0 peer-group overlay
    ```

    ///

1. **Configure EVPN Route Reflector (only on spine)**  

    The command below will enable the route reflector functionality and only needs to be enabled on the Spine.
    /// tab | spine

    ```srl
    set / network-instance default protocols bgp group overlay route-reflector client true
    ```

    ///

### Verification

The eBGP IPv4 sessions between Leaves and the spine is now active using IPv6 link-local addresses for peering. Through this eBGP peering, the IPv4 address family is distributing the loopback IPs across the DC.

Simultaneously, the iBGP EVPN address family, set up through the loopback addresses, supports the sharing of overlay routes, which will be covered in detail in the following chapter.

/// tab | leaf1

```srl
A:leaf1# show network-instance default protocols bgp neighbor
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
+------------------+--------------------------+------------------+------+----------+---------------+---------------+-------------+--------------------------+
|     Net-Inst     |           Peer           |      Group       | Flag | Peer-AS  |     State     |    Uptime     |  AFI/SAFI   |      [Rx/Active/Tx]      |
|                  |                          |                  |  s   |          |               |               |             |                          |
+==================+==========================+==================+======+==========+===============+===============+=============+==========================+
| default          | 100.100.100.100          | overlay          | S    | 55555    | established   | 0d:1h:13m:3s  | evpn        | [2/2/2]                  |
| default          | fe80::181d:4ff:feff:1%et | underlay         | D    | 65000    | established   | 0d:1h:13m:9s  | ipv4-       | [2/2/1]                  |
|                  | hernet-1/49.1            |                  |      |          |               |               | unicast     |                          |
+------------------+--------------------------+------------------+------+----------+---------------+---------------+-------------+--------------------------+
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
Summary:
1 configured neighbors, 1 configured sessions are established,0 disabled peers
1 dynamic peers
```

///

/// tab | leaf2

```srl
A:leaf2# show network-instance default protocols bgp neighbor
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
+------------------+--------------------------+------------------+------+----------+---------------+---------------+-------------+--------------------------+
|     Net-Inst     |           Peer           |      Group       | Flag | Peer-AS  |     State     |    Uptime     |  AFI/SAFI   |      [Rx/Active/Tx]      |
|                  |                          |                  |  s   |          |               |               |             |                          |
+==================+==========================+==================+======+==========+===============+===============+=============+==========================+
| default          | 100.100.100.100          | overlay          | S    | 55555    | established   | 0d:1h:13m:29s | evpn        | [2/2/2]                  |
| default          | fe80::181d:4ff:feff:2%et | underlay         | D    | 65000    | established   | 0d:1h:13m:35s | ipv4-       | [2/2/1]                  |
|                  | hernet-1/49.1            |                  |      |          |               |               | unicast     |                          |
+------------------+--------------------------+------------------+------+----------+---------------+---------------+-------------+--------------------------+
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
Summary:
1 configured neighbors, 1 configured sessions are established,0 disabled peers
1 dynamic peers
```

///

/// tab | spine

```srl
A:spine# show network-instance default protocols bgp neighbor
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
+------------------+--------------------------+------------------+------+----------+---------------+---------------+-------------+--------------------------+
|     Net-Inst     |           Peer           |      Group       | Flag | Peer-AS  |     State     |    Uptime     |  AFI/SAFI   |      [Rx/Active/Tx]      |
|                  |                          |                  |  s   |          |               |               |             |                          |
+==================+==========================+==================+======+==========+===============+===============+=============+==========================+
| default          | 100.0.0.1                | overlay          | D    | 55555    | established   | 0d:1h:12m:24s | evpn        | [2/0/2]                  |
| default          | 100.0.0.2                | overlay          | D    | 55555    | established   | 0d:1h:12m:29s | evpn        | [2/0/2]                  |
| default          | fe80::1805:2ff:feff:31%e | underlay         | D    | 42000000 | established   | 0d:1h:12m:36s | ipv4-       | [1/1/2]                  |
|                  | thernet-1/1.1            |                  |      | 01       |               |               | unicast     |                          |
| default          | fe80::18d9:3ff:feff:31%e | underlay         | D    | 42000000 | established   | 0d:1h:12m:31s | ipv4-       | [1/1/2]                  |
|                  | thernet-1/2.1            |                  |      | 02       |               |               | unicast     |                          |
+------------------+--------------------------+------------------+------+----------+---------------+---------------+-------------+--------------------------+
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
Summary:
0 configured neighbors, 0 configured sessions are established,0 disabled peers
4 dynamic peers
```

///

[^1]: default SR Linux credentials are `admin:NokiaSrl1!`.
[^2]: the snippets were extracted with `info flat` command issued in running mode.
