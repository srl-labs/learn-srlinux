---
comments: true
---

# L3 EVPN Instance with BGP PE-CE

Now, off to a more elaborated example where a workload connected to the leaf talks BGP to it. Maybe it is a Kubernetes node that implements a LoadBalancer service as MetalLB or KubeVIP and wants to expose service to the outside world.  
Or, it is a fleet of hypervisors with virtual machines that don't need a stretched L2 network, then a BGP speaker on the hypervisor could announce the subnets to the fabric.

There are deployment scenarios where the BGP on the host model works great, and we will show you how it can be implemented within our lab.

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":1,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>

In this chapter we will work with `ce1` and `ce2` nodes that belong to the `tenant-2` and connected to the same leaf pair.

## BGP on the Host

Let's first start with the BGP configuration on the workload (aka host) connected to the leaf. The idea behind running a BGP speaker on the host is to have a dynamic routing protocol that can advertise prefixes of the tenant systems running on the host to the fabric.

Instead of having a single IP address assigned to the whole host as in the previous chapter, a single host will announce multiple prefixes, as many as it has tenant networks running on this host. In the lab environment, we will simply use a loopback interface on the host to simulate the tenant network. In reality the BGP speaker will get client networks programmed by other processes like Kubernetes, or configured according to the hypervisor's network configuration.

As per the startup configuration of our CE routers, both have a loopback IP that needs to be advertised to the L3 EVPN Network Instance (ip-vrf). This requires setting up a routing protocol between the CE devices (frr) and the switches they're connected to (Leaf1 & Leaf2).  
Here are the config snippets for both CE nodes:

///tab | ce1

```
--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/frr1.conf:lo-interface"
--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/frr1.conf:bgp"
```

///
///tab | ce2

```
--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/frr2.conf:lo-interface"
--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/frr2.conf:bgp"
```

///

As you can see, both routers come preconfigured with the respective loopbacks to simulate a client prefix that is to be advertised to other clients of the same EVPN service.

Another peculiar thing is that the BGP configuration looks is identical on both CE1 and CE2 - they use the same AS number, peer IP and router ID. We achieve this similarity by using the same configuration on each CE-Leaf pair, which simplifies configuration management and troubleshooting. Here is how the BGP configuration looks like in our mini fabric:

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":10,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>

## BGP on the Leaf

In the previous chapter, we created the `tenant-1` IP VRF, to which servers `srv1` and `srv2` were connected. For Tenant 2 we will configure the `tenant-2` IP VRF and the associated interfaces.

A notable difference in the `tenant-2` IP VRF configuration is that we will configure a routing protocol within this VRF to establish peering with the CE devices.  
SR Linux supports OSPF, ISIS, and BGP as a PE-CE protocol. This time around we choose eBGP as our PE-CE protocol.

The BGP configuration in the IP VRF is exactly the same as the global BGP configuration, we just use `tenant-2` as the network instance name. And remember, the configuration is identical on all leaf switches.

1. **AS Number and Router ID**  
The initial step involves creating the `tenant-2` network instance and specifying the autonomous system number and router-id for this ip-vrf.

    ``` srl
    set / network-instance tenant-2 protocols bgp autonomous-system 65001
    set / network-instance tenant-2 protocols bgp router-id 10.0.0.1
    ```

1. **BGP Address Family**  
Since our clients use IPv4 addresses, we activate the `ipv4-unicast` address family to facilitate route exchange with the client. Although we could've enabled IPv6 family as well, we chose not to as our clients do not have IPv6 routes to announce.

    ``` srl
    set / network-instance tenant-2 protocols bgp afi-safi ipv4-unicast admin-state enable
    ```

1. **Configure the Neighbor Parameters**  
We configure the BGP peer/neighbor IP and its corresponding autonomous system number, then assign the BGP neighbor to a peer group.

    ``` srl
    set / network-instance tenant-2 protocols bgp group client
    set / network-instance tenant-2 protocols bgp neighbor 192.168.99.2 peer-as 65002
    set / network-instance tenant-2 protocols bgp neighbor 192.168.99.2 peer-group client
    ```

1. **Allow BGP to exchange routes by default**  
By default, all incoming and outgoing eBGP routes are blocked. We will disable this default setting to permit all incoming and outgoing routes.

    ``` srl
    set / network-instance tenant-2 protocols bgp ebgp-default-policy import-reject-all false
    set / network-instance tenant-2 protocols bgp ebgp-default-policy export-reject-all false
    ```

1. **Send Default Route to the Client**  
In the previous step, we disabled eBGP's default route import/export blocking. However, eBGP doesn't automatically announce routes to the client since it treats the peer as an external system and only announces selected routes through a policy. To share overlay routes with the client, we must either configure an export route policy or advertise a default route to the client.

    ``` srl
    set / network-instance tenant-2 protocols bgp group client send-default-route ipv4-unicast true
    ```

1. **Customer-facing and VXLAN interfaces**
    Since we created a new IP VRF, we need to add to it a customer facing interface. Our CE devices are connected to `ethernet-1/2` interfaces on the leaf switches; we configure these interfaces with IPv4 addresses and attach them to the `tenant-2` IP VRF.

    ``` srl
    set / interface ethernet-1/2 subinterface 1 admin-state enable
    set / interface ethernet-1/2 subinterface 1 ipv4 admin-state enable
    set / interface ethernet-1/2 subinterface 1 ipv4 address 192.168.99.1/24
    ```

    We need not to forget to create a tunnel interface for this tenant. It needs to be configured with a new VNI value so that our tenants don't mix up their traffic.  
    Since our tenant 1 used VNI 100, we will configure a tunnel interface with a subinterface index 200 and a matching VNI 200 value:

    ``` srl
    set / tunnel-interface vxlan1 vxlan-interface 200 type routed
    set / tunnel-interface vxlan1 vxlan-interface 200 ingress vni 200
    ```

    And add these interfaces to the network instance:

    ``` srl
    set / network-instance tenant-2 interface ethernet-1/2.1
    set / network-instance tenant-2 vxlan-interface vxlan1.200
    ```

1. **EVPN configuration**
    And the last bit is to add the EVPN bgp instance to the `tenant-2` VRF.

    ``` srl
    set / network-instance tenant-2 protocols bgp-evpn bgp-instance 1 admin-state enable
    set / network-instance tenant-2 protocols bgp-evpn bgp-instance 1 vxlan-interface vxlan1.200
    set / network-instance tenant-2 protocols bgp-evpn bgp-instance 1 evi 2
    set / network-instance tenant-2 protocols bgp-vpn bgp-instance 1 route-target export-rt target:65001:2
    set / network-instance tenant-2 protocols bgp-vpn bgp-instance 1 route-target import-rt target:65001:2

    set / network-instance tenant-2 protocols bgp-vpn bgp-instance 1
    set / network-instance tenant-2 protocols bgp-evpn bgp-instance 1 ecmp 8
    ```

The resulting configuration for the leaf routers is as follows:

/// tab | leaf1

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf1.conf:pece"

commit now
```

///
/// tab | leaf2

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/startup_configs/leaf2.conf:pece"

commit now
```

///

## Verification

To ensure that each leaf has successfully established an eBGP session with the CE device and started to receive and advertise ipv4 prefixes issue the following command:

/// tab | leaf1

```srl
A:leaf1# / show network-instance tenant-2 protocols bgp neighbor
------------------------------------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "tenant-2"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------
+----------------+-----------------------+----------------+------+---------+-------------+-------------+------------+-----------------------+
|    Net-Inst    |         Peer          |     Group      | Flag | Peer-AS |    State    |   Uptime    |  AFI/SAFI  |    [Rx/Active/Tx]     |
|                |                       |                |  s   |         |             |             |            |                       |
+================+=======================+================+======+=========+=============+=============+============+=======================+
| tenant-2       | 192.168.99.2          | client         | S    | 65002   | established | 0d:0h:22m:4 | ipv4-      | [2/1/1]               |
|                |                       |                |      |         |             | 5s          | unicast    |                       |
+----------------+-----------------------+----------------+------+---------+-------------+-------------+------------+-----------------------+
------------------------------------------------------------------------------------------------------------------------------------------------
Summary:
1 configured neighbors, 1 configured sessions are established,0 disabled peers
0 dynamic peers
```

///

/// tab | leaf2

```srl
A:leaf2# / show network-instance tenant-2 protocols bgp neighbor
-----------------------------------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "tenant-2"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
-----------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------
+----------------+-----------------------+----------------+------+---------+-------------+-------------+------------+-----------------------+
|    Net-Inst    |         Peer          |     Group      | Flag | Peer-AS |    State    |   Uptime    |  AFI/SAFI  |    [Rx/Active/Tx]     |
|                |                       |                |  s   |         |             |             |            |                       |
+================+=======================+================+======+=========+=============+=============+============+=======================+
| tenant-2       | 192.168.99.2          | client         | S    | 65002   | established | 0d:0h:24m:5 | ipv4-      | [2/1/1]               |
|                |                       |                |      |         |             | 4s          | unicast    |                       |
+----------------+-----------------------+----------------+------+---------+-------------+-------------+------------+-----------------------+
-----------------------------------------------------------------------------------------------------------------------------------------------
Summary:
1 configured neighbors, 1 configured sessions are established,0 disabled peers
0 dynamic peers
```

///

Each leaf has announced a default route to its clients and receives the client's loopback IP. We can verify that by checking the advertised and received routes.

/// tab | leaf1 - received

```srl hl_lines="14"
A:leaf1# / show network-instance tenant-2 protocols bgp neighbor 192.168.99.2 received-routes ipv4
------------------------------------------------------------------------------------------------------------------------------------------------
Peer        : 192.168.99.2, remote AS: 65002, local AS: 65001
Type        : static
Description : None
Group       : client
------------------------------------------------------------------------------------------------------------------------------------------------
Status codes: u=used, *=valid, >=best, x=stale
Origin codes: i=IGP, e=EGP, ?=incomplete
+---------------------------------------------------------------------------------------------------------------------------------------+
|     Status          Network          Path-id          Next Hop           MED            LocPref           AsPath           Origin     |
+=======================================================================================================================================+
|                  0.0.0.0/0        0                192.168.99.2           -               100         [65002, 65001]          ?       |
|      u*>         10.91.91.91/32   0                192.168.99.2           -               100         [65002]                 i       |
+---------------------------------------------------------------------------------------------------------------------------------------+
------------------------------------------------------------------------------------------------------------------------------------------------
2 received BGP routes : 1 used 1 valid
------------------------------------------------------------------------------------------------------------------------------------------------
```

///

/// tab | leaf1 - advertised

```srl
A:leaf1# / show network-instance tenant-2 protocols bgp neighbor 192.168.99.2 advertised-routes ipv4
------------------------------------------------------------------------------------------------------------------------------------------------
Peer        : 192.168.99.2, remote AS: 65002, local AS: 65001
Type        : static
Description : None
Group       : client
------------------------------------------------------------------------------------------------------------------------------------------------
Origin codes: i=IGP, e=EGP, ?=incomplete
+-------------------------------------------------------------------------------------------------------------------------------------------+
|      Network             Path-id            Next Hop               MED               LocPref             AsPath              Origin       |
+===========================================================================================================================================+
| 0.0.0.0/0           0                   192.168.99.1                -                  100          [65001]                     ?         |
+-------------------------------------------------------------------------------------------------------------------------------------------+
------------------------------------------------------------------------------------------------------------------------------------------------
1 advertised BGP routes
------------------------------------------------------------------------------------------------------------------------------------------------
```

///

Let's examine the routing table of the VRF on each leaf. Both leaves share the same list of routes, with different next hops. Local routes resolve to a local interface, while remote routes learned from the other leaf resolve to a VXLAN tunnel.

Loopback route of a remote client is highlighted.

/// tab | leaf1

```srl hl_lines="15-18"
A:leaf1# / show network-instance tenant-2 route-table
--------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance tenant-2
--------------------------------------------------------------------------------------------------------------------------------------------------------------
+------------------+------+-----------+--------------------+---------+---------+--------+-----------+-----------+-----------+-----------+--------------+
|      Prefix      |  ID  |   Route   |    Route Owner     | Active  | Origin  | Metric |   Pref    | Next-hop  | Next-hop  |  Backup   | Backup Next- |
|                  |      |   Type    |                    |         | Network |        |           |  (Type)   | Interface | Next-hop  |     hop      |
|                  |      |           |                    |         | Instanc |        |           |           |           |  (Type)   |  Interface   |
|                  |      |           |                    |         |    e    |        |           |           |           |           |              |
+==================+======+===========+====================+=========+=========+========+===========+===========+===========+===========+==============+
| 10.91.91.91/32   | 0    | bgp       | bgp_mgr            | True    | tenant- | 0      | 170       | 192.168.9 | ethernet- |           |              |
|                  |      |           |                    |         | 2       |        |           | 9.0/30 (i | 1/2.1     |           |              |
|                  |      |           |                    |         |         |        |           | ndirect/l |           |           |              |
|                  |      |           |                    |         |         |        |           | ocal)     |           |           |              |
| 10.92.92.92/32   | 0    | bgp-evpn  | bgp_evpn_mgr       | True    | tenant- | 0      | 170       | 10.0.0.2/ |           |           |              |
|                  |      |           |                    |         | 2       |        |           | 32 (indir |           |           |              |
|                  |      |           |                    |         |         |        |           | ect/vxlan |           |           |              |
|                  |      |           |                    |         |         |        |           | )         |           |           |              |
| 192.168.99.0/30  | 0    | bgp-evpn  | bgp_evpn_mgr       | False   | tenant- | 0      | 170       | 10.0.0.2/ |           |           |              |
|                  |      |           |                    |         | 2       |        |           | 32 (indir |           |           |              |
|                  |      |           |                    |         |         |        |           | ect/vxlan |           |           |              |
|                  |      |           |                    |         |         |        |           | )         |           |           |              |
| 192.168.99.0/30  | 3    | local     | net_inst_mgr       | True    | tenant- | 0      | 0         | 192.168.9 | ethernet- |           |              |
|                  |      |           |                    |         | 2       |        |           | 9.1       | 1/2.1     |           |              |
|                  |      |           |                    |         |         |        |           | (direct)  |           |           |              |
| 192.168.99.1/32  | 3    | host      | net_inst_mgr       | True    | tenant- | 0      | 0         | None      | None      |           |              |
|                  |      |           |                    |         | 2       |        |           | (extract) |           |           |              |
| 192.168.99.3/32  | 3    | host      | net_inst_mgr       | True    | tenant- | 0      | 0         | None (bro |           |           |              |
|                  |      |           |                    |         | 2       |        |           | adcast)   |           |           |              |
+------------------+------+-----------+--------------------+---------+---------+--------+-----------+-----------+-----------+-----------+--------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 routes total                    : 6
IPv4 prefixes with active routes     : 5
IPv4 prefixes with active ECMP routes: 0
--------------------------------------------------------------------------------------------------------------------------------------------------------------
```

///

/// tab | leaf2

```srl hl_lines="11-14"
A:leaf2# / show network-instance tenant-2 route-table
--------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance tenant-2
--------------------------------------------------------------------------------------------------------------------------------------------------------------
+------------------+------+-----------+--------------------+---------+---------+--------+-----------+-----------+-----------+-----------+--------------+
|      Prefix      |  ID  |   Route   |    Route Owner     | Active  | Origin  | Metric |   Pref    | Next-hop  | Next-hop  |  Backup   | Backup Next- |
|                  |      |   Type    |                    |         | Network |        |           |  (Type)   | Interface | Next-hop  |     hop      |
|                  |      |           |                    |         | Instanc |        |           |           |           |  (Type)   |  Interface   |
|                  |      |           |                    |         |    e    |        |           |           |           |           |              |
+==================+======+===========+====================+=========+=========+========+===========+===========+===========+===========+==============+
| 10.91.91.91/32   | 0    | bgp-evpn  | bgp_evpn_mgr       | True    | tenant- | 0      | 170       | 10.0.0.1/ |           |           |              |
|                  |      |           |                    |         | 2       |        |           | 32 (indir |           |           |              |
|                  |      |           |                    |         |         |        |           | ect/vxlan |           |           |              |
|                  |      |           |                    |         |         |        |           | )         |           |           |              |
| 10.92.92.92/32   | 0    | bgp       | bgp_mgr            | True    | tenant- | 0      | 170       | 192.168.9 | ethernet- |           |              |
|                  |      |           |                    |         | 2       |        |           | 9.0/30 (i | 1/2.1     |           |              |
|                  |      |           |                    |         |         |        |           | ndirect/l |           |           |              |
|                  |      |           |                    |         |         |        |           | ocal)     |           |           |              |
| 192.168.99.0/30  | 0    | bgp-evpn  | bgp_evpn_mgr       | False   | tenant- | 0      | 170       | 10.0.0.1/ |           |           |              |
|                  |      |           |                    |         | 2       |        |           | 32 (indir |           |           |              |
|                  |      |           |                    |         |         |        |           | ect/vxlan |           |           |              |
|                  |      |           |                    |         |         |        |           | )         |           |           |              |
| 192.168.99.0/30  | 3    | local     | net_inst_mgr       | True    | tenant- | 0      | 0         | 192.168.9 | ethernet- |           |              |
|                  |      |           |                    |         | 2       |        |           | 9.1       | 1/2.1     |           |              |
|                  |      |           |                    |         |         |        |           | (direct)  |           |           |              |
| 192.168.99.1/32  | 3    | host      | net_inst_mgr       | True    | tenant- | 0      | 0         | None      | None      |           |              |
|                  |      |           |                    |         | 2       |        |           | (extract) |           |           |              |
| 192.168.99.3/32  | 3    | host      | net_inst_mgr       | True    | tenant- | 0      | 0         | None (bro |           |           |              |
|                  |      |           |                    |         | 2       |        |           | adcast)   |           |           |              |
+------------------+------+-----------+--------------------+---------+---------+--------+-----------+-----------+-----------+-----------+--------------+
--------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 routes total                    : 6
IPv4 prefixes with active routes     : 5
IPv4 prefixes with active ECMP routes: 0
--------------------------------------------------------------------------------------------------------------------------------------------------------------
```

///

Then let's send a ping between `ce1` and `ce2` loopbacks to ensure that the datapath works.

```
sudo docker exec -i -t l3evpn-ce1 bash
```

```srl
ce1:/# ping 10.92.92.92 -I 10.91.91.91 -c 2
PING 10.92.92.92 (10.92.92.92) from 10.91.91.91: 56 data bytes
64 bytes from 10.92.92.92: seq=0 ttl=63 time=1.456 ms
64 bytes from 10.92.92.92: seq=1 ttl=63 time=0.845 ms

--- 10.92.92.92 ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.845/1.150/1.456 ms
```

Great, the datapath works!

Control-plane things work exactly the same way as in the previous chapter. We just announce more prefixes via RT5 NLRI, and that's it.

## Pros and Cons?

The BGP on the Host model allows to advertise a range of prefixes from the host using a dynamic routing protocol. Keeping the same configuration on all hosts and leafs simplifies the management and troubleshooting, as well as allows for easy migration of hosts as the BGP config on the host doesn't need to change when the host is moved to another leaf.

At the same time, it requires a BGP speaker on the host, which may not be feasible in all environments and introduces another routing protocol and stack to the host. So, as always, evaluate the trade-offs and choose the model that fits your environment best.

With PE-CE protocol configured, it is possible to achieve multuhoming and load balancing of the traffic between CE devices. The load balancing will be done purely on L3 level using ECMP where CE devices will advertise the same prefixes to the different leafs and therefore the remote CE devices will have multiple paths to reach the advertised prefixes.

We hope this was a fun configration marathon, and you enjoyed getting through this lab? Let's wrap it up with a quick [summary](summary.md).

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
