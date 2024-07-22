---
comments: true
---

# Overlay Routing

With IP underlay configured we prepared the grounds for the EVPN overlay services. In order to create an EVPN service on top of an IP fabric our leaf devices should be able to exchange overlay routing information. And you guessed it, there is no better protocol for this job than BGP with an EVPN address family. At least that's what the industry has agreed upon.

Since all our leaf switches can reach each other via loopbacks, we can establish a BGP peering between them with `evpn` address family enabled. Operators can choose to use iBGP or eBGP for this purpose. In this tutorial, we will use iBGP for the overlay routing using spine as the Route Reflector (RR).  
Utilizing RRs reduces the number of BGP sessions; leaf switches peer only with RRs and receive from other leafs at the same time. This approach minimizes configuration efforts, allows for centralized application of routing policies, but, at the same time, introduces another protocol.

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":5,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>

In this section our goal is to setup iBGP session with `evpn` address family between our leaf switches so that when we configure L3 EVPN instance in the next chapters; the overlay EVPN routes will be exchanged between the leafs using these sessions.

Let's have a look at the configuration steps required to setup overlay routing on our leaf switches:

1. **BGP peer-group**  
    Just like with the underlay, creating a BGP peer group simplifies configuring multiple BGP peers with similar requirements by grouping them together. We will call this group `overlay`.
  
    ```{.srl .no-select}
    set / network-instance default protocols bgp group overlay
    ```

2. **Autonomous System Number**  
    Since we are configuring a new iBGP instance, all routers should share the same AS number. We will use AS 65535; note, that we will have to set the peer-as and local-as, since otherwise a globally configured underlay AS number would be used.

    ```{.srl .no-select}
    set / network-instance default protocols bgp group overlay peer-as 65535
    set / network-instance default protocols bgp group overlay local-as as-number 65535
    ```

3. **Address Family**  
    In the overlay, we only care about the EVPN routes, hence we are enabling the EVPN address family for the overlay BGP group and disabling the `ipv4-unicast` family that was enabled globally for the BGP process for the underlay routing.

    ```{.srl .no-select}
    set / network-instance default protocols bgp group overlay afi-safi evpn admin-state enable
    set / network-instance default protocols bgp group overlay afi-safi ipv4-unicast admin-state disable
    ```

4. **Neighbors**  

    /// tab | leaf1 & leaf2
    Leaf devices uses Spine's System IP for iBGP peering.

    ```{.srl .no-select}
    set / network-instance default protocols bgp neighbor 10.10.10.10 admin-state enable
    set / network-instance default protocols bgp neighbor 10.10.10.10 peer-group overlay
    ```

    ///

    /// tab | spine ( RR )
    On the spine we configure dynamic peering, that accepts peers with any IP address. This simplifies the configuration, as we don't have to specify each leaf's IP address.

    ```{.srl .no-select}
    set / network-instance default protocols bgp dynamic-neighbors accept match 0.0.0.0/0 peer-group overlay
    ```

    ///

5. **EVPN Route Reflector**  

    The command below will enable the route reflector functionality and only needs to be enabled on the spine.

    ```{.srl .no-select}
    set / network-instance default protocols bgp group overlay route-reflector client true
    ```

## Resulting configs

Here are the config snippets for the leaf and spine devices covering everything we discussed above.

/// tab | leaf1 & leaf2

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf1.conf:ibgp-overlay"

commit now

```

///
/// tab | spine

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/spine.conf:ibgp-overlay"

commit now
```

///

## Verification

Similarly to the verifications we did for the underlay, we can check the BGP neighbor status to ensure that the overlay iBGP peering is up and running. Since all leafs establish the iBGP session with the spine, we can list the session on the spine to ensure that all leafs are connected.

```{.srl .no-select}
--{ + running }--[  ]--
A:spine# / show network-instance default protocols bgp neighbor 10.*
----------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
+----------+----------+----------+----------+----------+----------+----------+----------+----------+
| Net-Inst |   Peer   |  Group   |  Flags   | Peer-AS  |  State   |  Uptime  | AFI/SAFI | [Rx/Acti |
|          |          |          |          |          |          |          |          |  ve/Tx]  |
+==========+==========+==========+==========+==========+==========+==========+==========+==========+
| default  | 10.0.0.1 | overlay  | D        | 65535    | establis | 0d:0h:3m | evpn     | [0/0/0]  |
|          |          |          |          |          | hed      | :35s     |          |          |
| default  | 10.0.0.2 | overlay  | D        | 65535    | establis | 0d:0h:3m | evpn     | [0/0/0]  |
|          |          |          |          |          | hed      | :27s     |          |          |
+----------+----------+----------+----------+----------+----------+----------+----------+----------+
----------------------------------------------------------------------------------------------------
Summary:
0 configured neighbors, 0 configured sessions are established,0 disabled peers
4 dynamic peers
```

Both iBGP sessions from the spine towards the leafs are established. It is also perfectly fine to see no prefixes exchanged at this point, as we have not yet configured any EVPN services that would create the evpn routes.

This is what we are going to do next in the [L3 EVPN section](l3evpn.md).

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
