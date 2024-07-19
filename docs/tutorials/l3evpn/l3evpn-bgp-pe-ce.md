---
comments: true
---

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>

# L3 EVPN Instance with BGP PE-CE

Now, off to a more elaborated example where a server wants to talk BGP to datacenter fabric. Maybe it is a k8s node that uses a LoadBalancer such as MetalLB or KubeVIP and wants to expose service to the outside world. Or, it is a fleet of VMs do not require a stretched L2 network, then a BGP speaker on the host could announce the whole subnet to the fabric.

It is enough to say that there are use cases for BGP on the host, and we will show you how to do it.

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":1,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-l3evpn-basics-lab/main/images/diagrams.drawio"}'></div>

## BGP on the Host

In our lab realm, both FRR routers have loopback IPs that need to be advertised to the L3 EVPN Network Instance (ip-vrf). This requires setting up a routing protocol between the clients (frr) and the routers they're connected to (Leaf1 & Leaf2).  
While these are just loopbacks, they can be real routes that need to be advertised to the fabric in real life. Here is what we have on FRR nodes as part of their startup config related to loopbacks:

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

As you can see, both routers come preconfigured with the loopbacks and a simple eBGP configuration waiting for a remote end to establish a session with ipv4 unicast address family.

## BGP on the Leaf

In the previous chapter, we completed the ip-vrf configuration, moving forward, we'll integrate a routing protocol within it to establish connectivity with the client. SR Linux supports OSPF, ISIS, and BGP as a PE-CE protocol. We're opting for BGP because we love it for many reasons.

The BGP configuration in the IP VRF is exactly the same as the global BGP configuration, we just use `ip-vrf-1` as the network instance.

1. **AS Number and Router ID**  
The initial step involves specifying the autonomous system number and router-id for this ip-vrf, which will be uniformly applied across all routers encompassed by this ip-vrf. Ultimately, these routers will function collectively as if they are a singular router distributed over multiple devices.

    ``` srl
    set / network-instance ip-vrf-1 protocols bgp autonomous-system 500
    set / network-instance ip-vrf-1 protocols bgp router-id 10.100.100.100
    ```

1. **BGP Address Family**  
Since our clients use IPv4 addresses, we activate the `ipv4-unicast` address family to facilitate route exchange with the client. Although we could've enabled IPv6 family as well, we chose not to as our clients do not have IPv6 routes to announce.

    ``` srl
    set / network-instance ip-vrf-1 protocols bgp afi-safi ipv4-unicast admin-state enable
    ```

1. **Configure the Neighbor Parameters**  
We configure the BGP peer/neighbor IP and its corresponding autonomous system number, then assign the BGP neighbor to a peer group.

    ``` srl
    set / network-instance ip-vrf-1 protocols bgp group client
    set / network-instance ip-vrf-1 protocols bgp neighbor 192.168.1.100 peer-as 1000000000
    set / network-instance ip-vrf-1 protocols bgp neighbor 192.168.1.100 peer-group client
    ```

1. **Allow BGP to exchange routes by default**  
By default, all incoming and outgoing eBGP routes are blocked. We will disable this default setting to permit all incoming and outgoing routes.

    ``` srl
    set / network-instance ip-vrf-1 protocols bgp ebgp-default-policy import-reject-all false
    set / network-instance ip-vrf-1 protocols bgp ebgp-default-policy export-reject-all false
    ```

1. **Send Default Route to the Client**  
In the previous step, we disabled eBGP's default route blocking. However, eBGP doesn't automatically announce routes to the client since it treats the peer as an external system and only announces selected routes through a policy. To share overlay routes with the client, we must either configure an export route policy or advertise a default route to the client.

    ``` srl
    set / network-instance ip-vrf-1 protocols bgp group client send-default-route ipv4-unicast true
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

Each leaf has successfully established an eBGP session with the CE device and started to receive and advertise ipv4 prefixes.

/// tab | leaf1

```srl
A:leaf1# / show network-instance ip-vrf-1 protocols bgp neighbor
------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "ip-vrf-1"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
+---------+---------+---------+---------+---------+---------+---------+---------+---------+
|  Net-   |  Peer   |  Group  |  Flags  | Peer-AS |  State  | Uptime  | AFI/SAF | [Rx/Act |
|  Inst   |         |         |         |         |         |         |    I    | ive/Tx] |
+=========+=========+=========+=========+=========+=========+=========+=========+=========+
| ip-     | 192.168 | client  | S       | 1000000 | establi | 0d:0h:1 | ipv4-   | [3/1/1] |
| vrf-1   | .1.100  |         |         | 000     | shed    | 8m:47s  | unicast |         |
+---------+---------+---------+---------+---------+---------+---------+---------+---------+
------------------------------------------------------------------------------------------------
Summary:
1 configured neighbors, 1 configured sessions are established,0 disabled peers
0 dynamic peers
```

///

/// tab | leaf2

```srl
:leaf2# / show network-instance ip-vrf-1 protocols bgp neighbor
---------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "ip-vrf-1"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
+---------+---------+---------+---------+---------+---------+---------+---------+---------+
|  Net-   |  Peer   |  Group  |  Flags  | Peer-AS |  State  | Uptime  | AFI/SAF | [Rx/Act |
|  Inst   |         |         |         |         |         |         |    I    | ive/Tx] |
+=========+=========+=========+=========+=========+=========+=========+=========+=========+
| ip-     | 192.168 | client  | S       | 2000000 | establi | 0d:0h:1 | ipv4-   | [3/1/1] |
| vrf-1   | .2.100  |         |         | 000     | shed    | 3m:36s  | unicast |         |
+---------+---------+---------+---------+---------+---------+---------+---------+---------+
---------------------------------------------------------------------------------------------
Summary:
1 configured neighbors, 1 configured sessions are established,0 disabled peers
0 dynamic peers
```

///

Each leaf has announced a default route to its clients and receives the client's loopback IP. We can verify that by checking the advertised and received routes.

/// tab | leaf1 - received

```srl hl_lines="16-17"
A:leaf1# / show network-instance ip-vrf-1 protocols bgp neighbor 192.168.1.100 received-routes ipv4
------------------------------------------------------------------------------------------------
Peer        : 192.168.1.100, remote AS: 1000000000, local AS: 500
Type        : static
Description : None
Group       : client
------------------------------------------------------------------------------------------------
Status codes: u=used, *=valid, >=best, x=stale
Origin codes: i=IGP, e=EGP, ?=incomplete
+---------------------------------------------------------------------------------------+
|  Status    Network    Path-id    Next Hop     MED      LocPref     AsPath     Origin  |
+=======================================================================================+
|            0.0.0.0/   0          192.168.      -         100      [1000000       ?    |
|            0                     1.100                            000,                |
|                                                                   500]                |
|   u*>      1.1.1.1/   0          192.168.      -         100      [1000000       ?    |
|            32                    1.100                            000]                |
|    *       192.168.   0          192.168.      -         100      [1000000       ?    |
|            1.0/24                1.100                            000]                |
+---------------------------------------------------------------------------------------+
------------------------------------------------------------------------------------------------
3 received BGP routes : 1 used 2 valid
------------------------------------------------------------------------------------------------
```

///

/// tab | leaf1 - advertised

```srl
A:leaf1# / show network-instance ip-vrf-1 protocols bgp neighbor 192.168.1.100 advertised-routes ipv4
A:leaf1# / show network-instance ip-vrf-1 protocols bgp neighbor 192.168.1.100 advertised-rout
es ipv4
----------------------------------------------------------------------------------------------
Peer        : 192.168.1.100, remote AS: 1000000000, local AS: 500
Type        : static
Description : None
Group       : client
----------------------------------------------------------------------------------------------
Origin codes: i=IGP, e=EGP, ?=incomplete
+------------------------------------------------------------------------------------------+
|  Network      Path-id      Next Hop       MED        LocPref       AsPath       Origin   |
+==========================================================================================+
| 0.0.0.0/0    0            192.168.1.       -           100       [500]             ?     |
|                           1                                                              |
+------------------------------------------------------------------------------------------+
----------------------------------------------------------------------------------------------
1 advertised BGP routes
----------------------------------------------------------------------------------------------
```

///

Let's examine the routing table of the VRF on each leaf. Both leaves share the same list of routes, with different next hops. Local routes resolve to a local interface, while remote routes learned from the other leaf resolve to a VxLAN tunnel. Routes resolving to a VXLAN tunnel are highlighted for clarity.

/// tab | leaf1

```srl hl_lines="15-18 26-29"
A:leaf1# / show network-instance ip-vrf-1 route-table
---------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance ip-vrf-1
---------------------------------------------------------------------------------------------------------------------------------------------------------
+-----------------+------+-----------+--------------------+---------+---------+--------+-----------+-----------+-----------+-----------+-------------+
|     Prefix      |  ID  |   Route   |    Route Owner     | Active  | Origin  | Metric |   Pref    | Next-hop  | Next-hop  |  Backup   |   Backup    |
|                 |      |   Type    |                    |         | Network |        |           |  (Type)   | Interface | Next-hop  |  Next-hop   |
|                 |      |           |                    |         | Instanc |        |           |           |           |  (Type)   |  Interface  |
|                 |      |           |                    |         |    e    |        |           |           |           |           |             |
+=================+======+===========+====================+=========+=========+========+===========+===========+===========+===========+=============+
| 1.1.1.1/32      | 0    | bgp       | bgp_mgr            | True    | ip-     | 0      | 170       | 192.168.1 | ethernet- |           |             |
|                 |      |           |                    |         | vrf-1   |        |           | .0/24 (in | 1/1.1     |           |             |
|                 |      |           |                    |         |         |        |           | direct/lo |           |           |             |
|                 |      |           |                    |         |         |        |           | cal)      |           |           |             |
| 2.2.2.2/32      | 0    | bgp-evpn  | bgp_evpn_mgr       | True    | ip-     | 0      | 170       | 10.0.0.2/ |           |           |             |
|                 |      |           |                    |         | vrf-1   |        |           | 32 (indir |           |           |             |
|                 |      |           |                    |         |         |        |           | ect/vxlan |           |           |             |
|                 |      |           |                    |         |         |        |           | )         |           |           |             |
| 192.168.1.0/24  | 2    | local     | net_inst_mgr       | True    | ip-     | 0      | 0         | 192.168.1 | ethernet- |           |             |
|                 |      |           |                    |         | vrf-1   |        |           | .1        | 1/1.1     |           |             |
|                 |      |           |                    |         |         |        |           | (direct)  |           |           |             |
| 192.168.1.1/32  | 2    | host      | net_inst_mgr       | True    | ip-     | 0      | 0         | None      | None      |           |             |
|                 |      |           |                    |         | vrf-1   |        |           | (extract) |           |           |             |
| 192.168.1.255/3 | 2    | host      | net_inst_mgr       | True    | ip-     | 0      | 0         | None (bro |           |           |             |
| 2               |      |           |                    |         | vrf-1   |        |           | adcast)   |           |           |             |
| 192.168.2.0/24  | 0    | bgp-evpn  | bgp_evpn_mgr       | True    | ip-     | 0      | 170       | 10.0.0.2/ |           |           |             |
|                 |      |           |                    |         | vrf-1   |        |           | 32 (indir |           |           |             |
|                 |      |           |                    |         |         |        |           | ect/vxlan |           |           |             |
|                 |      |           |                    |         |         |        |           | )         |           |           |             |
+-----------------+------+-----------+--------------------+---------+---------+--------+-----------+-----------+-----------+-----------+-------------+
---------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 routes total                    : 6
IPv4 prefixes with active routes     : 6
IPv4 prefixes with active ECMP routes: 0
---------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 routes total                    : 6
IPv4 prefixes with active routes     : 6
IPv4 prefixes with active ECMP routes: 0
----------------------------------------------------------------------------------------------------------------------------------------------
```

///

/// tab | leaf2

```srl hl_lines="11-14 19-22"
A:leaf2# / show network-instance ip-vrf-1 route-table
---------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance ip-vrf-1
---------------------------------------------------------------------------------------------------------------------------------------------------------
+-----------------+------+-----------+--------------------+---------+---------+--------+-----------+-----------+-----------+-----------+-------------+
|     Prefix      |  ID  |   Route   |    Route Owner     | Active  | Origin  | Metric |   Pref    | Next-hop  | Next-hop  |  Backup   |   Backup    |
|                 |      |   Type    |                    |         | Network |        |           |  (Type)   | Interface | Next-hop  |  Next-hop   |
|                 |      |           |                    |         | Instanc |        |           |           |           |  (Type)   |  Interface  |
|                 |      |           |                    |         |    e    |        |           |           |           |           |             |
+=================+======+===========+====================+=========+=========+========+===========+===========+===========+===========+=============+
| 1.1.1.1/32      | 0    | bgp-evpn  | bgp_evpn_mgr       | True    | ip-     | 0      | 170       | 10.0.0.1/ |           |           |             |
|                 |      |           |                    |         | vrf-1   |        |           | 32 (indir |           |           |             |
|                 |      |           |                    |         |         |        |           | ect/vxlan |           |           |             |
|                 |      |           |                    |         |         |        |           | )         |           |           |             |
| 2.2.2.2/32      | 0    | bgp       | bgp_mgr            | True    | ip-     | 0      | 170       | 192.168.2 | ethernet- |           |             |
|                 |      |           |                    |         | vrf-1   |        |           | .0/24 (in | 1/1.1     |           |             |
|                 |      |           |                    |         |         |        |           | direct/lo |           |           |             |
|                 |      |           |                    |         |         |        |           | cal)      |           |           |             |
| 192.168.1.0/24  | 0    | bgp-evpn  | bgp_evpn_mgr       | True    | ip-     | 0      | 170       | 10.0.0.1/ |           |           |             |
|                 |      |           |                    |         | vrf-1   |        |           | 32 (indir |           |           |             |
|                 |      |           |                    |         |         |        |           | ect/vxlan |           |           |             |
|                 |      |           |                    |         |         |        |           | )         |           |           |             |
| 192.168.2.0/24  | 2    | local     | net_inst_mgr       | True    | ip-     | 0      | 0         | 192.168.2 | ethernet- |           |             |
|                 |      |           |                    |         | vrf-1   |        |           | .1        | 1/1.1     |           |             |
|                 |      |           |                    |         |         |        |           | (direct)  |           |           |             |
| 192.168.2.1/32  | 2    | host      | net_inst_mgr       | True    | ip-     | 0      | 0         | None      | None      |           |             |
|                 |      |           |                    |         | vrf-1   |        |           | (extract) |           |           |             |
| 192.168.2.255/3 | 2    | host      | net_inst_mgr       | True    | ip-     | 0      | 0         | None (bro |           |           |             |
| 2               |      |           |                    |         | vrf-1   |        |           | adcast)   |           |           |             |
+-----------------+------+-----------+--------------------+---------+---------+--------+-----------+-----------+-----------+-----------+-------------+
---------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 routes total                    : 6
IPv4 prefixes with active routes     : 6
IPv4 prefixes with active ECMP routes: 0
---------------------------------------------------------------------------------------------------------------------------------------------------------
```

///

Then let's send a ping between `ce1` and `ce2` loopbacks to ensure that the datapath works.

```
sudo docker exec -i -t l3evpn-ce1 bash
```

```srl
frr1:/# ping 2.2.2.2 -I 1.1.1.1 -c3
PING 2.2.2.2 (2.2.2.2) from 1.1.1.1: 56 data bytes
64 bytes from 2.2.2.2: seq=0 ttl=63 time=2.453 ms
64 bytes from 2.2.2.2: seq=1 ttl=63 time=1.865 ms
64 bytes from 2.2.2.2: seq=2 ttl=63 time=1.922 ms

--- 2.2.2.2 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 1.865/2.080/2.453 ms
```

Great, datapath works!

Control-plane things work exactly the same way as in the previous chapter. We just announce more prefixes via RT5 NLRI, and that's it.

Was a fun run, innit? Let's wrap it up with a quick [summary](summary.md).
