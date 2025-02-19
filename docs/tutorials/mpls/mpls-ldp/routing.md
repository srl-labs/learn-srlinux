---
comments: true
---

# Routing

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>

Prior to any MPLS configuration, we need to set up routing in the network core. Configuration of interfaces and IGP is the core task explained in this section.

## Interfaces

Let's start with basic interfaces configuration following this diagram:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:2,&quot;zoom&quot;:3,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/mpls-ldp.drawio&quot;}"></div>

The below config snippets configure regular `Ethernet-1/1`, `Ethernet-1/2` and a special loopback `system0` interfaces.

=== "srl1"
    ```srl
    enter candidate # (1)!

    set / interface ethernet-1/1
    set / interface ethernet-1/1 admin-state enable
    set / interface ethernet-1/1 subinterface 0
    set / interface ethernet-1/1 subinterface 0 admin-state enable
    set / interface ethernet-1/1 subinterface 0 ipv4 admin-state enable
    set / interface ethernet-1/1 subinterface 0 ipv4 address 10.1.2.1/30

    set / interface system0
    set / interface system0 admin-state enable
    set / interface system0 subinterface 0
    set / interface system0 subinterface 0 admin-state enable
    set / interface system0 subinterface 0 ipv4 admin-state enable
    set / interface system0 subinterface 0 ipv4 address 10.0.0.1/32

    set / network-instance default
    set / network-instance default interface ethernet-1/1.0
    set / network-instance default interface system0.0

    commit save
    ```

    1. config snippets contain `enter candidate` command to switch to configuration context.  
    At the bottom of the snippet `commit save` command will perform a `commit` operation followed by saving the running config to a startup config file.
=== "srl2"
    ```srl
    enter candidate

    set / interface ethernet-1/1
    set / interface ethernet-1/1 admin-state enable
    set / interface ethernet-1/1 subinterface 0
    set / interface ethernet-1/1 subinterface 0 admin-state enable
    set / interface ethernet-1/1 subinterface 0 ipv4 admin-state enable
    set / interface ethernet-1/1 subinterface 0 ipv4 address 10.1.2.2/30

    set / interface ethernet-1/2
    set / interface ethernet-1/2 admin-state enable
    set / interface ethernet-1/2 subinterface 0
    set / interface ethernet-1/2 subinterface 0 admin-state enable
    set / interface ethernet-1/2 subinterface 0 ipv4 admin-state enable
    set / interface ethernet-1/2 subinterface 0 ipv4 address 10.2.3.1/30

    set / interface system0
    set / interface system0 admin-state enable
    set / interface system0 subinterface 0
    set / interface system0 subinterface 0 admin-state enable
    set / interface system0 subinterface 0 ipv4 admin-state enable
    set / interface system0 subinterface 0 ipv4 address 10.0.0.2/32

    set / network-instance default
    set / network-instance default interface ethernet-1/1.0
    set / network-instance default interface ethernet-1/2.0
    set / network-instance default interface system0.0

    commit save
    ```
=== "srl3"
    ```srl
    enter candidate

    set / interface ethernet-1/1
    set / interface ethernet-1/1 admin-state enable
    set / interface ethernet-1/1 subinterface 0
    set / interface ethernet-1/1 subinterface 0 admin-state enable
    set / interface ethernet-1/1 subinterface 0 ipv4 admin-state enable
    set / interface ethernet-1/1 subinterface 0 ipv4 address 10.2.3.2/30

    set / interface system0
    set / interface system0 admin-state enable
    set / interface system0 subinterface 0
    set / interface system0 subinterface 0 admin-state enable
    set / interface system0 subinterface 0 ipv4 admin-state enable
    set / interface system0 subinterface 0 ipv4 address 10.0.0.3/32

    set / network-instance default
    set / network-instance default interface ethernet-1/1.0
    set / network-instance default interface system0.0

    commit save
    ```

When the interface config is committed[^1], routers should be able to ping each neighbor's interface address.

=== "srl1 pings srl2"
    ```srl
    --{ running }--[  ]--
    A:srl1# ping network-instance default 10.1.2.2
    Using network instance default
    PING 10.1.2.2 (10.1.2.2) 56(84) bytes of data.
    64 bytes from 10.1.2.2: icmp_seq=1 ttl=64 time=49.7 ms
    ```
=== "srl2 pings srl3"
    ```srl
    --{ running }--[  ]--
    A:srl2# ping network-instance default 10.2.3.2
    Using network instance default
    PING 10.2.3.2 (10.2.3.2) 56(84) bytes of data.
    64 bytes from 10.2.3.2: icmp_seq=1 ttl=64 time=0.033 ms
    ```

## IGP

With interfaces config done, proceed with configuring an IGP protocol to redistribute the loopback address information among all routers. In this tutorial, we will use IS-IS routing protocol to achieve this goal.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:3,&quot;zoom&quot;:3,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/mpls-ldp.drawio&quot;}"></div>

=== "srl1"
    ```srl
    enter candidate

    set / network-instance default protocols isis
    set / network-instance default protocols isis instance ISIS
    set / network-instance default protocols isis instance ISIS admin-state enable
    set / network-instance default protocols isis instance ISIS level-capability L2
    set / network-instance default protocols isis instance ISIS net [ 49.0001.0000.0000.0001.00 ]
    set / network-instance default protocols isis instance ISIS ipv4-unicast
    set / network-instance default protocols isis instance ISIS ipv4-unicast admin-state enable

    set / network-instance default protocols isis instance ISIS interface ethernet-1/1.0
    set / network-instance default protocols isis instance ISIS interface ethernet-1/1.0 circuit-type point-to-point
    set / network-instance default protocols isis instance ISIS interface ethernet-1/1.0 ipv4-unicast
    set / network-instance default protocols isis instance ISIS interface ethernet-1/1.0 ipv4-unicast admin-state enable
    set / network-instance default protocols isis instance ISIS interface ethernet-1/1.0 level 2

    set / network-instance default protocols isis instance ISIS interface system0.0
    set / network-instance default protocols isis instance ISIS interface system0.0 admin-state enable
    set / network-instance default protocols isis instance ISIS interface system0.0 passive true
    set / network-instance default protocols isis instance ISIS interface system0.0 ipv4-unicast
    set / network-instance default protocols isis instance ISIS interface system0.0 ipv4-unicast admin-state enable
    set / network-instance default protocols isis instance ISIS interface system0.0 level 2

    commit save
    ```
=== "srl2"
    ```srl
    enter candidate

    set / network-instance default protocols isis
    set / network-instance default protocols isis instance ISIS
    set / network-instance default protocols isis instance ISIS admin-state enable
    set / network-instance default protocols isis instance ISIS level-capability L2
    set / network-instance default protocols isis instance ISIS net [ 49.0001.0000.0000.0002.00 ]
    set / network-instance default protocols isis instance ISIS ipv4-unicast
    set / network-instance default protocols isis instance ISIS ipv4-unicast admin-state enable
    set / network-instance default protocols isis instance ISIS interface ethernet-1/1.0
    set / network-instance default protocols isis instance ISIS interface ethernet-1/1.0 circuit-type point-to-point
    set / network-instance default protocols isis instance ISIS interface ethernet-1/1.0 ipv4-unicast
    set / network-instance default protocols isis instance ISIS interface ethernet-1/1.0 ipv4-unicast admin-state enable
    set / network-instance default protocols isis instance ISIS interface ethernet-1/1.0 level 2

    set / network-instance default protocols isis instance ISIS interface ethernet-1/2.0
    set / network-instance default protocols isis instance ISIS interface ethernet-1/2.0 circuit-type point-to-point
    set / network-instance default protocols isis instance ISIS interface ethernet-1/2.0 ipv4-unicast
    set / network-instance default protocols isis instance ISIS interface ethernet-1/2.0 ipv4-unicast admin-state enable
    set / network-instance default protocols isis instance ISIS interface ethernet-1/2.0 level 2

    set / network-instance default protocols isis instance ISIS interface system0.0
    set / network-instance default protocols isis instance ISIS interface system0.0 admin-state enable
    set / network-instance default protocols isis instance ISIS interface system0.0 passive true
    set / network-instance default protocols isis instance ISIS interface system0.0 ipv4-unicast
    set / network-instance default protocols isis instance ISIS interface system0.0 ipv4-unicast admin-state enable
    set / network-instance default protocols isis instance ISIS interface system0.0 level 2

    commit save
    ```
=== "srl3"
    ```srl
    enter candidate

    set / network-instance default protocols isis
    set / network-instance default protocols isis instance ISIS
    set / network-instance default protocols isis instance ISIS admin-state enable
    set / network-instance default protocols isis instance ISIS level-capability L2
    set / network-instance default protocols isis instance ISIS net [ 49.0001.0000.0000.0003.00 ]
    set / network-instance default protocols isis instance ISIS ipv4-unicast
    set / network-instance default protocols isis instance ISIS ipv4-unicast admin-state enable
    set / network-instance default protocols isis instance ISIS interface ethernet-1/1.0
    set / network-instance default protocols isis instance ISIS interface ethernet-1/1.0 circuit-type point-to-point
    set / network-instance default protocols isis instance ISIS interface ethernet-1/1.0 ipv4-unicast
    set / network-instance default protocols isis instance ISIS interface ethernet-1/1.0 ipv4-unicast admin-state enable
    set / network-instance default protocols isis instance ISIS interface ethernet-1/1.0 level 2

    set / network-instance default protocols isis instance ISIS interface system0.0
    set / network-instance default protocols isis instance ISIS interface system0.0 admin-state enable
    set / network-instance default protocols isis instance ISIS interface system0.0 passive true
    set / network-instance default protocols isis instance ISIS interface system0.0 ipv4-unicast
    set / network-instance default protocols isis instance ISIS interface system0.0 ipv4-unicast admin-state enable
    set / network-instance default protocols isis instance ISIS interface system0.0 level 2

    commit save
    ```

All routers now should have enabled IS-IS adjacency with their respective neighbors, and the routing table should contain respective `system0.0` loopback addresses. A view from `srl2` side:

=== "Adjacency"
    ```srl
    --{ running }--[  ]--
    A:srl2# show  /network-instance default protocols isis adjacency
    -----------------------------------------------------------------------------------------------------------------------
    Network Instance: default
    Instance        : ISIS
    +----------------+----------------+---------------+------------+--------------+-------+---------------+---------------+
    | Interface Name |    Neighbor    |   Adjacency   | Ip Address | Ipv6 Address | State |     Last      |   Remaining   |
    |                |   System Id    |     Level     |            |              |       |  transition   |   holdtime    |
    +================+================+===============+============+==============+=======+===============+===============+
    | ethernet-1/1.0 | 0000.0000.0001 | L2            | 10.1.2.1   | ::           | up    | 2022-03-13T14 | 23            |
    |                |                |               |            |              |       | :15:57.500Z   |               |
    | ethernet-1/2.0 | 0000.0000.0003 | L2            | 10.2.3.2   | ::           | up    | 2022-03-13T14 | 21            |
    |                |                |               |            |              |       | :25:50.100Z   |               |
    +----------------+----------------+---------------+------------+--------------+-------+---------------+---------------+
    Adjacency Count: 2
    -----------------------------------------------------------------------------------------------------------------------
    ```
=== "Routing table"
    The below output verifies that `srl2` has successfully received loopbacks prefixes from `srl1/3` nodes.
    ```srl
    --{ running }--[  ]--
    A:srl2# /show network-instance default route-table all | grep isis
    | 10.0.0.1/32 | 0    | isis      | isis_mgr            | True/success        | 10      | 18     | 10.1.2 | ethern |
    | 10.0.0.3/32 | 0    | isis      | isis_mgr            | True/success        | 10      | 18     | 10.2.3 | ethern |
    ```

With IGP setup is done, we can proceed with LDP configuration.

[^1]: for instance, with `commit save` command executed from within configuration context.
