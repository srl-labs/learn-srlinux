---
comments: true
---

<script type="text/javascript" src="https://cdn.jsdelivr.net/gh/hellt/drawio-js@main/embed2.js" async></script>
LDP is a protocol defined for distributing labels. It is the set of procedures and messages by which Label Switched Routers (LSRs) establish Label Switched Paths (LSPs) through a network by mapping network-layer routing information directly to data-link layer switched paths. These LSPs may have an endpoint at a directly attached neighbor (comparable to IP hop-by-hop forwarding), or may have an endpoint at a network egress node, enabling switching via all intermediary nodes.

This chapter focuses on LDP configuration with verification steps to ensure that LSPs are set up and traffic is properly encapsulated.

## MPLS label manager

SR Linux features an MPLS label manager process that shares the MPLS label space among client applications that require MPLS labels; these applications include static MPLS forwarding and LDP.

LDP must be configured with a reference to a predefined range of labels, called a label block. A label block configuration includes a start-label value and an end-label value. LDP requires a dynamic, non-shared label block.

Although it is absolutely fine to configure the same label block on all the nodes, we will configure each device with a distinctive range for readability.
=== "srl1"
    ```srl
    enter candidate

    set / system mpls
    set / system mpls label-ranges
    set / system mpls label-ranges dynamic D1
    set / system mpls label-ranges dynamic D1 start-label 100
    set / system mpls label-ranges dynamic D1 end-label 199

    commit save
    ```
=== "srl2"
    ```srl
    enter candidate

    set / system mpls
    set / system mpls label-ranges
    set / system mpls label-ranges dynamic D1
    set / system mpls label-ranges dynamic D1 start-label 200
    set / system mpls label-ranges dynamic D1 end-label 299

    commit save
    ```
=== "srl3"
    ```srl
    enter candidate

    set / system mpls
    set / system mpls label-ranges
    set / system mpls label-ranges dynamic D1
    set / system mpls label-ranges dynamic D1 start-label 300
    set / system mpls label-ranges dynamic D1 end-label 399

    commit save
    ```

## LDP neighbor discovery

LDP neighbor discovery allows SR Linux to discover and connect to LDP peers without manually specifying the peers. SR Linux supports basic LDP discovery for discovering LDP peers, using multicast UDP hello messages.

At a minimum, you should enable the LDP process in the network-instance and specify LDP-enabled interfaces.

=== "srl1"
    ```srl
    enter candidate

    set / network-instance default protocols ldp
    set / network-instance default protocols ldp admin-state enable
    set / network-instance default protocols ldp dynamic-label-block D1

    set / network-instance default protocols ldp discovery
    set / network-instance default protocols ldp discovery interfaces
    set / network-instance default protocols ldp discovery interfaces interface ethernet-1/1.0
    set / network-instance default protocols ldp discovery interfaces interface ethernet-1/1.0 ipv4
    set / network-instance default protocols ldp discovery interfaces interface ethernet-1/1.0 ipv4 admin-state enable

    commit save
    ```
=== "srl2"
    ```srl
    enter candidate

    set / network-instance default protocols
    set / network-instance default protocols ldp
    set / network-instance default protocols ldp admin-state enable
    set / network-instance default protocols ldp dynamic-label-block D1
    set / network-instance default protocols ldp discovery

    set / network-instance default protocols ldp discovery interfaces
    set / network-instance default protocols ldp discovery interfaces interface ethernet-1/1.0
    set / network-instance default protocols ldp discovery interfaces interface ethernet-1/1.0 ipv4
    set / network-instance default protocols ldp discovery interfaces interface ethernet-1/1.0 ipv4 admin-state enable

    set / network-instance default protocols ldp discovery interfaces interface ethernet-1/2.0
    set / network-instance default protocols ldp discovery interfaces interface ethernet-1/2.0 ipv4
    set / network-instance default protocols ldp discovery interfaces interface ethernet-1/2.0 ipv4 admin-state enable

    commit save
    ```
=== "srl3"
    ```srl
    enter candidate

    set / network-instance default protocols ldp
    set / network-instance default protocols ldp admin-state enable
    set / network-instance default protocols ldp dynamic-label-block D1

    set / network-instance default protocols ldp discovery
    set / network-instance default protocols ldp discovery interfaces
    set / network-instance default protocols ldp discovery interfaces interface ethernet-1/1.0
    set / network-instance default protocols ldp discovery interfaces interface ethernet-1/1.0 ipv4
    set / network-instance default protocols ldp discovery interfaces interface ethernet-1/1.0 ipv4 admin-state enable

    commit save
    ```

Once enabled, LDP neighborship will establish over the specified interfaces.

=== "neighbors"
    ```srl
    --{ running }--[  ]--
    A:srl2# show network-instance default protocols ldp neighbor
    =================================================================================================
    Net-Inst default LDP neighbors
    -------------------------------------------------------------------------------------------------
    +------------------------------------------------------------------------------------------+
    | Interface    Peer LDP     Nbr          Local        Proposed     Negotiated   Remaining  |
    |              ID           Address      Address      Holdtime     Holdtime     Holdtime   |
    +==========================================================================================+
    | ethernet-1   10.0.0.1:0   10.1.2.1     10.1.2.2     15           15           11         |
    | /1.0                                                                                     |
    | ethernet-1   10.0.0.3:0   10.2.3.2     10.2.3.1     15           15           14         |
    | /2.0                                                                                     |
    +------------------------------------------------------------------------------------------+
    =================================================================================================
    ```
=== "sessions"
    ```srl
    A:srl2# /show network-instance default protocols ldp session
    ================================================================================================
    Net-Inst default LDP Sessions
    ------------------------------------------------------------------------------------------------
    +-------------------------------------------------------------------------------------------+
    | Peer LDP ID                State           Msg Sent   Msg Recv   Last Oper State Change   |
    +===========================================================================================+
    | 10.0.0.1:0                 operational     24         24         2022-03-14T08:08:28.000Z |
    | 10.0.0.3:0                 operational     24         24         2022-03-14T08:08:24.000Z |
    +-------------------------------------------------------------------------------------------+
    No. of sessions: 2
    ```

!!!tip
    [This packet capture][pcap1] sniffed on srl2's `e1-1` shows the LDP multicast hello messages as well as the subsequent Initialization and Notification messages.

## FEC

It is necessary to precisely specify which packets may be mapped to each LSP. This is done by providing a FEC specification for each LSP. The FEC identifies the set of IP packets that may be mapped to that LSP.

Each FEC is specified as a set of one or more FEC elements. Each FEC element identifies a set of packets that may be mapped to the corresponding LSP.

By default, SR Linux supports /32 IPv4 FEC resolution using IGP routes. For example, on `srl2` we see four FECs have been received, and four FECs have been advertised. These FECs were created for `system0` interface IP addresses advertised via IGP.

```srl
A:srl2# /show network-instance default protocols ldp ipv4 fec                                     
==================================================================================================
Net-Inst default LDP IPv4: All FEC prefixes table
==================================================================================================
Received FEC prefixes
--------------------------------------------------------------------------------------------------
+--------------------------------------------------------------------------------------------+
| FEC prefix           Peer LDP ID                 Label                Ingress   Used in    |
|                                                                       LSR       Forwarding |
+============================================================================================+
| 10.0.0.1/32          10.0.0.1:0                  100                  true      true       |
| 10.0.0.1/32          10.0.0.3:0                  304                  true      false      |
| 10.0.0.3/32          10.0.0.1:0                  109                  true      false      |
| 10.0.0.3/32          10.0.0.3:0                  300                  true      true       |
+--------------------------------------------------------------------------------------------+
--------------------------------------------------------------------------------------------------
Advertised FEC prefixes
--------------------------------------------------------------------------------------------------
+--------------------------------------------------------------------------------------------+
| FEC prefix           Peer LDP ID                 Label                Label        Egress  |
|                                                                       Status       LSR     |
+============================================================================================+
| 10.0.0.1/32          10.0.0.3:0                  206                               false   |
| 10.0.0.2/32          10.0.0.1:0                  204                               true    |
| 10.0.0.2/32          10.0.0.3:0                  204                               true    |
| 10.0.0.3/32          10.0.0.1:0                  205                               false   |
+--------------------------------------------------------------------------------------------+
--------------------------------------------------------------------------------------------------
Total received FEC prefixes  : 4 (2 used in forwarding)
Total advertised FEC prefixes: 4
```

The successful labels exchange leads to a populated tunnel table on each MPLS-enabled router. For instance, the tunnel table on `srl1` lists two tunnels for remote loopbacks of `srl2` and `srl3`:

```srl
--{ running }--[  ]--                                                                                                   
A:srl1# show network-instance default tunnel-table all                                                                  
------------------------------------------------------------------------------------------------------------------------
IPv4 tunnel table of network-instance "default"
------------------------------------------------------------------------------------------------------------------------
+-------------+------------+------------+-----------+-----+--------+------------+------------+------------+------------+
| IPv4 Prefix |   Encaps   |   Tunnel   | Tunnel ID | FIB | Metric | Preference |    Last    |  Next-hop  |  Next-hop  |
|             |    Type    |    Type    |           |     |        |            |   Update   |   (Type)   |            |
+=============+============+============+===========+=====+========+============+============+============+============+
| 10.0.0.2/32 | mpls       | ldp        | 65548     | Y   | 10     | 9          | 2022-03-14 | 10.1.2.2   | ethernet-1 |
|             |            |            |           |     |        |            | T08:08:29. | (mpls)     | /1.0       |
|             |            |            |           |     |        |            | 207Z       |            |            |
| 10.0.0.3/32 | mpls       | ldp        | 65549     | Y   | 20     | 9          | 2022-03-14 | 10.1.2.2   | ethernet-1 |
|             |            |            |           |     |        |            | T08:08:29. | (mpls)     | /1.0       |
|             |            |            |           |     |        |            | 219Z       |            |            |
+-------------+------------+------------+-----------+-----+--------+------------+------------+------------+------------+
------------------------------------------------------------------------------------------------------------------------
2 LDP tunnels, 2 active, 0 inactive
------------------------------------------------------------------------------------------------------------------------
```

The label operations can be seen in the mpls route-table report. For example, our LSR `srl2` performs swap operations for labels it assigned for remote FECs and it pops a label `204` as it was assigned to its own `10.0.0.2` FEC.

```srl
A:srl2# /show network-instance default route-table mpls
+---------+-----------+-------------+-----------------+------------------------+----------------------+------------------+
| Label   | Operation | Type        | Next Net-Inst   | Next-hop IP (Type)     | Next-hop             | Next-hop MPLS    |
|         |           |             |                 |                        | Subinterface         | labels           |
+=========+===========+=============+=================+========================+======================+==================+
| 204     | POP       | ldp         | default         |                        |                      |                  |
| 205     | SWAP      | ldp         | N/A             | 10.2.3.2 (mpls)        | ethernet-1/2.0       | 300              |
| 206     | SWAP      | ldp         | N/A             | 10.1.2.1 (mpls)        | ethernet-1/1.0       | 100              |
+---------+-----------+-------------+-----------------+------------------------+----------------------+------------------+
```

## Testing MPLS dataplane

The tunnels established for `system0` loopback FECs cannot be tested as is because they resolve to the existing IGP routes, and thus plain IPv4 transport is used. To test the MPLS dataplane we would need to create another pair of loopbacks on `srl1`/`srl3` nodes and create an iBGP session exchanging these loopbacks; only this time, we will leverage a specific BGP knob asking to resolve the nexthops for these prefixes via LDP tunnel only.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:4,&quot;zoom&quot;:3,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/mpls-ldp.drawio&quot;}"></div>

In the following snippets we configure `lo0` loopbacks following with iBGP peering setup to advertise them.

=== "srl1"
    ```srl
    enter candidate

    # configuring loopback interface
    set / interface lo0
    set / interface lo0 admin-state enable
    set / interface lo0 subinterface 0
    set / interface lo0 subinterface 0 admin-state enable
    set / interface lo0 subinterface 0 ipv4 admin-state enable
    set / interface lo0 subinterface 0 ipv4 address 192.168.99.1/32

    set / network-instance default interface lo0.0

    # configuring export policy to advertise loopbacks via BGP
    set / routing-policy
    set / routing-policy prefix-set LOOPBACK
    set / routing-policy prefix-set LOOPBACK prefix 192.168.99.1/32 mask-length-range exact
    set / routing-policy policy EXPORT_LOOPBACK
    set / routing-policy policy EXPORT_LOOPBACK statement 10
    set / routing-policy policy EXPORT_LOOPBACK statement 10 match
    set / routing-policy policy EXPORT_LOOPBACK statement 10 match family [ ipv4-unicast ]
    set / routing-policy policy EXPORT_LOOPBACK statement 10 match prefix-set LOOPBACK
    set / routing-policy policy EXPORT_LOOPBACK statement 10 action
    set / routing-policy policy EXPORT_LOOPBACK statement 10 action policy-result accept

    # configuring iBGP
    set / network-instance default protocols
    set / network-instance default protocols bgp
    set / network-instance default protocols bgp admin-state enable
    set / network-instance default protocols bgp autonomous-system 65001
    set / network-instance default protocols bgp router-id 10.0.0.1
    set / network-instance default protocols bgp group IBGP
    set / network-instance default protocols bgp group IBGP export-policy EXPORT_LOOPBACK
    set / network-instance default protocols bgp group IBGP afi-safi ipv4-unicast
    set / network-instance default protocols bgp group IBGP afi-safi ipv4-unicast admin-state enable
    set / network-instance default protocols bgp afi-safi ipv4-unicast admin-state enable
    set / network-instance default protocols bgp afi-safi ipv4-unicast ipv4-unicast next-hop-resolution
    set / network-instance default protocols bgp afi-safi ipv4-unicast ipv4-unicast next-hop-resolution ipv4-next-hops
    set / network-instance default protocols bgp afi-safi ipv4-unicast ipv4-unicast next-hop-resolution ipv4-next-hops tunnel-resolution
    set / network-instance default protocols bgp afi-safi ipv4-unicast ipv4-unicast next-hop-resolution ipv4-next-hops tunnel-resolution mode require
    set / network-instance default protocols bgp afi-safi ipv4-unicast ipv4-unicast next-hop-resolution ipv4-next-hops tunnel-resolution allowed-tunnel-types [ ldp ]
    set / network-instance default protocols bgp neighbor 10.0.0.3
    set / network-instance default protocols bgp neighbor 10.0.0.3 admin-state enable
    set / network-instance default protocols bgp neighbor 10.0.0.3 peer-as 65001
    set / network-instance default protocols bgp neighbor 10.0.0.3 peer-group IBGP

    commit save
    ```
=== "srl3"
    ```srl
    enter candidate

    # configuring loopback interface
    set / interface lo0
    set / interface lo0 admin-state enable
    set / interface lo0 subinterface 0
    set / interface lo0 subinterface 0 admin-state enable
    set / interface lo0 subinterface 0 ipv4 admin-state enable
    set / interface lo0 subinterface 0 ipv4 address 192.168.99.3/32

    set / network-instance default interface lo0.0

    # configuring export policy to advertise loopbacks via BGP
    set / routing-policy
    set / routing-policy prefix-set LOOPBACK
    set / routing-policy prefix-set LOOPBACK prefix 192.168.99.3/32 mask-length-range exact
    set / routing-policy policy EXPORT_LOOPBACK
    set / routing-policy policy EXPORT_LOOPBACK statement 10
    set / routing-policy policy EXPORT_LOOPBACK statement 10 match
    set / routing-policy policy EXPORT_LOOPBACK statement 10 match family [ ipv4-unicast ]
    set / routing-policy policy EXPORT_LOOPBACK statement 10 match prefix-set LOOPBACK
    set / routing-policy policy EXPORT_LOOPBACK statement 10 action
    set / routing-policy policy EXPORT_LOOPBACK statement 10 action policy-result accept

    # configuring iBGP
    set / network-instance default protocols
    set / network-instance default protocols bgp
    set / network-instance default protocols bgp admin-state enable
    set / network-instance default protocols bgp autonomous-system 65001
    set / network-instance default protocols bgp router-id 10.0.0.3
    set / network-instance default protocols bgp group IBGP
    set / network-instance default protocols bgp group IBGP export-policy EXPORT_LOOPBACK
    set / network-instance default protocols bgp group IBGP afi-safi ipv4-unicast admin-state enable
    set / network-instance default protocols bgp group IBGP afi-safi ipv4-unicast admin-state enable
    set / network-instance default protocols bgp afi-safi ipv4-unicast admin-state enable
    set / network-instance default protocols bgp afi-safi ipv4-unicast ipv4-unicast next-hop-resolution
    set / network-instance default protocols bgp afi-safi ipv4-unicast ipv4-unicast next-hop-resolution ipv4-next-hops
    set / network-instance default protocols bgp afi-safi ipv4-unicast ipv4-unicast next-hop-resolution ipv4-next-hops tunnel-resolution
    set / network-instance default protocols bgp afi-safi ipv4-unicast ipv4-unicast next-hop-resolution ipv4-next-hops tunnel-resolution mode require
    set / network-instance default protocols bgp afi-safi ipv4-unicast ipv4-unicast next-hop-resolution ipv4-next-hops tunnel-resolution allowed-tunnel-types [ ldp ]
    set / network-instance default protocols bgp neighbor 10.0.0.1
    set / network-instance default protocols bgp neighbor 10.0.0.1 admin-state enable
    set / network-instance default protocols bgp neighbor 10.0.0.1 peer-as 65001
    set / network-instance default protocols bgp neighbor 10.0.0.1 peer-group IBGP

    commit save
    ```

The iBGP peering should establish and both `srl1` and `srl3` nodes should receive loopback prefixes and install them in the routing table. From `srl1` point of view it received the remote loopback over BGP:

```srl
A:srl1# /show network-instance default protocols bgp neighbor 10.0.0.3 received-routes ipv4                                                        
---------------------------------------------------------------------------------------------------------------------------------------------------
Peer        : 10.0.0.3, remote AS: 65001, local AS: 65001
Type        : static
Description : None
Group       : IBGP
---------------------------------------------------------------------------------------------------------------------------------------------------
Status codes: u=used, *=valid, >=best, x=stale
Origin codes: i=IGP, e=EGP, ?=incomplete
+----------------------------------------------------------------------------------------------------------------------------------------------+
| Status         Network                Next Hop             MED          LocPref                       AsPath                       Origin    |
+==============================================================================================================================================+
|  u*>     192.168.99.3/32        10.0.0.3                    -             100                                                         i      |
+----------------------------------------------------------------------------------------------------------------------------------------------+
---------------------------------------------------------------------------------------------------------------------------------------------------
1 received BGP routes : 1 used 1 valid
```

And installed it in the routing table. The notable difference here is that the nexthop (`10.0.0.3`) is indirect, as it is being resolved via mpls/ldp tunnel. We can even see which label will be pushed on the stack[^1].

```srl
A:srl1# /show network-instance default route-table ipv4-unicast prefix 192.168.99.3/32 detail                                                      
---------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance default
---------------------------------------------------------------------------------------------------------------------------------------------------
Destination   : 192.168.99.3/32
ID            : 0
Route Type    : bgp
Route Owner   : bgp_mgr
Metric        : 0
Preference    : 170
Active        : true
Last change   : 2022-03-14T09:05:46.076Z
Resilient hash: false
---------------------------------------------------------------------------------------------------------------------------------------------------
Next hops: 1 entries
10.0.0.3 (indirect) resolved by tunnel to 10.0.0.3/32 (ldp)
  via 10.1.2.2 (mpls) via [ethernet-1/1.0]
      pushed MPLS labels : [205]
---------------------------------------------------------------------------------------------------------------------------------------------------
```

Now it is time to test the datapath with a ping between newly created loopbacks[^2].

```srl
--{ + running }--[  ]--
A:srl1# ping network-instance default 192.168.99.3 -I 192.168.99.1
Using network instance default
PING 192.168.99.3 (192.168.99.3) from 192.168.99.1 : 56(84) bytes of data.
64 bytes from 192.168.99.3: icmp_seq=1 ttl=64 time=15.3 ms
64 bytes from 192.168.99.3: icmp_seq=2 ttl=64 time=9.32 ms
64 bytes from 192.168.99.3: icmp_seq=3 ttl=64 time=16.7 ms
64 bytes from 192.168.99.3: icmp_seq=4 ttl=64 time=14.9 ms
^C
--- 192.168.99.3 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 9.316/14.063/16.727/2.823 ms
```

Yay! It works. Now let's see if we indeed had MPLS encapsulation used for that packet exchange. To quickly test this you can run a tcpdump on any node of the topology filtering mpls packets. For instance, let's connect to `srl1` shell via `docker exec` command and start listening for mpls packets on e1-1 interface:

```bash
docker exec -it srl1 bash
[root@srl1 /]# tcpdump -nnvi e1-1 mpls

tcpdump: listening on e1-1, link-type EN10MB (Ethernet), snapshot length 262144 bytes
09:54:03.700378 MPLS (label 205, exp 0, [S], ttl 64) # (1)!
        IP (tos 0x0, ttl 64, id 50746, offset 0, flags [DF], proto ICMP (1), length 84)
    192.168.99.1 > 192.168.99.3: ICMP echo request, id 52902, seq 1, length 64
09:54:03.707775 MPLS (label 100, exp 0, [S], ttl 63) # (2)!
        IP (tos 0x0, ttl 64, id 63961, offset 0, flags [none], proto ICMP (1), length 84)
    192.168.99.3 > 192.168.99.1: ICMP echo reply, id 52902, seq 1, length 64
09:54:04.701840 MPLS (label 205, exp 0, [S], ttl 64)
        IP (tos 0x0, ttl 64, id 50797, offset 0, flags [DF], proto ICMP (1), length 84)
    192.168.99.1 > 192.168.99.3: ICMP echo request, id 52902, seq 2, length 64
09:54:04.707592 MPLS (label 100, exp 0, [S], ttl 63)
        IP (tos 0x0, ttl 64, id 64000, offset 0, flags [none], proto ICMP (1), length 84)
    192.168.99.3 > 192.168.99.1: ICMP echo reply, id 52902, seq 2, length 64
```

1. MPLS frame with label `205` encapsulates ICMP echo request sourced from srl1
2. MPLS frame with label `100` encapsulates ICMP echo reply coming from srl2

This evidence clearly shows the MPLS encapsulation in play. In addition to that, we have captured a [pcap][pcap2] on `srl2:e-1` interface for ICMP packets in case you would like to look at the entire packet encapsulation and framing.

![pic](https://gitlab.com/rdodin/pics/-/wikis/uploads/9f448c82a667603c0eebb1bcc40fbfba/image.png)

## Complete lab

It is great to follow the tutorial doing all the steps yourself. But maybe not every single time :stuck_out_tongue_winking_eye: For those who just want to get a looksee at the LDP-in-action we created complete config snippets for the nodes so that they can boot with everything pre-provisioned and ready.

You can fetch the config snippets with `curl`:

```
curl -LO https://raw.githubusercontent.com/srl-labs/learn-srlinux/main/labs/mpls-ldp/srl1.cfg
curl -LO https://raw.githubusercontent.com/srl-labs/learn-srlinux/main/labs/mpls-ldp/srl2.cfg
curl -LO https://raw.githubusercontent.com/srl-labs/learn-srlinux/main/labs/mpls-ldp/srl3.cfg
```

Put the downloaded config files next to the topology file and make sure to uncomment `startup-config` elements for each node:

```yaml
--8<-- "labs/mpls-ldp/mpls-ldp.clab.yml"
```

Deploy the lab as usual, and you should have everything ready once the lab is deployed.

[pcap1]: https://github.com/srl-labs/learn-srlinux/blob/main/docs/tutorials/mpls/mpls-ldp/ldp-neighborship.pcapng
[pcap2]: https://github.com/srl-labs/learn-srlinux/blob/main/docs/tutorials/mpls/mpls-ldp/icmp-mpls.pcapng
[^1]: the label number (205) indicates that this label comes from `srl2`, as we configured 200-299 label range block on srl2 device.
[^2]: one could also introduce linux clients to the topology, connect them to srl1/3 nodes and test the connectivity that way.
