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

## Access interfaces
Next we are configuring the interfaces from the leaf switches to the corresponding servers. According to our lab's wiring diagram, interface 1 is connected to the server on both leaf switches:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:6,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/learn-srlinux/site/diagrams/quickstart.drawio&quot;}"></div>

Configuration of access interface is nothing special, we already [configured leaf-spine interfaces](fabric.md#leaf-spine-interfaces) at the fabric configuration stage, so the steps are all familiar. The only detail worth mentioning here is that we have to indicate the type of the subinterface to be [`bridged`](../basics/ifaces.md#subinterfaces), this makes the interfaces only attachable to a network instance of `mac-vrf` type with MAC learning and layer-2 forwarding enabled.

The following config is applied to both leaf switches:

```
enter candidate
    /interface ethernet-1/1 {
        vlan-tagging true
        subinterface 0 {
            type bridged
            admin-state enable
            vlan {
                encap {
                    untagged {
                    }
                }
            }
        }
    }
commit now
```

As the config snippet shows, we are not using any VLAN classification on the subinterface, our intention is to send untagged frames from the servers.

## Tunnel/VXLAN interface
After creating the access sub-interfaces we are proceeding with creation of the VXLAN/Tunnel interfaces. The [VXLAN encapsulation](https://datatracker.ietf.org/doc/html/rfc8365#section-5) in the dataplane allows MAC-VRFs of the same BD to be connected throughout the IP fabric.

The SR Linux models VXLAN as a tunnel-interface which has a vxlan-interface within. The tunnel-interface for VXLAN is configured with a name `vxlan<N>` where `N = 0..255`.

A vxlan-interface is configured under a tunnel-interface. At a minimum, a vxlan-interface must have an index, type, and ingress VNI.

- The index can be a number in the range 0-4294967295.
- The type can be bridged or routed and indicates whether the vxlan-interface can be linked to a mac-vrf (bridged) or ip-vrf (routed).
- The ingress VNI is the VXLAN Network Identifier that the system looks for in incoming VXLAN packets to classify them to this vxlan-interface and its
network-instance. VNI can be in the range of `1..16777215`.  
  The VNI is used to find the MAC-VRF where the inner MAC lookup is performed. The egress VNI is not configured and is determined by the imported EVPN routes.  
  SR Linux requires that the egress VNI (discovered) matches the configured ingress VNI so that two leaf routers attached to the same BD can exchange packets.

!!!note
    The source IP used in the vxlan-interfaces is the IPv4 address of subinterface `system0.0` in the default network-instance.

The above information translates to a configuration snippet which is applicable both to `leaf1` and `leaf2` nodes.

```
enter candidate
    /tunnel-interface vxlan1 {
        vxlan-interface 1 {
            type bridged
            ingress {
                vni 1
            }
        }
    }
commit now
```

To verify the tunnel interface configuration:
```
A:leaf2# show tunnel-interface vxlan-interface brief
---------------------------------------------------------------------------------
Show report for vxlan-tunnels
---------------------------------------------------------------------------------
+------------------+-----------------+---------+-------------+------------------+
| Tunnel Interface | VxLAN Interface |  Type   | Ingress VNI | Egress source-ip |
+==================+=================+=========+=============+==================+
| vxlan1           | vxlan1.1        | bridged | 1           | 10.0.0.2/32      |
+------------------+-----------------+---------+-------------+------------------+
---------------------------------------------------------------------------------
Summary
  1 tunnel-interfaces, 1 vxlan interfaces
  0 vxlan-destinations, 0 unicast, 0 es, 0 multicast, 0 ip
---------------------------------------------------------------------------------
```

## MAC-VRF
Now it is a turn of MAC-VRF to get configured.

The network-instance type `mac-vrf` functions as a broadcast domain. Each mac-vrf network-instance builds a bridge table composed of MAC addresses that can be learned via the data path on network-instance interfaces or via static configuration.


[^1]: as was verified [before](fabric.md#dataplane)