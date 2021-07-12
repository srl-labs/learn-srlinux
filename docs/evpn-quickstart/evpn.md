<script type="text/javascript" src="https://cdn.jsdelivr.net/gh/hellt/drawio-js@main/embed2.js" async></script>
SR Linux services facilitate EVPN-VXLAN deployments in data centers. Ethernet Virtual Private Network (EVPN), along with Virtual eXtensible LAN (VXLAN), is a technology that allows Layer 2 and Layer 3 traffic to be tunneled across an IP
network.

The SR Linux EVPN-VXLAN solution supports using Layer 2 Broadcast Domains (BDs) in multi-tenant data centers using EVPN for the control plane and VXLAN as the data plane. It includes the following features:

* EVPN for VXLAN tunnels (Layer 2), extending a BD in overlay multi-tenant DCs
* EVPN for VXLAN tunnels (Layer 3), allowing inter-subnet-forwarding for unicast traffic within the same tenant infrastructure

This tutorial is dedicated for EVPN for VXLAN tunnels Layer 2.

## Overview
EVPN-VXLAN provides Layer-2 connectivity in multi-tenant DCs. EVPN-VXLAN Broadcast Domains (BD) can span several leaf routers connected to the same IP fabric, allowing hosts attached to the same BD to communicate as though they were connected to the same layer-2 switch.

VXLAN tunnels bridge the layer-2 frames between leaf routers with EVPN providing the control plane to automatically setup tunnels and use them efficiently.

The following figure demonstrates this concept where servers `srv1` and `srv2` are connected to the different switches of the routed fabric, but appear to be on the same broadcast domain.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:4,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/learn-srlinux/site/diagrams/quickstart.drawio&quot;}"></div>

Now that the DC fabric has a routed underlay, and the loopbacks of the leaf switches are mutually reachable[^1], we can proceed with the VXLAN based EVPN service configuration.

While doing that we will cover the following topics:

* VXLAN tunnel interface configuration
* Network instances of type `mac-vrf`
* Bridged subinterfaces
* BGP EVPN control plane configuration

## iBGP for EVPN
Prior to configuring the overlay services we must enable the EVPN address family for the distribution of EVPN routes among leaf routers of the same tenant. 

EVPN is enabled using iBGP and typically a Route Reflector (RR), or eBGP. In our example we have only two leafs, so we won't take extra time configuring the iBGP with a spine acting as a Route Reflector, and instead will configure the iBGP between the two leaf switches.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:5,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/learn-srlinux/site/diagrams/quickstart.drawio&quot;}"></div>

For that iBGP configuration we will create a group called `iBGP-overlay` which will have the peer-as and local-as set to 100 to form an iBGP neighborship. The group will also host the same permissive `all` routing policy and enabled `evpn` address family.

Each leaf will then have another neighbor addressed by the remote `system0` interface address and local system address as the source. Below you will find the pastable snippets with the aforementioned config:

=== "leaf1"
    ```
    enter candidate

    /network-instance default protocols bgp
        group iBGP-overlay {
            export-policy all
            import-policy all
            peer-as 100
            evpn {
                admin-state enable
            }
            local-as 100
            timers {
                minimum-advertisement-interval 1
            }
        }

        neighbor 10.0.0.2 {
            peer-group iBGP-overlay
            transport {
                local-address 10.0.0.1
            }
        }
    commit now
    ```
=== "leaf2"
    ```
    enter candidate

    /network-instance default protocols bgp
        group iBGP-overlay {
            export-policy all
            import-policy all
            peer-as 100
            evpn {
                admin-state enable
            }
            local-as 100
            timers {
                minimum-advertisement-interval 1
            }
        }

        neighbor 10.0.0.1 {
            peer-group iBGP-overlay
            transport {
                local-address 10.0.0.2
            }
        }
    commit now
    ```

Ensure that the iBGP session is established before proceeding any further:

``` linenums="1"
--{ + running }--[  ]--
A:leaf1# show /network-instance default protocols bgp neighbor 10.0.0.2
--------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
--------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------
+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+
| Net-Inst  |   Peer    |   Group   |   Flags   |  Peer-AS  |   State   |  Uptime   | AFI/SAFI  | [Rx/Activ |
|           |           |           |           |           |           |           |           |   e/Tx]   |
+===========+===========+===========+===========+===========+===========+===========+===========+===========+
| default   | 10.0.0.2  | iBGP-     | S         | 100       | establish | 0d:0h:50m | ipv4-unic | [4/1/4]   |
|           |           | overlay   |           |           | ed        | :52s      | ast       | [0/0/0]   |
|           |           |           |           |           |           |           | evpn      |           |
+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+
--------------------------------------------------------------------------------------------------------------
Summary:
2 configured neighbors, 2 configured sessions are established,0 disabled peers
0 dynamic peers
```
Right now, as we don't have any EVPN service created, there are no EVPN routes that are being sent/received, which is indicated in the last column of the table above.

[^1]: as was verified [before](fabric.md#dataplane)