---
comments: true
---

# EVPN configuration

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>

Ethernet Virtual Private Network (EVPN), along with Virtual eXtensible LAN (VXLAN), is a technology that allows Layer 2 and Layer 3 traffic to be tunneled across an IP
network.

The SR Linux EVPN-VXLAN solution enables Layer 2 Broadcast Domains (BDs) in multi-tenant data centers using EVPN for the control plane and VXLAN as the data plane. It includes the following features:

* EVPN for VXLAN tunnels (Layer 2), extending a BD in overlay multi-tenant DCs
* EVPN for VXLAN tunnels (Layer 3), allowing inter-subnet-forwarding for unicast traffic within the same tenant infrastructure

This tutorial is focused on EVPN for VXLAN tunnels Layer 2.

## Overview

EVPN-VXLAN provides Layer-2 connectivity in multi-tenant DCs. EVPN-VXLAN Broadcast Domains (BD) can span several leaf routers connected to the same IP fabric, allowing hosts attached to the same BD to communicate as though they were connected to the same layer-2 switch.

VXLAN tunnels bridge the layer-2 frames between leaf routers with EVPN providing the control plane to automatically setup tunnels and use them efficiently.

The following figure demonstrates this concept where servers `srv1` and `srv2` are connected to the different switches of the routed fabric, but appear to be on the same broadcast domain.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:4,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/quickstart.drawio&quot;}"></div>

Now that the DC fabric has a routed underlay, and the loopbacks of the leaf switches are mutually reachable[^1], we can proceed with the VXLAN based EVPN service configuration.

While doing that we will cover the following topics:

* VXLAN tunnel interface configuration
* Network instances of type `mac-vrf`
* Bridged subinterfaces
* and BGP EVPN control plane configuration

## IBGP for EVPN

Prior to configuring the overlay services we must enable the EVPN address family for the distribution of EVPN routes among leaf routers of the same tenant.

EVPN is enabled using iBGP and typically a Route Reflector (RR), or eBGP. In our example we have only two leafs, so we won't take extra time configuring the iBGP with a spine acting as a Route Reflector, and instead will configure the iBGP between the two leaf switches.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:5,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/quickstart.drawio&quot;}"></div>

For that iBGP configuration we will create a group called `iBGP-overlay` which will have the `peer-as` and `local-as` set to `100` to form an iBGP neighborship. The group will also host the same permissive `all` routing policy, enabled `evpn` and disabled ipv4-unicast address families.

Then for each leaf we add a new BGP neighbor addressed by the remote `system0` interface address and local system address as the source. Below you will find the paste-able snippets with the aforementioned config:

=== "leaf1"
    ```srl
    enter candidate

    /network-instance default protocols bgp
        group iBGP-overlay {
            export-policy all
            import-policy all
            peer-as 100
            afi-safi ipv4-unicast {
                admin-state disable
            }
            afi-safi evpn {
                admin-state enable
            }
            local-as {
                as-number 100
            }
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
    ```srl
    enter candidate

    /network-instance default protocols bgp
        group iBGP-overlay {
            export-policy all
            import-policy all
            peer-as 100
            afi-safi ipv4-unicast {
                admin-state disable
            }
            afi-safi evpn {
                admin-state enable
            }
            local-as {
                as-number 100 
            }
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

```srl linenums="1"
A:leaf1# /show network-instance default protocols bgp neighbor 10.0.0.2
----------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+
| Net-Inst  |   Peer    |   Group   |   Flags   |  Peer-AS  |   State   |  Uptime   | AFI/SAFI  | [Rx/Activ |
|           |           |           |           |           |           |           |           |   e/Tx]   |
+===========+===========+===========+===========+===========+===========+===========+===========+===========+
| default   | 10.0.0.2  | iBGP-     | S         | 100       | establish | 0d:0h:2m: | evpn      | [0/0/0]   |
|           |           | overlay   |           |           | ed        | 9s        |           |           |
+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+
```

Right now, as we don't have any EVPN service created, there are no EVPN routes that are being sent/received, which is indicated in the last column of the table above.

## Access interfaces

Next we are configuring the interfaces from the leaf switches to the corresponding servers. According to our lab's wiring diagram, interface 1 is connected to the server on both leaf switches:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":6,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/quickstart.drawio"}'></div>

Configuration of an access interface is nothing special, we already [configured leaf-spine interfaces](fabric.md#leaf-spine-interfaces) at the fabric configuration stage, so the steps are all familiar. The only detail worth mentioning here is that we have to indicate the type of the subinterface to be `bridged`, this makes the interfaces only attachable to a network instance of `mac-vrf` type with MAC learning and layer-2 forwarding enabled.

The following config is applied to both leaf switches:

```srl
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

A vxlan-interface is configured under a tunnel-interface. At a minimum, a vxlan-interface must have an index, type, and ingress VXLAN Network Identifier (VNI).

* The index can be a number in the range 0-4294967295.
* The type can be bridged or routed and indicates whether the vxlan-interface can be linked to a mac-vrf (bridged) or ip-vrf (routed).
* The ingress VNI is the VXLAN Network Identifier that the system looks for in incoming VXLAN packets to classify them to this vxlan-interface and its
network-instance. VNI can be in the range of `1..16777215`.  
  The VNI is used to find the MAC-VRF where the inner MAC lookup is performed. The egress VNI is not configured and is determined by the imported EVPN routes.  
  SR Linux requires that the egress VNI (discovered) matches the configured ingress VNI so that two leaf routers attached to the same BD can exchange packets.

!!!note
    The source IP used in the vxlan-interfaces is the IPv4 address of subinterface `system0.0` in the default network-instance.

The above information translates to a configuration snippet which is applicable both to `leaf1` and `leaf2` nodes.

```srl
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

```srl
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

Now it is the turn of MAC-VRF to get configured.

The network-instance type `mac-vrf` functions as a broadcast domain. Each mac-vrf network-instance builds a bridge table composed of MAC addresses that can be learned via the data path on network-instance interfaces, via BGP EVPN or provided with static configuration.

With the below snippet, which is applicable to both leaf1 and leaf2, we are associating the access and vxlan interfaces with the mac-vrf. With that we bound them to this network-instance.

```srl
enter candidate
    /network-instance vrf-1 {
        type mac-vrf
        admin-state enable
        interface ethernet-1/1.0 {
        }
        vxlan-interface vxlan1.1 {
        }
    }
commit now
```

## Server interfaces

The servers in our fabric have IPv4 addresses for their `eth1` interfaces configured as per the `exec` instructions in the [topology file](intro.md#lab-deployment). For completeness, we show below how to manually configure the IPv4 addresses on the `eth1` interfaces of the servers.

Our servers connectivity diagram looks like this:

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":7,"zoom":3,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/quickstart.drawio"}'></div>

To connect to a bash shell of a server execute `docker exec -it <container-name> bash`:
/// details | Configure MAC and IP addresses on the servers

Both MAC and IP addresses are automatically configured in our lab definition file via the `exec` command, but should you want to change the addresses/MACs, here is how to do it.

First, connect to the server's bash shell:

=== "srv1"
    ```
    docker exec -it clab-evpn01-srv1 bash
    ```
=== "srv2"
    ```
    docker exec -it clab-evpn01-srv2 bash
    ```

Within the shell, configure MAC address[^2] and IPv4 address for the `eth1` interface according to the diagram above, as with this interface the server is connected to the leaf switch.
=== "srv1"
    ```
    ip link set address 00:c1:ab:00:00:01 dev eth1
    ip addr add 192.168.0.1/24 dev eth1
    ```
=== "srv2"
    ```
    ip link set address 00:c1:ab:00:00:02 dev eth1
    ip addr add 192.168.0.2/24 dev eth1
    ```
///

Let's try to ping server2 from server1:

```
bash-5.0# ping 192.168.0.2
PING 192.168.0.2 (192.168.0.2) 56(84) bytes of data.
^C
--- 192.168.0.2 ping statistics ---
3 packets transmitted, 0 received, 100% packet loss, time 2028ms
```

That failed, expectedly, as our servers connected to different leafs, and those leafs do not yet have a shared broadcast domain. But by just trying to ping the remote party from server 1, we made the `srv1` interface MAC to get learned by the `leaf1` mac-vrf network instance:

```srl
A:leaf1# show network-instance vrf-1 bridge-table mac-table all
----------------------------------------------------------------------------------------------------------------------
Mac-table of network instance vrf-1
----------------------------------------------------------------------------------------------------------------------
+-------------------+--------------------------+-----------+--------+--------+-------+--------------------------+
|      Address      |       Destination        |   Dest    |  Type  | Active | Aging |       Last Update        |
|                   |                          |   Index   |        |        |       |                          |
+===================+==========================+===========+========+========+=======+==========================+
| 00:C1:AB:00:00:01 | ethernet-1/1.0           | 4         | learnt | true   | 242   | 2021-07-13T17:36:23.000Z |
+-------------------+--------------------------+-----------+--------+--------+-------+--------------------------+
Total Irb Macs            :    0 Total    0 Active
Total Static Macs         :    0 Total    0 Active
Total Duplicate Macs      :    0 Total    0 Active
Total Learnt Macs         :    1 Total    1 Active
Total Evpn Macs           :    0 Total    0 Active
Total Evpn static Macs    :    0 Total    0 Active
Total Irb anycast Macs    :    0 Total    0 Active
Total Macs                :    1 Total    1 Active
----------------------------------------------------------------------------------------------------------------------
```

## EVPN in MAC-VRF

To advertise the locally learned MACs to the remote leafs we have to configure EVPN in our `vrf-1` network-instance.

EVPN configuration under the mac-vrf network instance will require two configuration containers:

* `bgp-vpn` - provides the configuration of the bgp-instances where the route-distinguisher and the import/export route-targets used for the EVPN routes exist.
* `bgp-evpn` - hosts all the commands required to enable EVPN in the network-instance. At a minimum, a reference to `bgp-instance 1` is configured, along with the reference to the vxlan-interface and the EVPN Virtual Identifier (EVI).

The following configuration is entered on both leafs:

```srl
enter candidate
    /network-instance vrf-1
        protocols {
            bgp-evpn {
                bgp-instance 1 {
                    admin-state enable
                    vxlan-interface vxlan1.1
                    evi 111
                }
            }
            bgp-vpn {
                bgp-instance 1 {
                    route-target {
                        export-rt target:100:111
                        import-rt target:100:111
                    }
                }
            }
        }
commit now
```

Once configured, the `bgp-vpn` instance can be checked to have the RT/RD values set:

```srl
A:leaf1# show network-instance vrf-1 protocols bgp-vpn bgp-instance 1
=====================================================================
Net Instance   : vrf-1
    bgp Instance 1
---------------------------------------------------------------------
        route-distinguisher: 10.0.0.1:111, auto-derived-from-evi
        export-route-target: target:100:111, manual
        import-route-target: target:100:111, manual
=====================================================================
```

!!!note "VNI to EVI mapping"
    Prior to release 21.11, SR Linux used only **VLAN-based Service** type of mapping between the VNI and EVI. In this option, a single Ethernet broadcast domain (e.g., subnet)
    represented by a VNI is mapped to a unique EVI.[^3]

    Starting from release 21.11 SR Linux supports an [interoperability mode](https://documentation.nokia.com/srlinux/SR_Linux_HTML_R21-11/EVPN-VXLAN_Guide/evpn_interoperability_with_vlan_aware_bundle_services.html) in which SR Linux leaf nodes can be attached to VLAN-aware bundle broadcast domains along with other third-party routers.

## Final configurations

For your convenience, in case you want to jump over the config routines and start with control/data plane verification we provide the resulting configuration[^4] for all the lab nodes. You can copy paste those snippets to the relevant nodes and proceed with verification tasks.

???example "pastable snippets"
    === "leaf1"
        ```srl
        enter candidate
            /routing-policy {
                policy all {
                    default-action {
                        policy-result accept
                    }
                }
            }
            /tunnel-interface vxlan1 {
                vxlan-interface 1 {
                    type bridged
                    ingress {
                        vni 1
                    }
                }
            }
            /network-instance default {
                interface ethernet-1/49.0 {
                }
                interface system0.0 {
                }
                protocols {
                    bgp {
                        autonomous-system 101
                        router-id 10.0.0.1
                        afi-safi ipv4-unicast {
                            admin-state enable
                        }
                        group eBGP-underlay {
                            export-policy all
                            import-policy all
                            peer-as 201
                        }
                        group iBGP-overlay {
                            export-policy all
                            import-policy all
                            peer-as 100
                            afi-safi ipv4-unicast {
                                admin-state disable
                            }
                            afi-safi evpn {
                                admin-state enable
                            }
                            local-as {
                                as-number 100
                            }
                            timers {
                                minimum-advertisement-interval 1
                            }
                        }
                        neighbor 10.0.0.2 {
                            admin-state enable
                            peer-group iBGP-overlay
                            transport {
                                local-address 10.0.0.1
                            }
                        }
                        neighbor 192.168.11.2 {
                            peer-group eBGP-underlay
                        }
                    }
                }
            }

            /network-instance vrf-1 {
                type mac-vrf
                admin-state enable
                interface ethernet-1/1.0 {
                }
                vxlan-interface vxlan1.1 {
                }
                protocols {
                    bgp-evpn {
                        bgp-instance 1 {
                            admin-state enable
                            vxlan-interface vxlan1.1
                            evi 111
                        }
                    }
                    bgp-vpn {
                        bgp-instance 1 {
                            route-target {
                                export-rt target:100:111
                                import-rt target:100:111
                            }
                        }
                    }
                }
            }

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
            /interface ethernet-1/49 {
                subinterface 0 {
                    ipv4 {
                        admin-state enable
                        address 192.168.11.1/30 {
                        }
                    }
                }
            }
            /interface system0 {
                admin-state enable
                subinterface 0 {
                    ipv4 {
                        admin-state enable
                        address 10.0.0.1/32 {
                        }
                    }
                }
            }
        commit now
        ```
    === "leaf2"
        ```srl
        enter candidate
            /routing-policy {
                policy all {
                    default-action {
                        policy-result accept
                    }
                }
            }
            /tunnel-interface vxlan1 {
                vxlan-interface 1 {
                    type bridged
                    ingress {
                        vni 1
                    }
                }
            }
            /network-instance default {
                interface ethernet-1/49.0 {
                }
                interface system0.0 {
                }
                protocols {
                    bgp {
                        autonomous-system 102
                        router-id 10.0.0.2
                        afi-safi ipv4-unicast {
                            admin-state enable
                        }
                        group eBGP-underlay {
                            export-policy all
                            import-policy all
                            peer-as 201
                        }
                        group iBGP-overlay {
                            export-policy all
                            import-policy all
                            peer-as 100
                            afi-safi ipv4-unicast {
                                admin-state disable
                            }
                            afi-safi evpn {
                                admin-state enable
                            }
                            local-as {
                                as-number 100
                            }
                            timers {
                                minimum-advertisement-interval 1
                            }
                        }
                        neighbor 10.0.0.1 {
                            admin-state enable
                            peer-group iBGP-overlay
                            transport {
                                local-address 10.0.0.2
                            }
                        }
                        neighbor 192.168.12.2 {
                            peer-group eBGP-underlay
                        }
                    }
                }
            }
            /network-instance vrf-1 {
                type mac-vrf
                admin-state enable
                interface ethernet-1/1.0 {
                }
                vxlan-interface vxlan1.1 {
                }
                protocols {
                    bgp-evpn {
                        bgp-instance 1 {
                            admin-state enable
                            vxlan-interface vxlan1.1
                            evi 111
                        }
                    }
                    bgp-vpn {
                        bgp-instance 1 {
                            route-target {
                                export-rt target:100:111
                                import-rt target:100:111
                            }
                        }
                    }
                }
            }

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
            interface ethernet-1/49 {
                subinterface 0 {
                    ipv4 {
                        admin-state enable
                        address 192.168.12.1/30 {
                        }
                    }
                }
            }
            interface system0 {
                admin-state enable
                subinterface 0 {
                    ipv4 {
                        admin-state enable
                        address 10.0.0.2/32 {
                        }
                    }
                }
            }
        commit now
        ```
    === "spine1"
        ```srl
        enter candidate
            /routing-policy {
                policy all {
                    default-action {
                        policy-result accept
                    }
                }
            }

            /network-instance default {
                interface ethernet-1/1.0 {
                }
                interface ethernet-1/2.0 {
                }
                interface system0.0 {
                }
                protocols {
                    bgp {
                        autonomous-system 201
                        router-id 10.0.1.1
                        group eBGP-underlay {
                            export-policy all
                            import-policy all
                        }
                        afi-safi ipv4-unicast {
                            admin-state enable
                        }
                        neighbor 192.168.11.1 {
                            peer-as 101
                            peer-group eBGP-underlay
                        }
                        neighbor 192.168.12.1 {
                            peer-as 102
                            peer-group eBGP-underlay
                        }
                    }
                }
            }
            
            /interface ethernet-1/1 {
                subinterface 0 {
                    ipv4 {
                        admin-state enable
                        address 192.168.11.2/30 {
                        }
                    }
                }
            }
            interface ethernet-1/2 {
                subinterface 0 {
                    ipv4 {
                        admin-state enable
                        address 192.168.12.2/30 {
                        }
                    }
                }
            }
            interface system0 {
                admin-state enable
                subinterface 0 {
                    ipv4 {
                        admin-state enable
                        address 10.0.1.1/32 {
                        }
                    }
                }
            }
        commit now
        ```
    === "srv1"
        configuring static MAC and IP on the single interface of a server
        ```bash
        docker exec -it clab-evpn01-srv1 bash
        
        ip link set address 00:c1:ab:00:00:01 dev eth1
        ip addr add 192.168.0.1/24 dev eth1
        ```
    === "srv2"
        configuring static MAC and IP on the single interface of a server
        ```bash
        docker exec -it clab-evpn01-srv2 bash

        ip link set address 00:c1:ab:00:00:02 dev eth1
        ip addr add 192.168.0.2/24 dev eth1
        ```

## Verification

### EVPN IMET routes

When the BGP-EVPN is configured in the mac-vrf instance, the leafs start to exchange EVPN routes, which we can verify with the following commands:

```srl
A:leaf1# /show network-instance default protocols bgp neighbor 10.0.0.2
----------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+
| Net-Inst  |   Peer    |   Group   |   Flags   |  Peer-AS  |   State   |  Uptime   | AFI/SAFI  | [Rx/Activ |
|           |           |           |           |           |           |           |           |   e/Tx]   |
+===========+===========+===========+===========+===========+===========+===========+===========+===========+
| default   | 10.0.0.2  | iBGP-     | S         | 100       | establish | 0d:0h:2m: | evpn      | [1/1/1]   |
|           |           | overlay   |           |           | ed        | 9s        |           |           |
+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+
```

The single route that the leaf1 received/sent is an [EVPN Inclusive Multicast Ethernet Tag](https://datatracker.ietf.org/doc/html/rfc8365#section-9) route (IMET or type 3, RT3).

The IMET route is advertised as soon as bgp-evpn is enabled in the MAC-VRF; it has the following purpose:

* Auto-discovery of the remote VTEPs attached to the same EVI
* Creation of a default flooding list in the MAC-VRF so that BUM frames are replicated

The IMET/RT3 routes can be viewed in summary and detailed modes:

=== "RT3 summary"
    ```srl
    A:leaf1# /show network-instance default protocols bgp routes evpn route-type 3 summary
    ----------------------------------------------------------------------------------------------------------------
    Show report for the BGP route table of network-instance "default"
    ----------------------------------------------------------------------------------------------------------------
    Status codes: u=used, *=valid, >=best, x=stale
    Origin codes: i=IGP, e=EGP, ?=incomplete
    ----------------------------------------------------------------------------------------------------------------
    BGP Router ID: 10.0.0.1      AS: 101      Local AS: 101
    ----------------------------------------------------------------------------------------------------------------
    Type 3 Inclusive Multicast Ethernet Tag Routes
    +--------+---------------------+------------+---------------------+---------------------+---------------------+
    | Status | Route-distinguisher |   Tag-ID   |    Originator-IP    |      neighbor       |      Next-Hop       |
    +========+=====================+============+=====================+=====================+=====================+
    | u*>    | 10.0.0.2:111        | 0          | 10.0.0.2            | 10.0.0.2            | 10.0.0.2            |
    +--------+---------------------+------------+---------------------+---------------------+---------------------+
    ----------------------------------------------------------------------------------------------------------------
    1 Inclusive Multicast Ethernet Tag routes 0 used, 1 valid
    ----------------------------------------------------------------------------------------------------------------
    ```
=== "RT3 detailed"
    ```srl
    A:leaf1# /show network-instance default protocols bgp routes evpn route-type 3 detail
    -------------------------------------------------------------------------------------
    Show report for the EVPN routes in network-instance  "default"
    -------------------------------------------------------------------------------------
    Route Distinguisher: 10.0.0.2:111
    Tag-ID             : 0
    Originating router : 10.0.0.2
    neighbor           : 10.0.0.2
    Received paths     : 1
    Path 1: <Best,Valid,Used,>
        VNI             : 1
        Route source    : neighbor 10.0.0.2 (last modified 2m3s ago)
        Route preference: No MED, LocalPref is 100
        Atomic Aggr     : false
        BGP next-hop    : 10.0.0.2
        AS Path         :  i
        Communities     : [target:100:111, bgp-tunnel-encap:VXLAN]
        RR Attributes   : No Originator-ID, Cluster-List is []
        Aggregation     : None
        Unknown Attr    : None
        Invalid Reason  : None
        Tie Break Reason: none
    --------------------------------------------------------------------------------------
    ```

???info "Lets capture those routes?"
    Since our lab is launched with containerlab, we can leverage the transparent sniffing of packets that [it offers](https://containerlab.dev/manual/wireshark/).

    By capturing on the `e1-49` interface of the `clab-evpn01-leaf1` container, we are able to collect all the packets that are flowing between the nodes. Then we simply flap the EVPN instance in the `vrf-1` network instance to trigger the BGP updates to flow and see them in the live capture.

    [Here is the pcap file](https://github.com/srl-labs/learn-srlinux/blob/master/docs/tutorials/l2evpn/evpn01-imet-routes.pcapng) with the IMET routes advertisements between `leaf1` and `leaf2`.

When the IMET routes from `leaf2` are imported for `vrf-1` network-instance, the corresponding multicast VXLAN destinations are added and can be checked with the following command:

```srl
A:leaf1# show tunnel-interface vxlan1 vxlan-interface 1 bridge-table multicast-destinations destination *
-------------------------------------------------------------------------------
Show report for vxlan-interface vxlan1.1 multicast destinations (flooding-list)
-------------------------------------------------------------------------------
+--------------+------------+-------------------+----------------------+
| VTEP Address | Egress VNI | Destination-index | Multicast-forwarding |
+==============+============+===================+======================+
| 10.0.0.2     | 1          | 160078821962      | BUM                  |
+--------------+------------+-------------------+----------------------+
-------------------------------------------------------------------------------
Summary
  1 multicast-destinations
-------------------------------------------------------------------------------
```

This multicast destination means that BUM frames received on a bridged sub-interface are ingress-replicated to the VTEPs for that EVI as per the table above. For example any ARP traffic will be distributed (ingress-replicated) to the VTEPs from multicast destinations table.

As to the unicast destinations there are none so far, and this is because we haven't yet received any MAC/IP RT2 EVPN routes. But before looking into the RT2 EVPN routes, let's zoom into VXLAN tunnels that got built right after we receive the first IMET RT3 routes.

### VXLAN tunnels

After receiving EVPN routes from the remote leafs with VXLAN encapsulation[^5], SR Linux creates VXLAN tunnels towards remote VTEP, whose address is received in EVPN IMET routes. The state of a single remote VTEP we have in our lab is shown below from the `leaf1` switch.

```srl
A:leaf1# /show tunnel vxlan-tunnel all
----------------------------------------------------------
Show report for vxlan-tunnels
----------------------------------------------------------
+--------------+--------------+--------------------------+
| VTEP Address |    Index     |       Last Change        |
+==============+==============+==========================+
| 10.0.0.2     | 160078821947 | 2021-07-13T21:13:50.000Z |
+--------------+--------------+--------------------------+
1 VXLAN tunnels, 1 active, 0 inactive
----------------------------------------------------------
```

The VXLAN tunnel is built between the `vxlan` interfaces in the MAC-VRF network instances, which internally use `system` interfaces of the `default` network instance as a VTEP:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:8,&quot;zoom&quot;:4,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/quickstart.drawio&quot;}"></div>

Once a VTEP is created in the vxlan-tunnel table with a non-zero allocated index[^6], an entry in the tunnel-table is also created for the tunnel.

```srl
A:leaf1# /show network-instance default tunnel-table all
-------------------------------------------------------------------------------------------------------
Show report for network instance "default" tunnel table
-------------------------------------------------------------------------------------------------------
+-------------+-----------+-------+-------+--------+------------+----------+--------------------------+
| IPv4 Prefix |   Owner   | Type  | Index | Metric | Preference | Fib-prog |       Last Update        |
+=============+===========+=======+=======+========+============+==========+==========================+
| 10.0.0.2/32 | vxlan_mgr | vxlan | 1     | 0      | 0          | Y        | 2021-07-13T21:13:43.424Z |
+-------------+-----------+-------+-------+--------+------------+----------+--------------------------+
-------------------------------------------------------------------------------------------------------
1 VXLAN tunnels, 1 active, 0 inactive
```

### EVPN MAC/IP routes

As was mentioned, when the leafs exchanged only EVPN IMET routes they build the BUM flooding tree (aka multicast destinations), but unicast destinations are yet unknown, which is seen in the below output:

```srl
A:leaf1# show tunnel-interface vxlan1 vxlan-interface 1 bridge-table unicast-destinations destination *
-------------------------------------------------------------------------------
Show report for vxlan-interface vxlan1.1 unicast destinations
-------------------------------------------------------------------------------
Destinations
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
Ethernet Segment Destinations
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
Summary
  0 unicast-destinations, 0 non-es, 0 es
  0 MAC addresses, 0 active, 0 non-active
```

This is due to the fact that no [MAC/IP EVPN routes](https://datatracker.ietf.org/doc/html/rfc7432#section-7.2) are being advertised yet. If we take a look at the MAC table of the `vrf-1`, we will see that no local MAC addresses are there, and this is because the servers haven't yet sent any frames towards the leafs[^7].

```srl
A:leaf1# show network-instance vrf-1 bridge-table mac-table all
-------------------------------------------------------------------------------
Mac-table of network instance vrf-1
-------------------------------------------------------------------------------
Total Irb Macs            :    0 Total    0 Active
Total Static Macs         :    0 Total    0 Active
Total Duplicate Macs      :    0 Total    0 Active
Total Learnt Macs         :    0 Total    0 Active
Total Evpn Macs           :    0 Total    0 Active
Total Evpn static Macs    :    0 Total    0 Active
Total Irb anycast Macs    :    0 Total    0 Active
Total Macs                :    0 Total    0 Active
-------------------------------------------------------------------------------
```

Let's try that ping from `srv1` towards `srv2` once again and see what happens:

```
bash-5.0# ping 192.168.0.2
PING 192.168.0.2 (192.168.0.2) 56(84) bytes of data.
64 bytes from 192.168.0.2: icmp_seq=1 ttl=64 time=1.28 ms
64 bytes from 192.168.0.2: icmp_seq=2 ttl=64 time=0.784 ms
64 bytes from 192.168.0.2: icmp_seq=3 ttl=64 time=0.901 ms
^C
--- 192.168.0.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2013ms
rtt min/avg/max/mdev = 0.784/0.986/1.275/0.209 ms
```

Much better! The dataplane works and we can check that the MAC table in the `vrf-1` network-instance has been populated with local and EVPN-learned MACs:

```srl
A:leaf1# show network-instance vrf-1 bridge-table mac-table all
---------------------------------------------------------------------------------------------------------------------------------------------
Mac-table of network instance vrf-1
---------------------------------------------------------------------------------------------------------------------------------------------
+-------------------+------------------------------------+-----------+-----------+--------+-------+------------------------------------+
|      Address      |            Destination             |   Dest    |   Type    | Active | Aging |            Last Update             |
|                   |                                    |   Index   |           |        |       |                                    |
+===================+====================================+===========+===========+========+=======+====================================+
| 00:C1:AB:00:00:01 | ethernet-1/1.0                     | 4         | learnt    | true   | 240   | 2021-07-18T14:22:55.000Z           |
| 00:C1:AB:00:00:02 | vxlan-interface:vxlan1.1           | 160078821 | evpn      | true   | N/A   | 2021-07-18T14:22:56.000Z           |
|                   | vtep:10.0.0.2 vni:1                | 962       |           |        |       |                                    |
+-------------------+------------------------------------+-----------+-----------+--------+-------+------------------------------------+
Total Irb Macs            :    0 Total    0 Active
Total Static Macs         :    0 Total    0 Active
Total Duplicate Macs      :    0 Total    0 Active
Total Learnt Macs         :    1 Total    1 Active
Total Evpn Macs           :    1 Total    1 Active
Total Evpn static Macs    :    0 Total    0 Active
Total Irb anycast Macs    :    0 Total    0 Active
Total Macs                :    2 Total    2 Active
---------------------------------------------------------------------------------------------------------------------------------------------
```

When traffic is exchanged between `srv1` and `srv2`, the MACs are learned on the access bridged sub-interfaces and advertised in [EVPN MAC/IP routes (type 2, RT2)](https://datatracker.ietf.org/doc/html/rfc7432#section-7.2). The MAC/IP routes are imported, and the MACs programmed in the mac-table.

The below output shows the MAC/IP EVPN route that `leaf1` received from its neighbor. The NLRI information contains the MAC of the `srv2`:

```srl
A:leaf1# show network-instance default protocols bgp routes evpn route-type 2 summary
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Show report for the BGP route table of network-instance "default"
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Status codes: u=used, *=valid, >=best, x=stale
Origin codes: i=IGP, e=EGP, ?=incomplete
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BGP Router ID: 10.0.0.1      AS: 101      Local AS: 101
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Type 2 MAC-IP Advertisement Routes
+-------+----------------+-----------+------------------+----------------+----------------+----------------+----------------+-------------------------------+----------------+
| Statu |     Route-     |  Tag-ID   |   MAC-address    |   IP-address   |    neighbor    |    Next-Hop    |      VNI       |              ESI              |  MAC Mobility  |
|   s   | distinguisher  |           |                  |                |                |                |                |                               |                |
+=======+================+===========+==================+================+================+================+================+===============================+================+
| u*>   | 10.0.0.2:111   | 0         | 00:C1:AB:00:00:0 | 0.0.0.0        | 10.0.0.2       | 10.0.0.2       | 1              | 00:00:00:00:00:00:00:00:00:00 | -              |
|       |                |           | 2                |                |                |                |                |                               |                |
+-------+----------------+-----------+------------------+----------------+----------------+----------------+----------------+-------------------------------+----------------+
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
1 MAC-IP Advertisement routes 1 used, 1 valid
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

The MAC/IP EVPN routes also triggers the creation of the unicast tunnel destinations which were empty before:

```srl
A:leaf1# show tunnel-interface vxlan1 vxlan-interface 1 bridge-table unicast-destinations destination *
---------------------------------------------------------------------------------------------------------------------------------------------
Show report for vxlan-interface vxlan1.1 unicast destinations
---------------------------------------------------------------------------------------------------------------------------------------------
Destinations
---------------------------------------------------------------------------------------------------------------------------------------------
+--------------+------------+-------------------+-----------------------------+
| VTEP Address | Egress VNI | Destination-index | Number MACs (Active/Failed) |
+==============+============+===================+=============================+
| 10.0.0.2     | 1          | 160078821962      | 1(1/0)                      |
+--------------+------------+-------------------+-----------------------------+
---------------------------------------------------------------------------------------------------------------------------------------------
Ethernet Segment Destinations
---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------
Summary
  1 unicast-destinations, 1 non-es, 0 es
  1 MAC addresses, 1 active, 0 non-active
-------------------------------------------------------------------------------
```

!!!tip "packet capture"
    [The following pcap](https://github.com/srl-labs/learn-srlinux/blob/master/docs/tutorials/l2evpn/evpn01-macip-routes.pcapng) was captured a moment before `srv1` started to ping `srv2` on `leaf1` interface `e1-49`.

    It shows how:

    1. ARP frames were first exchanged using the multicast destination, 
    2. next the first ICMP request was sent out by `leaf1` again using the BUM destination, since RT2 routes were not received yet 
    3. and then the MAC/IP EVPN routes were exchanged triggered by the MACs being learned in the dataplane.
    4. after that event, the ICMP Requests and replies were using the unicast destinations, which were created after receiving the MAC/IP EVPN routes.

This concludes the verification steps, as we have a working data plane connectivity between the servers.

[^1]: as was verified [before](fabric.md#dataplane)
[^2]: containerlab assigns mac addresses to the interfaces with OUI `00:C1:AB`. We are changing the generated MAC with a more recognizable address, since we want to easily identify MACs in the bridge tables.
[^3]: Per [section 5.1.2 of RFC 8365](https://datatracker.ietf.org/doc/html/rfc8365#section-5.1.2)
[^4]: Easily extracted with doing `info <container>` where `container` is `routing-policy`, `network-instance *`, `interface *`, `tunnel-interface *`
[^5]: IMET routes have extended community that conveys the encapsulation type. And for VXLAN EVPN it states VXLAN encap. Check [pcap](https://github.com/srl-labs/learn-srlinux/blob/master/docs/tutorials/l2evpn/evpn01-imet-routes.pcapng) for reference.
[^6]: If the next hop is not resolved to a route in the default network-instance route-table, the index in the vxlan-tunnel table shows as “0” for the VTEP and no tunnel-table is created.
[^7]: We did try to ping from `srv1` to `srv2` in [server interfaces](#server-interfaces) section which triggered MAC-VRF to insert a locally learned MAC into its MAC table, but since then this mac has aged out, and thus the table is empty again.
