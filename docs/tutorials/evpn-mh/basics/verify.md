---
comments: true
---

Let's verify that the configuration we have done so far is working as expected.

## LAG

Starting from the interface level let's check the LAG and LACP status on our leaf switches leaf1 and leaf2:

```srl
--{ + running }--[  ]--
A:leaf1# show interface lag1
==========================================================================================================================================
lag1 is up, speed None, type None
  lag1.0 is up
    Network-instance: mac-vrf-1
    Encapsulation   : null
    Type            : bridged
------------------------------------------------------------------------------------------------------------------------------------------
==========================================================================================================================================

--{ running }--[  ]--
A:leaf1# show lag lag1 lacp-state
------------------------------------------------------------------------------------------------------------------------------------------
LACP State for lag1
------------------------------------------------------------------------------------------------------------------------------------------
Lag Id         : lag1
Interval       : SLOW
Mode           : ACTIVE
System Id      : 00:00:00:00:00:11
System Priority: 11
+--------------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+
|   Members    |   Oper    | Activity  |  Timeout  |   State   | System Id | Oper key  |  Partner  |  Partner  |  Port No  |  Partner  |
|              |   state   |           |           |           |           |           |    Id     |    Key    |           |  Port No  |
+==============+===========+===========+===========+===========+===========+===========+===========+===========+===========+===========+
| ethernet-1/1 | up        | ACTIVE    | LONG      | IN_SYNC/T | 00:00:00: | 11        | 00:C1:AB: | 15        | 1         | 1         |
|              |           |           |           | rue/True/ | 00:00:11  |           | 00:00:11  |           |           |           |
|              |           |           |           | True      |           |           |           |           |           |           |
+--------------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+
------------------------------------------------------------------------------------------------------------------------------------------
```

The LAG status and network instance it belongs to can be seen in the `show interface lag1` output, and `show lag lag1 lacp-state` command shows the LACP parameters as well as the status information of the member ports.

The output on leaf1 and leaf2 is expected to be the same, except for the `partner port no`, which is unique per peer.

## Ethernet Segment

To see the details of Ethernet Segment `ES-1`:

=== "leaf1"

    ```srl
    --{ + running }--[  ]--
    A:leaf1# show system network-instance ethernet-segments ES-1 detail
    ===============================================================================================================
    Ethernet Segment
    ===============================================================================================================
    Name                 : ES-1
    Admin State          : enable              Oper State        : up
    ESI                  : 01:11:11:11:11:11:11:00:00:01
    Multi-homing         : all-active          Oper Multi-homing : all-active
    Interface            : lag1
    Next Hop             : N/A
    EVI                  : N/A
    ES Activation Timer  : None
    DF Election          : default             Oper DF Election  : default

    Last Change          : 2023-08-16T14:53:30.270Z
    ===============================================================================================================
    MAC-VRF   Actv Timer Rem   DF
    ES-1      0                Yes
    ---------------------------------------------------------------------------------------------------------------
    DF Candidates
    ---------------------------------------------------------------------------------------------------------------
    Network-instance       ES Peers
    mac-vrf-1              10.0.0.1
    mac-vrf-1              10.0.0.2 (DF)
    ===============================================================================================================
    ```

=== "leaf2"

    ```srl
    --{ + running }--[  ]--
    A:leaf2# show system network-instance ethernet-segments ES-1 detail 
    =============================================================================================
    Ethernet Segment
    =============================================================================================
    Name                 : ES-1
    Admin State          : enable              Oper State        : up
    ESI                  : 01:11:11:11:11:11:11:00:00:01
    Multi-homing         : all-active          Oper Multi-homing : all-active
    Interface            : lag1
    Next Hop             : N/A
    EVI                  : N/A
    ES Activation Timer  : None
    DF Election          : default             Oper DF Election  : default

    Last Change          : 2023-10-12T11:27:48.364Z
    =============================================================================================
    MAC-VRF   Actv Timer Rem   DF
    ES-1      0                Yes
    ---------------------------------------------------------------------------------------------
    DF Candidates
    ---------------------------------------------------------------------------------------------
    Network-instance       ES Peers
    mac-vrf-1              10.0.0.1
    mac-vrf-1              10.0.0.2 (DF)
    =============================================================================================
    ```

The configured ES parameters, operational status, as well as the ES peers and the selected Designated Forwarder (DF) are displayed here.1

!note "Designated Forwarders"
    <A Designated Forwarder (DF) in EVPN multihoming is a Provider Edge (PE) router that is responsible for forwarding broadcast, unknown unicast, and multicast (BUM) traffic to a multihomed Customer Edge (CE) device on a given Ethernet Segment (ES). The DF is elected by the PEs that are connected to the ES, and the election is based on the PEs' router IDs.>

## Traffic test

Let's send some CE to CE traffic to see if multihoming works and traffic is utilizing all available links.

To create multiple flows with enough variability to trigger flow hashing we will use `nmap` utility. The `nmap` launched from CE1 will "ping scan" open ports on the remote CE2 using three different IP addresses we have configured on CE2.

Open three SSH sessions towards `CE1`. Run `tcpdump` in two of them targeting `eth1` and `eth2` interfaces respectively. In the third session we run `nmap` to send traffic to `CE2`, which hosts three IPs (192.168.0.21-23):

```bash
ssh admin@clab-evpn-mh-ce1 #(1)!
```

1. Credentials `admin:srllabs@123`

=== "nmap"
    ```
    Warning:  You are not root -- using TCP pingscan rather than ICMP
    Starting Nmap 7.80 ( https://nmap.org ) at 2023-10-12 12:51 UTC
    Nmap scan report for 192.168.0.21
    Host is up (0.00087s latency).
    Not shown: 999 closed ports
    PORT   STATE SERVICE
    22/tcp open  ssh

    Nmap scan report for 192.168.0.22
    Host is up (0.00061s latency).
    Not shown: 999 closed ports
    PORT   STATE SERVICE
    22/tcp open  ssh

    Nmap scan report for 192.168.0.23
    Host is up (0.00086s latency).
    Not shown: 999 closed ports
    PORT   STATE SERVICE
    22/tcp open  ssh

    Nmap done: 3 IP addresses (3 hosts up) scanned in 23.24 seconds
    ```
=== "eth1 tcpdump"
    ```text linenums="1" hl_lines="10"
    bash-5.0# tcpdump -ni eth1
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on eth1, link-type EN10MB (Ethernet), capture size 262144 bytes
    13:58:07.487592 LACPv1, length 110
    13:58:10.807635 ARP, Request who-has 192.168.0.22 tell 192.168.0.11, length 28
    13:58:10.807677 ARP, Request who-has 192.168.0.23 tell 192.168.0.11, length 28
    13:58:10.807687 ARP, Request who-has 192.168.0.21 tell 192.168.0.11, length 28
    13:58:10.810885 ARP, Reply 192.168.0.22 is-at 00:c1:ab:00:00:22, length 28
    13:58:10.810990 ARP, Reply 192.168.0.23 is-at 00:c1:ab:00:00:23, length 28
    13:58:10.857873 IP 192.168.0.11.49747 > 192.168.0.23.445: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    13:58:10.857902 IP 192.168.0.11.49747 > 192.168.0.21.445: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    13:58:10.857936 IP 192.168.0.11.49747 > 192.168.0.23.23: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    13:58:10.857949 IP 192.168.0.11.49747 > 192.168.0.21.23: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    13:58:10.857975 IP 192.168.0.11.49747 > 192.168.0.23.3389: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    13:58:10.857989 IP 192.168.0.11.49747 > 192.168.0.21.3389: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    13:58:10.860176 IP 192.168.0.22.23 > 192.168.0.11.49747: Flags [R.], seq 0, ack 2625981133, win 0, length 0
    13:58:10.860265 IP 192.168.0.22.443 > 192.168.0.11.49747: Flags [R.], seq 0, ack 2625981133, win 0, length 0
    13:58:10.862538 IP 192.168.0.11.49747 > 192.168.0.23.443: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    13:58:10.862585 IP 192.168.0.11.49747 > 192.168.0.21.443: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    13:58:10.862647 IP 192.168.0.11.49747 > 192.168.0.23.199: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    13:58:10.862696 IP 192.168.0.11.49747 > 192.168.0.21.199: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    13:58:10.862795 IP 192.168.0.11.49747 > 192.168.0.23.111: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    ```
=== "eth2 tcpdump"
    ```text linenums="1" hl_lines="12"
    bash-5.0# tcpdump -ni eth2
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on eth2, link-type EN10MB (Ethernet), capture size 262144 bytes
    13:58:10.810595 ARP, Reply 192.168.0.21 is-at 00:c1:ab:00:00:21, length 28
    13:58:10.857768 IP 192.168.0.11.49747 > 192.168.0.22.445: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    13:58:10.857916 IP 192.168.0.11.49747 > 192.168.0.22.23: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    13:58:10.857962 IP 192.168.0.11.49747 > 192.168.0.22.3389: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    13:58:10.858002 IP 192.168.0.11.49747 > 192.168.0.22.443: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    13:58:10.859723 IP 192.168.0.22.445 > 192.168.0.11.49747: Flags [R.], seq 0, ack 2625981133, win 0, length 0
    13:58:10.859846 IP 192.168.0.22.3389 > 192.168.0.11.49747: Flags [R.], seq 0, ack 2625981133, win 0, length 0
    13:58:10.862474 IP 192.168.0.11.49747 > 192.168.0.22.199: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    13:58:10.862478 IP 192.168.0.23.445 > 192.168.0.11.49747: Flags [R.], seq 0, ack 2625981133, win 0, length 0
    13:58:10.862592 IP 192.168.0.21.445 > 192.168.0.11.49747: Flags [R.], seq 0, ack 2625981133, win 0, length 0
    13:58:10.862620 IP 192.168.0.11.49747 > 192.168.0.22.111: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    13:58:10.862653 IP 192.168.0.23.3389 > 192.168.0.11.49747: Flags [R.], seq 0, ack 2625981133, win 0, length 0
    13:58:10.862727 IP 192.168.0.11.49747 > 192.168.0.22.143: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    13:58:10.862772 IP 192.168.0.21.3389 > 192.168.0.11.49747: Flags [R.], seq 0, ack 2625981133, win 0, length 0
    13:58:10.866605 IP 192.168.0.11.49747 > 192.168.0.22.80: Flags [S], seq 2625981132, win 1024, options [mss 1460], length 0
    ```

Check the tcpdump output for `eth1` and `eth2` interfaces when sending traffic with nmap. You should see that the traffic is balanced for both incoming and outgoing packets.  
For example, the highlighted line in `eth1` output shows the outgoing request `IP 192.168.0.11.49747 > 192.168.0.23.445: Flags [S]` going out from `eth1` interface. And then the reply `IP 192.168.0.23.445 > 192.168.0.11.49747: Flags [R.]` is seen on `eth2`.

!!!note
    Outgoing ARP packets may not be balanced because load balancing mode of the bond is layer2 by default.

## EVPN Routes

When doing the traffic tests we triggered some EVPN routes exchange in the fabric.

Let's check which EVPN routes leaf1 and leaf2 (ES peers) advertise to each other:

=== "leaf1"
    ```srl
    --{ + running }--[  ]--
    A:leaf1# show network-instance default protocols bgp neighbor 10.0.0.2 advertised-routes evpn
    ------------------------------------------------------------------------------------------------------------------------------
    Peer        : 10.0.0.2, remote AS: 100, local AS: 100
    Type        : static
    Description : None
    Group       : iBGP-overlay
    ------------------------------------------------------------------------------------------------------------------------------
    Origin codes: i=IGP, e=EGP, ?=incomplete
    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------
    Type 1 Ethernet Auto-Discovery Routes
    +----------------+--------------------------------+------------+----------------+----------------+---------+----------------+
    |     Route-     |              ESI               |   Tag-ID   |    Next-Hop    |      MED       | LocPref |      Path      |
    | distinguisher  |                                |            |                |                |         |                |
    +================+================================+============+================+================+=========+================+
    | 10.0.0.1:111   | 01:11:11:11:11:11:11:00:00:01  | 0          | 10.0.0.1       | -              | 100     |                |
    | 10.0.0.1:111   | 01:11:11:11:11:11:11:00:00:01  | 4294967295 | 10.0.0.1       | -              | 100     |                |
    +----------------+--------------------------------+------------+----------------+----------------+---------+----------------+
    Type 2 MAC-IP Advertisement Routes
    +---------------+------------+-------------------+---------------+---------------+---------------+---------+---------------+
    |    Route-     |   Tag-ID   |    MAC-address    |  IP-address   |   Next-Hop    |      MED      | LocPref |     Path      |
    | distinguisher |            |                   |               |               |               |         |               |
    +===============+============+===================+===============+===============+===============+=========+===============+
    | 10.0.0.1:111  | 0          | 00:C1:AB:00:00:11 | 0.0.0.0       | 10.0.0.1      | -             | 100     |               |
    +---------------+------------+-------------------+---------------+---------------+---------------+---------+---------------+
    ------------------------------------------------------------------------------------------------------------------------------
    Type 3 Inclusive Multicast Ethernet Tag Routes
    +-------------------+------------+---------------------+-------------------+-------------------+---------+-------------------+
    |      Route-       |   Tag-ID   |    Originator-IP    |     Next-Hop      |        MED        | LocPref |       Path        |
    |   distinguisher   |            |                     |                   |                   |         |                   |
    +===================+============+=====================+===================+===================+=========+===================+
    | 10.0.0.1:111      | 0          | 10.0.0.1            | 10.0.0.1          | -                 | 100     |                   |
    +-------------------+------------+---------------------+-------------------+-------------------+---------+-------------------+
    ------------------------------------------------------------------------------------------------------------------------------
    Type 4 Ethernet Segment Routes
    +---------------+--------------------------------+---------------+---------------+---------------+---------+---------------+
    |    Route-     |              ESI               | Originating-  |   Next-Hop    |      MED      | LocPref |     Path      |
    | distinguisher |                                |      IP       |               |               |         |               |
    +===============+================================+===============+===============+===============+=========+===============+
    | 10.0.0.1:0    | 01:11:11:11:11:11:11:00:00:01  | 10.0.0.1      | 10.0.0.1      | -             | 100     |               |
    +---------------+--------------------------------+---------------+---------------+---------------+---------+---------------+
    ------------------------------------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------------------------------------
    2 advertised Ethernet Auto-Discovery routes
    1 advertised MAC-IP Advertisement routes
    1 advertised Inclusive Multicast Ethernet Tag routes
    1 advertised Ethernet Segment routes
    0 advertised IP Prefix routes
    ------------------------------------------------------------------------------------------------------------------------------
    ```
=== "leaf2"
    ```srl
    --{ + running }--[  ]--
    A:leaf2# show network-instance default protocols bgp neighbor 10.0.0.1 advertised-routes evpn
    ---------------------------------------------------------------------------------------------------------------------------
    Peer        : 10.0.0.1, remote AS: 100, local AS: 100
    Type        : static
    Description : None
    Group       : iBGP-overlay
    ---------------------------------------------------------------------------------------------------------------------------
    Origin codes: i=IGP, e=EGP, ?=incomplete
    ---------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------
    Type 1 Ethernet Auto-Discovery Routes
    +---------------+--------------------------------+------------+---------------+---------------+---------+---------------+
    |    Route-     |              ESI               |   Tag-ID   |   Next-Hop    |      MED      | LocPref |     Path      |
    | distinguisher |                                |            |               |               |         |               |
    +===============+================================+============+===============+===============+=========+===============+
    | 10.0.0.2:111  | 01:11:11:11:11:11:11:00:00:01  | 0          | 10.0.0.2      | -             | 100     |               |
    | 10.0.0.2:111  | 01:11:11:11:11:11:11:00:00:01  | 4294967295 | 10.0.0.2      | -             | 100     |               |
    +---------------+--------------------------------+------------+---------------+---------------+---------+---------------+
    Type 3 Inclusive Multicast Ethernet Tag Routes
    +------------------+------------+---------------------+------------------+------------------+---------+------------------+
    |      Route-      |   Tag-ID   |    Originator-IP    |     Next-Hop     |       MED        | LocPref |       Path       |
    |  distinguisher   |            |                     |                  |                  |         |                  |
    +==================+============+=====================+==================+==================+=========+==================+
    | 10.0.0.2:111     | 0          | 10.0.0.2            | 10.0.0.2         | -                | 100     |                  |
    +------------------+------------+---------------------+------------------+------------------+---------+------------------+
    ---------------------------------------------------------------------------------------------------------------------------
    Type 4 Ethernet Segment Routes
    +--------------+--------------------------------+--------------+--------------+--------------+---------+--------------+
    | Route-distin |              ESI               | Originating- |   Next-Hop   |     MED      | LocPref |     Path     |
    |   guisher    |                                |      IP      |              |              |         |              |
    +==============+================================+==============+==============+==============+=========+==============+
    | 10.0.0.2:0   | 01:11:11:11:11:11:11:00:00:01  | 10.0.0.2     | 10.0.0.2     | -            | 100     |              |
    +--------------+--------------------------------+--------------+--------------+--------------+---------+--------------+
    ---------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------
    2 advertised Ethernet Auto-Discovery routes
    0 advertised MAC-IP Advertisement routes
    1 advertised Inclusive Multicast Ethernet Tag routes
    1 advertised Ethernet Segment routes
    0 advertised IP Prefix routes
    ---------------------------------------------------------------------------------------------------------------------------
    ```
RT1, RT3 and RT4 routes are triggered by configuration (ES and MAC-VRF), while RT2 routes (MAC-IP) only appear when a MAC is learned or statically configured.

Among these, RT4 is known as ES routes imported by ES peers for DF election and local biasing (split-horizon). It is advertised/received here only by leaf1 and leaf2.

RT1 also advertises ESIs, mainly for two reasons (hence two entries per ESI):

+ Aliasing for load balancing (0)
+ Mass withdrawal for fast convergence (4294967295)

Let's see what leaf2 and leaf3 get in their BGP EVPN route table:

=== "leaf2"
    ```srl
    --{ + running }--[  ]--
    A:leaf2# show network-instance default protocols bgp routes evpn route-type summary
    ---------------------------------------------------------------------------------------------------------------------------
    Show report for the BGP route table of network-instance "default"
    ---------------------------------------------------------------------------------------------------------------------------
    Status codes: u=used, *=valid, >=best, x=stale
    Origin codes: i=IGP, e=EGP, ?=incomplete
    ---------------------------------------------------------------------------------------------------------------------------
    BGP Router ID: 10.0.0.2      AS: 102      Local AS: 102
    ---------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------
    Type 1 Ethernet Auto-Discovery Routes
    +--------+---------------+--------------------------------+------------+---------------+---------------+---------------+
    | Status |    Route-     |              ESI               |   Tag-ID   |   neighbor    |   Next-hop    |      VNI      |
    |        | distinguisher |                                |            |               |               |               |
    +========+===============+================================+============+===============+===============+===============+
    | u*>    | 10.0.0.1:111  | 01:11:11:11:11:11:11:00:00:01  | 0          | 10.0.0.1      | 10.0.0.1      | 1             |
    | u*>    | 10.0.0.1:111  | 01:11:11:11:11:11:11:00:00:01  | 4294967295 | 10.0.0.1      | 10.0.0.1      | -             |
    +--------+---------------+--------------------------------+------------+---------------+---------------+---------------+
    Type 2 MAC-IP Advertisement Routes
    +-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+
    |  Status   | Route-dis |  Tag-ID   |   MAC-    |    IP-    | neighbor  | Next-Hop  |    VNI    |    ESI    |    MAC    |
    |           | tinguishe |           |  address  |  address  |           |           |           |           | Mobility  |
    |           |     r     |           |           |           |           |           |           |           |           |
    +===========+===========+===========+===========+===========+===========+===========+===========+===========+===========+
    | u*>       | 10.0.0.1: | 0         | 00:C1:AB: | 0.0.0.0   | 10.0.0.1  | 10.0.0.1  | 1         | 01:11:11: | -         |
    |           | 111       |           | 00:00:11  |           |           |           |           | 11:11:11: |           |
    |           |           |           |           |           |           |           |           | 11:00:00: |           |
    |           |           |           |           |           |           |           |           | 01        |           |
    | u*>       | 10.0.0.3: | 0         | 00:C1:AB: | 0.0.0.0   | 10.0.0.3  | 10.0.0.3  | 1         | 00:00:00: | -         |
    |           | 111       |           | 00:00:21  |           |           |           |           | 00:00:00: |           |
    |           |           |           |           |           |           |           |           | 00:00:00: |           |
    |           |           |           |           |           |           |           |           | 00        |           |
    | u*>       | 10.0.0.3: | 0         | 00:C1:AB: | 0.0.0.0   | 10.0.0.3  | 10.0.0.3  | 1         | 00:00:00: | -         |
    |           | 111       |           | 00:00:22  |           |           |           |           | 00:00:00: |           |
    |           |           |           |           |           |           |           |           | 00:00:00: |           |
    |           |           |           |           |           |           |           |           | 00        |           |
    | u*>       | 10.0.0.3: | 0         | 00:C1:AB: | 0.0.0.0   | 10.0.0.3  | 10.0.0.3  | 1         | 00:00:00: | -         |
    |           | 111       |           | 00:00:23  |           |           |           |           | 00:00:00: |           |
    |           |           |           |           |           |           |           |           | 00:00:00: |           |
    |           |           |           |           |           |           |           |           | 00        |           |
    +-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+
    ---------------------------------------------------------------------------------------------------------------------------
    Type 3 Inclusive Multicast Ethernet Tag Routes
    +--------+-------------------------+------------+---------------------+-------------------------+-------------------------+
    | Status |   Route-distinguisher   |   Tag-ID   |    Originator-IP    |        neighbor         |        Next-Hop         |
    +========+=========================+============+=====================+=========================+=========================+
    | u*>    | 10.0.0.1:111            | 0          | 10.0.0.1            | 10.0.0.1                | 10.0.0.1                |
    | u*>    | 10.0.0.3:111            | 0          | 10.0.0.3            | 10.0.0.3                | 10.0.0.3                |
    +--------+-------------------------+------------+---------------------+-------------------------+-------------------------+
    ---------------------------------------------------------------------------------------------------------------------------
    Type 4 Ethernet Segment Routes
    +--------+-------------------+--------------------------------+-------------------+-------------------+-------------------+
    | Status |      Route-       |              ESI               |   originating-    |     neighbor      |     Next-Hop      |
    |        |   distinguisher   |                                |      router       |                   |                   |
    +========+===================+================================+===================+===================+===================+
    | u*>    | 10.0.0.1:0        | 01:11:11:11:11:11:11:00:00:01  | 10.0.0.1          | 10.0.0.1          | 10.0.0.1          |
    +--------+-------------------+--------------------------------+-------------------+-------------------+-------------------+
    ---------------------------------------------------------------------------------------------------------------------------
    2 Ethernet Auto-Discovery routes 2 used, 2 valid
    4 MAC-IP Advertisement routes 4 used, 4 valid
    2 Inclusive Multicast Ethernet Tag routes 2 used, 2 valid
    1 Ethernet Segment routes 1 used, 1 valid
    0 IP Prefix routes 0 used, 0 valid
    ---------------------------------------------------------------------------------------------------------------------------
    ```
=== "leaf3"
    ```srl
    --{ running }--[  ]--
    A:leaf3# show network-instance default protocols bgp routes evpn route-type summary
    ---------------------------------------------------------------------------------------------------------------------------
    Show report for the BGP route table of network-instance "default"
    ---------------------------------------------------------------------------------------------------------------------------
    Status codes: u=used, *=valid, >=best, x=stale
    Origin codes: i=IGP, e=EGP, ?=incomplete
    ---------------------------------------------------------------------------------------------------------------------------
    BGP Router ID: 10.0.0.3      AS: 103      Local AS: 103
    ---------------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------------
    Type 1 Ethernet Auto-Discovery Routes
    +--------+---------------+--------------------------------+------------+---------------+---------------+---------------+
    | Status |    Route-     |              ESI               |   Tag-ID   |   neighbor    |   Next-hop    |      VNI      |
    |        | distinguisher |                                |            |               |               |               |
    +========+===============+================================+============+===============+===============+===============+
    | u*>    | 10.0.0.1:111  | 01:11:11:11:11:11:11:00:00:01  | 0          | 10.0.0.1      | 10.0.0.1      | 1             |
    | u*>    | 10.0.0.1:111  | 01:11:11:11:11:11:11:00:00:01  | 4294967295 | 10.0.0.1      | 10.0.0.1      | -             |
    | u*>    | 10.0.0.2:111  | 01:11:11:11:11:11:11:00:00:01  | 0          | 10.0.0.2      | 10.0.0.2      | 1             |
    | u*>    | 10.0.0.2:111  | 01:11:11:11:11:11:11:00:00:01  | 4294967295 | 10.0.0.2      | 10.0.0.2      | -             |
    +--------+---------------+--------------------------------+------------+---------------+---------------+---------------+
    Type 2 MAC-IP Advertisement Routes
    +-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+
    |  Status   | Route-dis |  Tag-ID   |   MAC-    |    IP-    | neighbor  | Next-Hop  |    VNI    |    ESI    |    MAC    |
    |           | tinguishe |           |  address  |  address  |           |           |           |           | Mobility  |
    |           |     r     |           |           |           |           |           |           |           |           |
    +===========+===========+===========+===========+===========+===========+===========+===========+===========+===========+
    | u*>       | 10.0.0.1: | 0         | 00:C1:AB: | 0.0.0.0   | 10.0.0.1  | 10.0.0.1  | 1         | 01:11:11: | -         |
    |           | 111       |           | 00:00:11  |           |           |           |           | 11:11:11: |           |
    |           |           |           |           |           |           |           |           | 11:00:00: |           |
    |           |           |           |           |           |           |           |           | 01        |           |
    +-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+
    ---------------------------------------------------------------------------------------------------------------------------
    Type 3 Inclusive Multicast Ethernet Tag Routes
    +--------+-------------------------+------------+---------------------+-------------------------+-------------------------+
    | Status |   Route-distinguisher   |   Tag-ID   |    Originator-IP    |        neighbor         |        Next-Hop         |
    +========+=========================+============+=====================+=========================+=========================+
    | u*>    | 10.0.0.1:111            | 0          | 10.0.0.1            | 10.0.0.1                | 10.0.0.1                |
    | u*>    | 10.0.0.2:111            | 0          | 10.0.0.2            | 10.0.0.2                | 10.0.0.2                |
    +--------+-------------------------+------------+---------------------+-------------------------+-------------------------+
    ---------------------------------------------------------------------------------------------------------------------------
    4 Ethernet Auto-Discovery routes 4 used, 4 valid
    1 MAC-IP Advertisement routes 1 used, 1 valid
    2 Inclusive Multicast Ethernet Tag routes 2 used, 2 valid
    0 Ethernet Segment routes 0 used, 0 valid
    0 IP Prefix routes 0 used, 0 valid
    ---------------------------------------------------------------------------------------------------------------------------
    ```

As an ES peer, leaf2 receives both RT1 and RT4 in its table, while leaf3 only imports RT1 since it is a remote PE.

## MAC Table

Finally, check the MAC table of the `mac-vrf-1` on leaf3, which should show the `esi` instead of an individual destination for the MAC address of ce1.

```
--{ running }--[  ]--
A:leaf3# show network-instance mac-vrf-1 bridge-table mac-table all
-----------------------------------------------------------------------------------------------------------------------------------------------------

Mac-table of network instance mac-vrf-1
-----------------------------------------------------------------------------------------------------------------------------------------------------

+--------------------+---------------------------------------+------------+------------+---------+--------+---------------------------------------+
|      Address       |              Destination              | Dest Index |    Type    | Active  | Aging  |              Last Update              |
+====================+=======================================+============+============+=========+========+=======================================+
| 00:C1:AB:00:00:11  | vxlan-interface:vxlan1.1              | 7173081172 | evpn       | true    | N/A    | 2023-08-17T10:34:59.000Z              |
|                    | esi:01:11:11:11:11:11:11:00:00:01     | 20         |            |         |        |                                       |
| 00:C1:AB:00:00:21  | ethernet-1/1.0                        | 3          | learnt     | true    | 300    | 2023-08-17T10:34:59.000Z              |
| 00:C1:AB:00:00:22  | ethernet-1/2.0                        | 4          | learnt     | true    | 300    | 2023-08-17T10:35:01.000Z              |
| 00:C1:AB:00:00:23  | ethernet-1/3.0                        | 5          | learnt     | true    | 300    | 2023-08-17T10:35:03.000Z              |
+--------------------+---------------------------------------+------------+------------+---------+--------+---------------------------------------+
Total Irb Macs                 :    0 Total    0 Active
Total Static Macs              :    0 Total    0 Active
Total Duplicate Macs           :    0 Total    0 Active
Total Learnt Macs              :    3 Total    3 Active
Total Evpn Macs                :    1 Total    1 Active
Total Evpn static Macs         :    0 Total    0 Active
Total Irb anycast Macs         :    0 Total    0 Active
Total Proxy Antispoof Macs     :    0 Total    0 Active
Total Reserved Macs            :    0 Total    0 Active
Total Eth-cfm Macs             :    0 Total    0 Active
--{ running }--[  ]--

```

## ESI-based Load-Balancing

MAC addresses learned through EVPN typically show the VTEP (PE) router in the destination column, while MAC addresses of multihomed devices are instead assigned the EVPN Segment Identifier (ESI), which can refer to multiple VTEP destinations.  
The use of ESIs here ensures the load balancing as it refers to multiple VTEPs if ECMP is enabled.

```
--{ running }--[  ]--
A:leaf3# show tunnel-interface vxlan1 vxlan-interface 1 bridge-table unicast-destinations destination  
---------------------------------------------------------------------------------------------------------------------------------------------------------
Show report for vxlan-interface vxlan1.1 unicast destinations
---------------------------------------------------------------------------------------------------------------------------------------------------------
Destinations
---------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------
Ethernet Segment Destinations
---------------------------------------------------------------------------------------------------------------------------------------------------------
+-------------------------------+-------------------+--------------------+-----------------------------+
|              ESI              | Destination-index |       VTEPs        | Number MACs (Active/Failed) |
+===============================+===================+====================+=============================+
| 01:11:11:11:11:11:11:00:00:01 | 95631942551       | 10.0.0.1, 10.0.0.2 | 1(1/0)                      |
+-------------------------------+-------------------+--------------------+-----------------------------+
---------------------------------------------------------------------------------------------------------------------------------------------------------
Summary
  1 unicast-destinations, 0 non-es, 1 es
  1 MAC addresses, 1 active, 0 non-active
---------------------------------------------------------------------------------------------------------------------------------------------------------
--{ + running }--[  ]--
```

As the output shows, the ESI assigned on both leaves resolves to two VTEPs, which are the two PEs we have in our fabric. This means that the traffic from leaf3 will be load balanced between the two PEs based on the fact that the destination ESI is advertised by both leaf1 and leaf2.

## Summary

In this tutorial we have seen how to configure EVPN Mutlihomin in a fabric where one CE is multihomed to two PEs. EVPN-based Multihoming is the current standard for connecting workloads to multiple leaves in the datacenter fabric. It provides all the benefits of the proprietary MC-LAG solutions, but with the added benefit of being standards-based and interoperable with other vendors.

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
