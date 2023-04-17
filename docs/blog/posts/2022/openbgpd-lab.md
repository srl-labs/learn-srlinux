---
date: 2022-11-11
tags:
  - ixp
  - openbgp
  - sr linux
  - bgp
authors:
  - rdodin
---

# Basic IXP Lab with OpenBGPd Route Server

Almost every Internet eXchange Point (IXP) leverages a Router Server (RS) to simplify peering between members of the exchange who exercise an open policy peering. A Route Server is a software component connected to the IXP network which acts as a BGP speaker with whom members peer to receive BGP updates from each other.

Nowadays, IXPs predominantly use [BIRD][bird] routing daemon as a Route Server, but for diversity and sustainability reasons [Route Server Support Foundation][rssf] initiated a program to introduce other software solutions, like [OpenBGPd][openbgpd], to the IXP market.

While OpenBGPd is not a new kid on the block of software BGP implementations, it is less known in the IXP domain (compared to BIRD). Lots of IXPs are interested in introducing OpenBGPd as a second Route Server in their networks and this lab opens the doors to explore "OpenBGPd as a Route Server" use case.

<!-- more -->

## Lab summary

This blog posts is based on a lab example that builds a simple IXP network with a route server and two IXP members.

| Summary                   |                                                                                                                                         |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| **Lab name**              | Basic IXP Lab with OpenBGPd Route Server                                                                                                |
| **Lab components**        | Nokia SR Linux, Arista cEOS and OpenBGPd nodes                                                                                          |
| **Resource requirements** | :fontawesome-solid-microchip: 2 vCPU <br/>:fontawesome-solid-memory: 6 GB                                                               |
| **Lab**                   | [hellt/obgpd-lab][lab]                                                                                                                  |
| **Version information**   | [`containerlab:0.32.4`][clab-install], [`srlinux:22.6.4`][srl-container], [`cEOS:4.28.0F`][get-ceos], [`openbgpd:7.7`][obgpd-container] |
| **Authors**               | Roman Dodin [:material-twitter:][rd-twitter] [:material-linkedin:][rd-linkedin]                                                         |

## Prerequisites

The lab leverages the [Containerlab][containerlab] project to spin up a topology of network elements and couple it with containerized software such as openbgpd. A [one-click][clab-install] installation gets containerlab installed on any Linux system.

```bash title="Containerlab installation via installation-script"
bash -c "$(curl -sL https://get.containerlab.dev)"
```

Since containerlab uses containers as the nodes of a lab, Docker engine has to be [installed][docker-install] on the host system.

## Lab topology

The goal of this lab is to give users a hands-on experience with OpenBGPd by providing a lab that mimics a trivialized IXP setup with two members exchanging their routers via a Route Server.

![phy topo](https://gitlab.com/rdodin/pics/-/wikis/uploads/aa830e6e6c76e8eb33423d3947774c66/image.png)

The setup consists of two routers - Nokia SR Linux and Arista EOS - acting as members connected to a common IXP LAN where a Route Server (OpenBGPd) is present.

Members of the exchange establish the BGP peering sessions with a Route Server over a common LAN segment and announce their `/32` networks.

![bgp](https://gitlab.com/rdodin/pics/-/wikis/uploads/d4a6ae3b9c63171e0d30a93cc432a9d4/image.png)

The OpenBGPd-based Route Server is configured to announce the routes it receives to connected peers and thus enables a core Route Server functionality.

## Obtaining container images

This lab features three different products:

* Nokia SR Linux - IXP member role
* Arista EOS - IXP member role
* OpenBGPd - Route Server role

For containerlab to be able to start up the lab, the relevant container images need to be available.

| Image          | How to get it?                                                                                                                                                                                                                        |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nokia SR Linux | [Nokia SR Linux container image][srl-container] is freely available for anyone to use and can be pulled as easy as `docker pull ghcr.io/nokia/srlinux:22.6.4`                                                                         |
| Arista EOS     | Arista EOS containerized version is called cEOS and can be obtained by registering on Arista website and downloading an archive with container image. Follow the [instructions][get-ceos] provided on containerlab website to get it. |
| OpenBGPd       | OpenBGPd has a publicly available container pushed to a registry. Pull it with `docker pull quay.io/openbgpd/openbgpd:7.7`                                                                                                            |

## Containerlab toplogy file

Courtesy of [containerlab][containerlab], the whole lab topology is captured in a declarative fashion via the [`obgpd.clab.yml`][topofile] file.

Let's cover the key components of the topology.

!!!tip
    Consult with [containerlab](https://containerlab.dev/manual/topo-def-file/) documentation to learn more about containerlab topology syntax.

### Defining members of the IXP

Let's start first by looking at the way we define the members of the IXP:

```yaml title="Defining SR Linux and cEOS nodes"
topology:
  nodes:
    # -- snip --
    srlinux: #(1)!
      kind: nokia_srlinux
      image: ghcr.io/nokia/srlinux:22.6.4
      startup-config: srlinux.cfg

    ceos:
      kind: arista_ceos
      image: ceos:4.28.0F #(2)!
      startup-config: ceos.cfg
```

1. This is a node `name`. It can be any string. For simplicity, we name Nokia SR Linux node `srlinux`, and Arista EOS node as `ceos`.
2. Make sure that you [download and import][get-ceos] cEOS image before starting the lab.

Our two IXP members named in the topology file `srlinux` and `ceos` accordingly are defined using the respective [kinds](https://containerlab.dev/manual/kinds/) `nokia_srlinux` and `arista_ceos`. Kinds make containerlab aware of particularities each Network OS has in terms of boot procedures and supported features.

To make our member nodes come up with their interfaces and protocols configured as per the lab topology design, we utilize containerlab's [startup-config](https://containerlab.dev/manual/nodes/#startup-config) feature. It allows us to provide a configuration file for both nodes that gets applied right after the nodes finish booting.

!!! note
    The startup configuration files for [Nokia SR Linux][srl-startup] and [Arista EOS][ceos-startup] contain CLI commands that move the system to a state where BGP peering with the Route Server is fully configured.

    If you want to configure the systems from the ground up, remove the `startup-config` block from the topology file and the nodes will boot with the default configuration.

Now to the Route Server. Containerlab allows users to combine regular containers with Network OS nodes. These regular containers are identified with the `linux` kind in the topology, and this is exactly how we define the OpenBGPd node:

```yaml title="Defining a Route Server node"
topology:
  nodes:
  # -- snip --
    openbgpd:
      kind: linux
      image: quay.io/openbgpd/openbgpd:7.7 #(1)!
      binds:
        - openbgpd.conf:/etc/bgpd/bgpd.conf
      exec:
        - "ip address add dev eth1 192.168.0.3/24"
```

1. OpenBGPd team maintains a [public container image][obgpd-container] which we can use right away in the topology file.

To provide OpenBGPd with a configuration file we leverage the [`binds`](https://containerlab.dev/manual/nodes/#binds) property that works exactly like bind mount in Docker.  
You specify a source file path[^1] and the corresponding path inside the container process. For `openbgpd` node we take the [`openbgpd.conf`][obgpd-startup] file and mount it inside the container by the `/etc/bgpd/bgpd.conf` path. This will make OpenBGPd to read this config when the process starts.

One last step left for the `openbgpd` node: to configure the `eth1` interface that connects the Route Server to the IXP LAN. Links setup is covered in details in the next chapter, but, for now, just keep in mind that we can configure interfaces of a container using the [`exec` option](https://containerlab.dev/manual/nodes/#exec) and `ip` utility.

This is what we have defined so far:

<center markdown>![logical1](https://gitlab.com/rdodin/pics/-/wikis/uploads/55af4a0c785b40edc6faf0946deb7d1a/image.png){.img-shadow width=80%}</p>
</small>Logical view of the topology with IXP members defined</small></center>

We have one last piece missing, and that is an IXP LAN network to which all our members should be connected.

### IXP LAN

To keep things simple, in this lab the IXP's underlay network is just an abstract L2 network as we don't want to get into the weeds of IXP network implementation[^2]. And what provides the most trivial Layer 2 segment on a Linux system? Yes, a Linux bridge.  
If we have a bridge, we can connect our members and a Route Server to it, thus providing the needed L2 connectivity between all parties.

First, let's create a bridge interface named `ixp` on a Linux host:

```bash
ip link add name ixp type bridge && ip link set dev ixp up
```

In containerlab, a special node of `kind: bridge` must be part of a topology so that other elements of the lab can be connected to it.

```yaml title="Defining a bridge in the topo file"
topology:
  nodes:
    # --snip--
    ixp:
      kind: bridge
```

!!!note
    Node name for the bridge needs to match the name of the bridge interface you created on your host. It is `ixp` in our case.

#### Adding links

And we get to the final part which is defining the links between the nodes of our lab.

Following the topology design, our task is to connect every node of our lab to the IXP LAN, which is a bridge network we created a moment ago. To achieve that, we create the [`links`][clab-links] section in our topology file where we wire-up all the elements together:

```yaml title="Defining links"
topology:
  # --snip--
  links:
    - endpoints: ["srlinux:e1-1", "ixp:srl1"]
    - endpoints: ["ceos:eth1", "ixp:ceos1"]
    - endpoints: ["openbgpd:eth1", "ixp:obgp1"]
```

This block instructs containerlab to create veth paris between the defined endpoints. For example, `endpoints: ["srlinux:e1-1", "ixp:srl1"]` tells containerlab to create a veth pair between the nodes `srlinux` and `ixp`, where `ixp` is a Linux bridge. Containerlab will place the veth pair into the relevant namespaces and will name veth interface endpoints according to the names provided by the user in this string array.

```text title="A wire between srlinux and IXP bridge"
       srlinux                      ixp bridge
  ┌───────────────┐             ┌───────────────┐
  │               │             │               │
  │               │             │               │
  │        ┌─────┬┤             ├┬───────┐      │
  │        │ e1-1│┼─────────────┼│ srl1  │      │
  │        └─────┴┤             ├┴───────┘      │
  │               │             │               │
  └───────────────┘             └───────────────┘
```

!!!note
    The interface name specified for the bridge-side is placed in the hosts network namespace and has no special meaning.

    Read more on [how links are modelled][clab-links] if you want to know all the details or get an additional explanation.

With all the links defined, our lab logical view becomes complete!

<center markdown>![logical1](https://gitlab.com/rdodin/pics/-/wikis/uploads/d4776acfc2b23cc506a8bbd44124bc8e/image.png){.img-shadow width=80%}</p>
</small>Logical view of the topology with IXP members and links defined</small></center>

## Lab deployment

At this point everything is ready for the lab to be deployed:

1. Container images are pulled
2. Linux bridge named `ixp` is created

First, clone the lab:

```bash
git clone https://github.com/hellt/openbgpd-lab.git && cd openbgpd-lab
```

And deploy!

```bash
containerlab deploy
```

At the end of the deployment process, which should take around 30 seconds, you will be greeted by the summary table with details about deployed nodes:

```text
INFO[0000] Containerlab v0.32.4 started
--snip--
INFO[0036] Adding containerlab host entries to /etc/hosts file 
+---+---------------------+--------------+-------------------------------+-------------+---------+----------------+----------------------+
| # |        Name         | Container ID |             Image             |    Kind     |  State  |  IPv4 Address  |     IPv6 Address     |
+---+---------------------+--------------+-------------------------------+-------------+---------+----------------+----------------------+
| 1 | clab-obgpd-ceos     | b102810a4e9a | ceos:4.28.0F                  | arista_ceos | running | 172.20.20.2/24 | 2001:172:20:20::2/64 |
| 2 | clab-obgpd-openbgpd | ad3724a00562 | quay.io/openbgpd/openbgpd:7.7 | linux       | running | 172.20.20.3/24 | 2001:172:20:20::3/64 |
| 3 | clab-obgpd-srlinux  | 2ece012bc12e | ghcr.io/nokia/srlinux:22.6.4  | srl         | running | 172.20.20.4/24 | 2001:172:20:20::4/64 |
+---+---------------------+--------------+-------------------------------+-------------+---------+----------------+----------------------+
```

!!!tip "Pro tip"
    Use `clab` instead of `containerlab` to save on typing.

## Connecting to the nodes

When the lab is deployed, you can connect to every node and configure and verify the lab' status and protocols operation. For nodes that run SSH server, you can connect with SSH client using the names provided in the summary table:

```bash
ssh admin@clab-obgpd-srlinux #(1)!
```

1. Default credentials for both SR Linux and cEOS are `admin:admin`
    You can use containerlab-assigned IP addresses from the summary table as well.

???question "What makes a node name?"
    Each node name by default consists of three parts:

    1. fixed `clab` prefix
    2. lab name as set in the topology file; `obgpd` in our case
    3. node name as set in the topology file; `srlinux` as per the example above.

To connect to the OpenBGPd container that doesn't have SSH server use `docker` CLI and execute a shell process:

```c
❯ docker exec -it clab-obgpd-openbgpd ash //(1)!
/ # bgpctl // (2)!
missing argument:
valid commands/args:
  reload
  show
  fib
  neighbor
  network
  log
```

1. `ash` is the alpine shell used in openbgpd container image
2. `bgpctl` is a CLI interface to interact with OpenBGPd

## Configuration

With the lab deployed and connection methods sorted out, we can move on to the meat of it - checking the basic configuration we embedded into this lab.

### OpenBGPd

OpenBGPd config is provided in a [`openbgpd.conf`][obgpd-startup] file that we bind mounted to the container. Let's have a quick look at what this config has inside:

```bash
# example config for a test lab, DO NOT USE FOR PRODUCTION

# global configuration
AS 65003
router-id 10.0.0.3

# do not add our own AS (a route server behavior) in ASPATH
transparent-as yes

group "route-server-clients" {
 # IPv4 Peering LAN
 neighbor 192.168.0.0/24
}

# in a lab we can allow ourselves to not do any filtering
allow to ebgp
allow from ebgp

# set's these communities to identify from where RS learned a route
match from any set large-community local-as:0:neighbor-as
```

As the comments indicate, this is a trivialized configuration that automatically peers with any BGP speaker available in the `192.168.0.0/24` network. There is no filtering configured, and every received BGP route is sent to all peers.  
When `openbgpd` container starts, it reads this file automatically, since we mounted it by the well-known path. As a result of that, the peerings will be automatically set up with our two members running SR Linux and cEOS.

Do you remember that `exec` statement, that we have in our topology file?

```yaml
topology:
  nodes:
    # -- snip --
    openbgpd:
      # -- snip --
      exec:
        - "ip address add dev eth1 192.168.0.3/24"
  
  # --snip--
  links:
    # --snip--
    - endpoints: ["openbgpd:eth1", "ixp:obgp1"]
```

Within the `exec` block, we configured the IP address on the `eth1` interface of the `openbgpd` node, as we added that link connecting the route server to the IXP bridge.

### Nokia SR Linux

Similarly, a [startup configuration file][srl-startup] has been provided for SR Linux node.

=== "Interfaces configuration"
    First we configure the interfaces. Interface `ethernet-1/1` connects our router to the IXP bridge, and therefore is addressed with the `192.168.0.1` address.  
    We also add the loopback `lo0` interface that is addressed `10.0.0.1/32` and simulates the network this router will announce towards the route server.
    ```bash
    interface ethernet-1/1 {
        admin-state enable
        subinterface 0 {
            admin-state enable
            ipv4 {
                address 192.168.0.1/24 {
                }
            }
        }
    }

    interface lo0 {
        admin-state enable
        subinterface 0 {
            admin-state enable
            ipv4 {
                address 10.0.0.1/32 {
                }
            }
        }
    }
    ```
=== "Routing policy"
    A routing policy is required to fine tune which routes can be imported/exported by SR Linux. In this policy we leverage the `prefix-set` that includes our loopback address.
    ```bash
    routing-policy {
        prefix-set loopback {
            prefix 10.0.0.0/24 mask-length-range 24..32 {
            }
        }
        policy loopbacks {
            default-action {
                reject {
                }
            }
            statement 10 {
                match {
                    prefix-set loopback
                }
                action {
                    accept {
                    }
                }
            }
        }
    }
    ```
=== "Network instance and BGP"
    Lastly, we attach configured interfaces to the default network instance and configure BGP peering with the route server.
    ```bash
    network-instance default {
        interface ethernet-1/1.0 {
        }
        interface lo0.0 {
        }
        protocols {
            bgp {
                admin-state enable
                autonomous-system 65001
                router-id 10.0.0.1
                group rs {
                    export-policy loopbacks
                    import-policy loopbacks
                    peer-as 65003
                    ipv4-unicast {
                        admin-state enable
                    }
                    timers {
                        connect-retry 1
                        hold-time 9
                        keepalive-interval 3
                        minimum-advertisement-interval 1
                    }
                }
                neighbor 192.168.0.3 {
                    peer-group rs
                }
            }
        }
    }
    ```

### Arista EOS

Arista EOS is configured in the same spirit, and its configuration is contained within [`ceos.cfg`][ceos-startup] file.

## Verification

Because we used startup configuration files for all of the components of our lab, the peerings will automatically set up once the nodes finish their boot procedures.

### OpenBGPd

On `openbgpd` side we can monitor the logs of the daemon right after we enter the `clab deploy` command:

```bash
docker logs -f clab-obgpd-openbgpd
```

Watching the log file will show to us when the `openbgpd` starts to receives messages from the peers reaching out to it:

```
--snip--
RTR engine reconfigured
RDE reconfigured
running softreconfig in
softreconfig in done
RDE soft reconfiguration done
neighbor 192.168.0.2: state change None -> Idle, reason: None
neighbor 192.168.0.2: state change Idle -> Connect, reason: Start
neighbor 192.168.0.2: state change Connect -> OpenSent, reason: Connection opened
neighbor 192.168.0.2: state change OpenSent -> OpenConfirm, reason: OPEN message received
neighbor 192.168.0.2: state change OpenConfirm -> Established, reason: KEEPALIVE message received
neighbor 192.168.0.2: sending IPv4 unicast EOR marker
neighbor 192.168.0.2: received IPv4 unicast EOR marker
nexthop 192.168.0.2 now valid: directly connected: via 192.168.0.2
nexthop 192.168.0.2 update starting
nexthop 192.168.0.2 update finished
neighbor 192.168.0.1: state change None -> Idle, reason: None
neighbor 192.168.0.1: state change Idle -> Connect, reason: Start
neighbor 192.168.0.1: state change Connect -> OpenSent, reason: Connection opened
neighbor 192.168.0.1: state change OpenSent -> OpenConfirm, reason: OPEN message received
neighbor 192.168.0.1: state change OpenConfirm -> Established, reason: KEEPALIVE message received
neighbor 192.168.0.1: sending IPv4 unicast EOR marker
neighbor 192.168.0.1: received IPv4 unicast EOR marker
nexthop 192.168.0.1 now valid: directly connected: via 192.168.0.1
nexthop 192.168.0.1 update starting
nexthop 192.168.0.1 update finished
```

As the log shows, `openbgpd` established two BGP sessions with our two IXP members and exchanged records. We can have a deeper look at the RIB and neighbor status[^3] by [connecting](#connecting-to-the-nodes) to this node and using `bgpctl` CLI:

=== "RIB IN"
    When checking the BGP peerings it is useful to peek into the BGP RIB IN database to see which routes were received by the `openbgpd`.
    ```
    / # bgpctl show rib in detail

    BGP routing table entry for 10.0.0.1/32
        65001
        Nexthop 192.168.0.1 (via 192.168.0.1) Neighbor 192.168.0.1 (10.0.0.1)
        Origin IGP, metric 0, localpref 100, weight 0, ovs not-found, external
        Last update: 00:04:31 ago

    BGP routing table entry for 10.0.0.2/32
        65002
        Nexthop 192.168.0.2 (via 192.168.0.2) Neighbor 192.168.0.2 (10.0.0.2)
        Origin IGP, metric 0, localpref 100, weight 0, ovs not-found, external
        Last update: 00:04:48 ago
    ```
    All checks out here, we got a loobpack from each of our IXP members.
=== "RIB"
    We can have a look at the OpenBGPd's RIB table then to see which routes were accepted:
    ```
    / # bgpctl show rib
    flags: * = Valid, > = Selected, I = via IBGP, A = Announced,
          S = Stale, E = Error
    origin validation state: N = not-found, V = valid, ! = invalid
    origin: i = IGP, e = EGP, ? = Incomplete

    flags ovs destination          gateway          lpref   med aspath origin
    *>      N 10.0.0.1/32          192.168.0.1       100     0 65001 i
    *>      N 10.0.0.2/32          192.168.0.2       100     0 65002 i
    ```
    To our luck both routes were selected and used in the RIB.
=== "RIB OUT"
    Finally, we can make sure that the routes from our local RIB are sent out to the memebers of our exchange:
    ```
    / # bgpctl show rib out
    flags: * = Valid, > = Selected, I = via IBGP, A = Announced,
          S = Stale, E = Error
    origin validation state: N = not-found, V = valid, ! = invalid
    origin: i = IGP, e = EGP, ? = Incomplete

    flags ovs destination          gateway          lpref   med aspath origin
    *       N 10.0.0.2/32          192.168.0.2       100     0 65002 i
    *       N 10.0.0.1/32          192.168.0.1       100     0 65001 i
    ```
    Nice, the routes were selected to be in RIB OUT database, and therefore they will be sent out to the respective peers.
=== "Neighbor status"
    To check the status of the BGP neighbors use `bgpctl show neighbor` command. The output is quite lengthy, so we won't paste it here.

### SR Linux

On the SR Linux side we have an extensive list of state information related to BGP. Connect to the node using `ssh admin@clab-obgpd-srlinux` and try out these commands.

=== "Neighbor status"
    ```
    --{ running }--[  ]--
    A:srlinux# show network-instance default protocols bgp neighbor  
    -----------------------------------------------------------------------------------------------------------------------
    BGP neighbor summary for network-instance "default"
    Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
    -----------------------------------------------------------------------------------------------------------------------
    -----------------------------------------------------------------------------------------------------------------------
    +-------------+-------------------+-------------+-----+-------+-----------+-----------+----------+-------------------+
    |  Net-Inst   |       Peer        |    Group    | Fla | Peer- |   State   |  Uptime   | AFI/SAFI |  [Rx/Active/Tx]   |
    |             |                   |             | gs  |  AS   |           |           |          |                   |
    +=============+===================+=============+=====+=======+===========+===========+==========+===================+
    | default     | 192.168.0.3       | rs          | S   | 65003 | establish | 0d:0h:14m | ipv4-uni | [1/1/1]           |
    |             |                   |             |     |       | ed        | :1s       | cast     |                   |
    +-------------+-------------------+-------------+-----+-------+-----------+-----------+----------+-------------------+
    -----------------------------------------------------------------------------------------------------------------------
    Summary:
    1 configured neighbors, 1 configured sessions are established,0 disabled peers
    0 dynamic peers
    ```
=== "Received BGP routes"
    To list the routes received from a given BGP peer:
    ```
    --{ running }--[  ]--
    A:srlinux# show network-instance default protocols bgp neighbor 192.168.0.3 received-routes ipv4
    -----------------------------------------------------------------------------------------------------------------------
    Peer        : 192.168.0.3, remote AS: 65003, local AS: 65001
    Type        : static
    Description : None
    Group       : rs
    -----------------------------------------------------------------------------------------------------------------------
    Status codes: u=used, *=valid, >=best, x=stale
    Origin codes: i=IGP, e=EGP, ?=incomplete
    +-------------------------------------------------------------------------------------------------------------------+
    | Stat       Network          Next Hop          MED        LocPref                 AsPath                  Origin   |
    |  us                                                                                                               |
    +===================================================================================================================+
    | u*>    10.0.0.2/32       192.168.0.2           -           100       [65002]                                i     |
    +-------------------------------------------------------------------------------------------------------------------+
    -----------------------------------------------------------------------------------------------------------------------
    1 received BGP routes : 1 used 1 valid
    -----------------------------------------------------------------------------------------------------------------------
    ```
=== "Advertised routes"
    Equally important to see which routes were qualified to be sent out:
    ```
    --{ running }--[  ]--
    A:srlinux# show network-instance default protocols bgp neighbor 192.168.0.3 advertised-routes ipv4
    -----------------------------------------------------------------------------------------------------------------------
    Peer        : 192.168.0.3, remote AS: 65003, local AS: 65001
    Type        : static
    Description : None
    Group       : rs
    -----------------------------------------------------------------------------------------------------------------------
    Origin codes: i=IGP, e=EGP, ?=incomplete
    +-------------------------------------------------------------------------------------------------------------------+
    |        Network             Next Hop          MED        LocPref                  AsPath                  Origin   |
    +===================================================================================================================+
    | 10.0.0.1/32             192.168.0.1           -           100       [65001]                                 i     |
    +-------------------------------------------------------------------------------------------------------------------+
    -----------------------------------------------------------------------------------------------------------------------
    1 advertised BGP routes
    -----------------------------------------------------------------------------------------------------------------------
    ```
=== "BGP RIB"
    We can check which routes were populated in the BGP RIB. There we can see our route from the other IXP member "reflected" by the route server to us.
    ```
    --{ running }--[  ]--
    A:srlinux# show network-instance default protocols bgp routes ipv4 summary  
    -----------------------------------------------------------------------------------------------------------------------
    Show report for the BGP route table of network-instance "default"
    -----------------------------------------------------------------------------------------------------------------------
    Status codes: u=used, *=valid, >=best, x=stale
    Origin codes: i=IGP, e=EGP, ?=incomplete
    -----------------------------------------------------------------------------------------------------------------------
    +-----+-------------+-------------------+-----+-----+-------------------------------------+
    | Sta |   Network   |     Next Hop      | MED | Loc |              Path Val               |
    | tus |             |                   |     | Pre |                                     |
    |     |             |                   |     |  f  |                                     |
    +=====+=============+===================+=====+=====+=====================================+
    | u*> | 10.0.0.1/32 | 0.0.0.0           | -   | 100 |  i                                  |
    | u*> | 10.0.0.2/32 | 192.168.0.2       | -   | 100 | [65002] i                           |
    | u*> | 192.168.0.0 | 0.0.0.0           | -   | 100 |  i                                  |
    |     | /24         |                   |     |     |                                     |
    +-----+-------------+-------------------+-----+-----+-------------------------------------+
    -----------------------------------------------------------------------------------------------------------------------
    3 received BGP routes: 3 used, 3 valid, 0 stale
    3 available destinations: 0 with ECMP multipaths
    -----------------------------------------------------------------------------------------------------------------------
    ```
=== "Detailed route information"
    When in need to look which communities were attached to the route, use a zoomed view on a received BGP prefix.

    ```
    --{ running }--[  ]--
    A:srlinux# show network-instance default protocols bgp routes ipv4 prefix 10.0.0.2/32 
    -----------------------------------------------------------------------------------------------------------------------
    Show report for the BGP routes to network "10.0.0.2/32" network-instance  "default"
    -----------------------------------------------------------------------------------------------------------------------
    Network: 10.0.0.2/32
    Received Paths: 1
      Path 1: <Best,Valid,Used,>
        Route source    : neighbor 192.168.0.3
        Route Preference: MED is -, LocalPref is 100
        BGP next-hop    : 192.168.0.2
        Path            :  i [65002]
        Communities     : 65003:0:65002
    Path 1 was advertised to: 
    [  ]
    -----------------------------------------------------------------------------------------------------------------------
    ```

There are many more commands that can be of use, feel free to explore them or ask in the comments.

### Arista EOS

On EOS side we can verify that we have the prefix from SR Linux received in good order:

```
ceos#sh ip bgp summ
BGP summary information for VRF default
Router identifier 10.0.0.2, local AS number 65002
Neighbor Status Codes: m - Under maintenance
  Neighbor    V AS           MsgRcvd   MsgSent  InQ OutQ  Up/Down State   PfxRcd PfxAcc
  192.168.0.3 4 65003             64        78    0    0 00:30:38 Estab   0      0
```

### Datapath

It will all be for nothing if the exchanged networks weren't able to talk one to another. We can check this by issuing a ping from either IXP member, targeting the advertised network. Let's do this on SR Linux:

```bash
--{ running }--[  ]--
A:srlinux# ping network-instance default 10.0.0.2 -I 192.168.0.1 #(1)!
Using network instance default
PING 10.0.0.2 (10.0.0.2) from 192.168.0.1 : 56(84) bytes of data.
64 bytes from 10.0.0.2: icmp_seq=1 ttl=64 time=5.75 ms
64 bytes from 10.0.0.2: icmp_seq=2 ttl=64 time=3.38 ms
64 bytes from 10.0.0.2: icmp_seq=3 ttl=64 time=2.32 ms
^C
--- 10.0.0.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2003ms
rtt min/avg/max/mdev = 2.319/3.816/5.754/1.438 ms
```

1. We have to specify the outgoing IP address to be from the IXP network, otherwise, the connected loopback would be used as a source.

Great, it works! We have built a lab simulating a simple IXP setup where members exchange their routes via Route Server in an open-policy fashion. We followed the control plane operations where BGP peerings were established between each memeber and a route server. And finally, we verified that the datapath has been programmed in accordance to the control plane instructions, and the datapath works between the networks of the respective members.

## Lab lifecycle

Not a single lab is perfect on the first try. Thus, you will often find yourself in need to make changes to the configuration, topology and design. Containerlab strives to give you the best possible user experience in managing your lab and is equipped with a handful set of commands.

Once you made some changes to the topology or attached configurations you can redeploy your lab by first removing the running and deploying it again. This sounds like a lot of moves, but `clab dep -c` (short for `containerlab deploy --reconfigure`) shortcut is all you need to achieve that.

When you need to just remove the lab from your host without re-spinning it up, use `clab des -c` (short for `containerlab destroy --cleanup`) and everything will be gone like it never was there.

!!!note
    The bridge is not removed by containerlab when you destroy the lab. You have to remove it manually if needed.

To remind yourself if you have any labs running and which nodes are there, use `clab ins -a` (short for `containerlab inspect --all`).

These commands will quickly get into your muscle memory and you will feel like you've never been so fast in running labs!

## What next?

This lab was designed to be a trivial IXP setup. It lays a foundation on which you can build way more elaborated use cases:

1. Introduce proper Route Server configuration with route filtering according to [MANRS](https://www.manrs.org/). Maybe utilise [ARouteServer](https://github.com/pierky/arouteserver) project to test route server config automation.
2. Swap bridge-based IXP network with a real emulated network running VPLS or EVPN-VXLAN and try to build the best IXP network setup.
3. Get into the deep woods of MAC filtering, route suppression or BUM optimization.
4. Try out peering automation scenarios using IXP manager or home-grown scripts.

As you can see, there are dozens of complex scenarios that may be added to this lab that serves as an entrypoint to the world of IXP use cases. We would like to hear from you about what you want us to build next in the comments, chao!

## Additional info

* [Containerlab project][containerlab]
* [OpenBGP home page][openbgpd]
* [OpenBGPd How To](https://dn42.eu/howto/OpenBGPD)
* [RIPE: Adding diversity to the route server landscape](https://labs.ripe.net/author/claudio_jeker/openbgpd-adding-diversity-to-the-route-server-landscape/)

[lab]: https://github.com/hellt/openbgpd-lab
[bird]: https://bird.network.cz/
[rssf]: https://www.rssf.nl/
[openbgpd]: http://openbgpd.org/
[containerlab]: https://containerlab.dev
[clab-install]: https://containerlab.dev/install/#install-script
[docker-install]: https://docs.docker.com/engine/install/
[srl-container]: https://github.com/nokia/srlinux-container-image
[get-ceos]: https://containerlab.dev/manual/kinds/ceos/#getting-ceos-image
[obgpd-container]: https://github.com/openbgpd-portable/openbgpd-container
[rd-linkedin]: https://linkedin.com/in/rdodin
[rd-twitter]: https://twitter.com/ntdvps
[topofile]: https://github.com/hellt/openbgpd-lab/blob/main/obgpd.clab.yml
[srl-startup]: https://github.com/hellt/openbgpd-lab/blob/main/srlinux.cfg
[ceos-startup]: https://github.com/hellt/openbgpd-lab/blob/main/ceos.cfg
[obgpd-startup]: https://github.com/hellt/openbgpd-lab/blob/main/openbgpd.conf
[clab-links]: https://containerlab.dev/manual/topo-def-file/#links

[^1]: Paths are relative to the topology file.
[^2]: This is planned as an advanced IXP lab, stay tuned!
[^3]: Check OpenBGP documentation to see what other commands might be useful for your use case.
