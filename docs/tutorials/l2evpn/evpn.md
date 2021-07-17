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

For that iBGP configuration we will create a group called `iBGP-overlay` which will have the peer-as and local-as set to 100 to form an iBGP neighborship. The group will also host the same permissive `all` routing policy, enabled `evpn` and disabled ipv4-unicast address families.

Each leaf will then have another neighbor addressed by the remote `system0` interface address and local system address as the source. Below you will find the pastable snippets with the aforementioned config:

=== "leaf1"
    ```
    enter candidate

    /network-instance default protocols bgp
        group iBGP-overlay {
            export-policy all
            import-policy all
            peer-as 100
            ipv4-unicast {
                admin-state disable
            }
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
            ipv4-unicast {
                admin-state disable
            }
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

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:6,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/learn-srlinux/site/diagrams/quickstart.drawio&quot;}"></div>

Configuration of access interface is nothing special, we already [configured leaf-spine interfaces](fabric.md#leaf-spine-interfaces) at the fabric configuration stage, so the steps are all familiar. The only detail worth mentioning here is that we have to indicate the type of the subinterface to be [`bridged`](../../basics/ifaces.md#subinterfaces), this makes the interfaces only attachable to a network instance of `mac-vrf` type with MAC learning and layer-2 forwarding enabled.

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

The network-instance type `mac-vrf` functions as a broadcast domain. Each mac-vrf network-instance builds a bridge table composed of MAC addresses that can be learned via the data path on network-instance interfaces, learned via BGP EVPN or provided with static configuration.

We start with associating the access and vxlan interfaces with the mac-vrf to bound them to this network-instance:

```
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

The servers in our fabric do not have any addressing on their `eth1` interfaces by default. It is time to configure IP addresses on both servers, so that they will be ready to communicate with each other once we complete the EVPN service configuration.

By the end of this section, we will have the following addressing scheme complete:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:7,&quot;zoom&quot;:3,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/learn-srlinux/site/diagrams/quickstart.drawio&quot;}"></div>


To connect to a shell of a server execute `docker exec -it <container-name> bash`:

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

Let's try to ping server2 from server1:

```
bash-5.0# ping 192.168.0.2
PING 192.168.0.2 (192.168.0.2) 56(84) bytes of data.
^C
--- 192.168.0.2 ping statistics ---
3 packets transmitted, 0 received, 100% packet loss, time 2028ms
```

That failed, expectedly, as our servers connected to different leafs, and those leafs do not yet have a shared broadcast domain. But by just trying to ping the remote party from server 1, we made the `srv1` interface MAC to get learned by the `leaf1` mac-vrf network instance:

```
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
* `bgp-evpn` - hosts all the commands required to enable EVPN in the network-instance. At a minimum, a reference to `bgp-instance 1` is configured, along with the reference to the vxlan-interface and the EVPN Virtual Identified (EVI).

The following configuration is entered on both leafs:

```
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

```
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

## Verification
### EVPN routes
When the BGP-EVPN is configured in the mac-vrf instance, the leafs start to exchange EVPN routes, which we can verify with the following commands:

```
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

The single route that the leaf1 received/sent is an EVPN Inclusive Multicast Ethernet Tag route (IMET or type 3, RT3).

The IMET route is advertised as soon as bgp-evpn is enabled in the MAC-VRF; it has the following purpose:

* Auto-discovery of the remote VTEPs attached to the same EVI
* Creation of a default flooding list in the MAC-VRF so that BUM frames are replicated

The IMET/RT3 routes can be viewed in summary and detailed modes:

=== "RT3 summary"
    ```
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
    ```
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

???info "Lets catch those routes?"
    Since our lab is launched with containerlab, we can leverage the transparent sniffing of packets that [it offers](https://containerlab.srlinux.dev/manual/wireshark/).

    By capturing on the `e1-49` interface of the `clab-evpn01-leaf1` container, we are able to collect all the packets that are flowing between the nodes. Then we simply flap the EVPN instance in the `vrf-1` network instance to trigger the BGP updates to flow and see them in the live capture.

    [Here is](https://github.com/learn-srlinux/site/blob/master/docs/tutorials/l2evpn/evpn01-imet-routes.pcapng) the pcap file with the IMET routes advertisements between `leaf1` and `leaf2`.

### VXLAN tunnels
After receiving EVPN routes from the remote leafs with VXLAN encapsulation[^4], SR Linux creates VTEPs from the EVPN routes next-hops. The state of the two only remote VTEP we have in our lab is shown below from the `leaf1` switch.

```
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

Once a VTEP is created in the vxlan-tunnel table with a non-zero allocated index[^3], an entry in the tunnel-table is also created for the tunnel.

```
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

[^1]: as was verified [before](fabric.md#dataplane)
[^2]: containerlab assigns mac addresses to the interfaces with OUI `00:C1:AB`. We are changing the generated MAC with a more recognizable address, since we want to easily identify MACs in the bridge tables.
[^3]: If the next hop is not resolved to a route in the default network-instance route-table, the index in the vxlan-tunnel table shows as “0” for the VTEP and no tunnel-table is created.
[^4]: IMET routes have extended community that conveys the encapsulation type. And for VXLAN EVPN it states VXLAN encap. Check [pcap](https://github.com/learn-srlinux/site/blob/master/docs/tutorials/l2evpn/evpn01-imet-routes.pcapng) for reference.