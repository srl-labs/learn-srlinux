---
date: 2024-07-30
tags:
    - mirroring
authors:
    - tweber
    - rdodin
---

# Mirroring in SR Linux

Once in a while you need to take a closer look at the traffic that flows through your network. Be it for troubleshooting, monitoring, or security reasons, you need to be able to capture and analyze the packets.

Doing the packet capture in a virtual lab is a breeze - pick your favorite traffic dumping tool and point it to the virtual interface associated with your data port. But when you need to do the same in a physical network, things get a bit more complicated. Packets that are not destined to the management interface of your device are not visible to the CPU, and hence you can't capture it directly.

That is where the mirroring feature comes in. It allows you to copy the packets from a source interface to a mirror destination, where you would run your packet capture tool. By leveraging the ASIC capabilities, the mirroring feature is hardware-dependent, but luckily, SR Linux container image is built with mirroring support, so we can build a lab and play with mirroring in a close-to-real-world environment.

<!-- more -->

|                             |                                                                                                                     |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| **Lab components**          | 3 SR Linux nodes, 2 Alpine Linux clients and 2 Alpine Linux mirror destination nodes                                |
| **Resource requirements**   | :fontawesome-solid-microchip: 2vCPU <br/>:fontawesome-solid-memory: 8 GB                                            |
| **Lab Repo**                | [srl-mirroring-lab][lab-repo]                                                                                       |
| **Packet captures**         | [EVPN IP Prefix routes exchange][capture]                                                                           |
| **Main ref documents**      | [OAM and Diagnostics Guide][mirror-docs]                     |
| **Version information**[^1] | [`containerlab:v0.56.0`][clab-install], [`srlinux:24.7.1`][srlinux-container], [`docker-ce:26.1.4`][docker-install] |

We created [a lab][lab-repo] to make this blog post interactive and let you play with mirroring configuration at your own pace. Anyone can deploy this lab on any Linux system with [containerlab][clab-install] or run for free in the cloud with [Codespaces](../../../blog/posts/2024/codespaces.md):

/// tab | Locally

To deploy the lab locally, enter in the directory where you want to store the lab directory and run one single command:

```
sudo containerlab deploy -c -t srl-labs/srl-mirroring-lab
```

Containerlab will pull the git repo to your current working directory and start deploying the lab.
///
/// tab | With Codespaces

If you want to run the lab in a free cloud instance, click the button below to open the lab in GitHub Codespaces:

<div align=center markdown>
<a href="https://codespaces.new/srl-labs/srl-mirroring-lab?quickstart=1">
<img src="https://gitlab.com/rdodin/pics/-/wikis/uploads/d78a6f9f6869b3ac3c286928dd52fa08/run_in_codespaces-v1.svg?sanitize=true" style="width:50%"/></a>

**[Run](https://codespaces.new/srl-labs/srl-mirroring-lab?quickstart=1) this lab in GitHub Codespaces for free**.  
[Learn more](https://containerlab.dev/manual/codespaces) about Containerlab for Codespaces.  
<small>Machine type: 2 vCPU · 8 GB RAM</small>
</div>
///

The lab topology represents a small DC Fabric with two leafs and a spine. The clients are connected to the leafs, and the two mirror destinations are connected to the `leaf1` and `spine1` accordingly.

<figure>
  <div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":0,"zoom":1,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-mirroring-lab/main/diagrams/diagrams.drawio"}'></div>
  <figcaption>Lab topology</figcaption>
</figure>

The lab comes up with the necessary configuration already applied to the leaf and spine switches. We run a [basic L2 EVPN service](../../../tutorials/l2evpn/intro.md) in the fabric with eBGP/iBGP combo powering the control plane.

<figure>
  <div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":1,"zoom":1,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-mirroring-lab/main/diagrams/diagrams.drawio"}'></div>
  <figcaption>EVPN service</figcaption>
</figure>

We will ping between the clients and see how the mirroring feature intercepts and mirrors the traffic to the mirror destination nodes.

## Mirror source and destination

There are two types of mirroring in SR Linux: local and remote.

The local mirroring is used when both a mirror source and a mirror destination are on the same device. The remote mirroring is used when the mirror source and the mirror destination are on different devices.

But what can be a mirror source and a mirror destination?  
The mirror source can be:

1. an SR Linux interface with all its subinterfaces
2. a subinterface of an SR Linux interface
3. a LAG interface with all its members

///admonition | Consult with the docs
    type: warning
Mirroring is a hardware dependent feature, check the [docs][mirror-docs] to see if your hardware supports it.
///

The mirror destination can be:

1. an SR Linux subinterface of type `local-mirror-dest` in case of local mirroring
2. tunnel endpoint identified by the source and destination IP address pair in case of remote mirroring

Let's see how these two types of mirroring work in practice.

## Local mirroring

Starting with a simple example of local mirroring, we will explore what it takes to configure the mirroring between the interfaces on the `leaf1` device.

As per our topology, we have a `mirror1` connected to the `leaf1` interface `ethernet-1/10`. Our goal is to configure the port mirroring from the `ethernet-1/1` interface of `leaf1` and mirror the packets over to a mirror destination subinterface that we attach tot the `ethernet-1/10` interface on the same switch.

Here is a diagram that explains the local mirroring setup:

<figure>
  <div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":2,"zoom":2   ,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-mirroring-lab/main/diagrams/diagrams.drawio"}'></div>
  <figcaption>Local mirroring</figcaption>
</figure>

The cyan dashed line showes the path of the mirrored packets from the source interface to the mirror destination (subinterface of `ethernet-1/10`). Let's see what does it take to configure the local mirroring.

### Mirror source

Our intention is to mirror all the packets traversing the `ethernet-1/1` interface on the `leaf1` switch. To do that, we can choose the whole `ethernet-1/1` interface as our mirror source.

Both mirror source and destination are provided in the context of a "mirroring instance". Here is how we created it with the mirror source on `leaf1`:

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-mirroring-lab/main/configs/leaf1.cfg:mirror-src"

commit now
```

Note, that we indicate the mirroring direction `ingress-egress`, denoting that we want to mirror both traffic incoming and outgoing from the `ethernet-1/1` interface.

### Mirror destination

As for the destination, we need to create a subinterface for the `ethernet-1/10` interface that is connected to our mirror destination. The subinterface must be of a specific type `local-mirror-dest`. Then we need to add that subinterface as a mirror destination for in the mirroring instance context created eaerlier.

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-mirroring-lab/main/configs/leaf1.cfg:mirror-dest"

commit now
```

And that's it, the local mirroring is now configured! But how do we know that it works? Let's see it in action.

### Verification

First, we can check that mirroring instance configuration and operational state by running the following command:

```srl hl_lines="6"
A:leaf1# info from state /system mirroring mirroring-instance 1
    system {
        mirroring {
            mirroring-instance 1 {
                admin-state enable
                oper-state up
                mirror-source {
                    interface ethernet-1/1 {
                        direction ingress-egress
                    }
                }
                mirror-destination {
                    local ethernet-1/10.0
                }
            }
        }
    }
```

The output should show that the mirroring instance is up and running, and the source and destination are correctly configured.

Now, let's run pings between the clients and see if the mirrored packets are indeed send to the mirror destination. First, start the ping from client1 to client2:

```bash
sudo docker exec client1 ping 172.17.0.2
```

This will start pings from client1 to client2, and while the pings are running, we can run a packet capture on the mirror destination node:

```bash
sudo docker exec -t -t mirror1 tcpdump -i eth1
```

In the tcpdump we should see the mirrored ICMP packets with the source and destination IP addresses of the clients.

```
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth1, link-type EN10MB (Ethernet), snapshot length 262144 bytes
11:56:49.678416 IP 172.17.0.1 > 172.17.0.2: ICMP echo request, id 18, seq 59, length 64
11:56:49.679344 IP 172.17.0.2 > 172.17.0.1: ICMP echo reply, id 18, seq 59, length 64
11:56:50.679164 IP 172.17.0.1 > 172.17.0.2: ICMP echo request, id 18, seq 60, length 64
11:56:50.679874 IP 172.17.0.2 > 172.17.0.1: ICMP echo reply, id 18, seq 60, length 64
```

Great, local mirroring works as expected and we can see the mirrored packets on the mirror destination node.

## Remote mirroring

The remote mirroring is a bit more complex as it involves two devices and a tunneling protocol to send the mirrored packets from the source to the destination. Essentially, we will build the following setup:

<figure>
  <div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":3,"zoom":2   ,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srl-mirroring-lab/main/diagrams/diagrams.drawio"}'></div>
  <figcaption>Remote mirroring</figcaption>
</figure>

The diagram might look busy, but once we get through the configuration, it will all make sense. Our goal is to mirror ICMP packets from the subinterface `ethernet-1/1.0` on the `leaf2` switch and deliver the mirrored packets to the `mirro2` destination node.

### Mirror source

To have some variety in the mirroring setup, we will show how an ACL rule can be used a mirror source. We will create an ACL filter rule (named `mirror-acl`) that will match on ICMP packets and associate this ACL rule with the `interface-1/1.0` subinterface on `leaf2`.

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-mirroring-lab/main/configs/leaf2.cfg:acl"

commit now
```

When the ACL filter created, proceed with the mirroring instance configuration.

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-mirroring-lab/main/configs/leaf2.cfg:mirror-src"

commit now
```

Note, that we need to specify the ACL filter entry in the mirror source configuration.

### Mirror destination

The mirror destination in the remote mirroring is a tunnel endpoint. The reason for that is that we need to tunnel the mirrored packets from the source to the destination, and that is what tunneling protocols are for.

```srl
enter candidate

--8<-- "https://raw.githubusercontent.com/srl-labs/srl-mirroring-lab/main/configs/leaf2.cfg:mirror-dest"

commit now
```

Let's dig into this configuration a bit more.

First, we specify the tunnel encapsulation type, which is L2-over-GRE in the case of the 7220 IXR-D2L/D3L switch that we are running in the lab.

Then we specify the tunnel source IP - `10.0.1.2` - and you might wonder where this IP comes from. This is the system0 (loopback) IP address that our `leaf2` switch uses as a VTEP. This IP is distributed via eBGP so that all leaf and spine switches know how to reach it. This IP is routable in our fabric' underlay.

Now, the tunnel destination IP - `192.168.1.10` - is the IP address of the `mirror2` node, which is configured on its `eth1` interface. How does `leaf2` know how to route to this IP? Well, the `192.168.1.0/24` network is advertised by the `spine1` switch, since it has the `ethernet-1/10.0` subinterface configured with the `192.168.1.1/24` IP address.

We can ensure that `leaf2` knows how to reach the remote tunnel destination by checking the underlay routing table:

```srl
A:leaf2# show network-instance default route-table ipv4-unicast route 192.168.1.10
-----------------------------------------------------------------------------------------------------------------------------------------------------------------
IPv4 unicast route table of network instance default
-----------------------------------------------------------------------------------------------------------------------------------------------------------------
+------------------+------+-----------+--------------------+---------+---------+--------+-----------+------------+------------+------------+---------------+
|      Prefix      |  ID  |   Route   |    Route Owner     | Active  | Origin  | Metric |   Pref    |  Next-hop  |  Next-hop  |   Backup   | Backup Next-  |
|                  |      |   Type    |                    |         | Network |        |           |   (Type)   | Interface  |  Next-hop  | hop Interface |
|                  |      |           |                    |         | Instanc |        |           |            |            |   (Type)   |               |
|                  |      |           |                    |         |    e    |        |           |            |            |            |               |
+==================+======+===========+====================+=========+=========+========+===========+============+============+============+===============+
| 192.168.1.0/24   | 0    | bgp       | bgp_mgr            | True    | default | 0      | 170       | 100.64.2.0 | ethernet-  |            |               |
|                  |      |           |                    |         |         |        |           | /31 (indir | 1/50.0     |            |               |
|                  |      |           |                    |         |         |        |           | ect/local) |            |            |               |
+------------------+------+-----------+--------------------+---------+---------+--------+-----------+------------+------------+------------+---------------+
```

/// note | Mirroring using underlay
It is worth noting that the mirroring is done in the underlay network, and the mirrored packets are not encapsulated in the overlay VXLAN. Instead, the L2oGRE (or L3oGRE on some platforms) is used to deliver the mirrored packets to the destination.
///

### Verification

We can run the same ping betweem the clients and see if `mirror2` receives the mirrored packets.

```
sudo docker exec -t -t mirror2 tcpdump -i eth1
```

This time around we will not see the raw ICMP packets, but rather the GREv0 encapsulated packets that carry the mirrored traffic.

```
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth1, link-type EN10MB (Ethernet), snapshot length 262144 bytes
12:39:02.286873 IP 10.0.1.2 > 192.168.1.10: GREv0, length 102: IP 172.17.0.2 > 172.17.0.1: ICMP echo reply, id 18, seq 2569, length 64
12:39:03.287869 IP 10.0.1.2 > 192.168.1.10: GREv0, length 102: IP 172.17.0.2 > 172.17.0.1: ICMP echo reply, id 18, seq 2570, length 64
```

The GRE encapsulated packets are sent from the `leaf2` switch to the `mirror2` node, where they are captured by the tcpdump.

## Statistics

SR Linux keeps tabs on the mirrored packets which you can see with any management interface, for example with CLI.

On 7220 IXR-D2/D3 platforms, you can display the statistics per mirror destination interface using the `info from state interface * statistics` command.

In case of `leaf2` switch the statistics can be seen on `ethernet-1/50` interface, since this is the interface used to send mirrored traffic to its destination.

```srl
A:leaf2# info from state interface ethernet-1/50 statistics | filter fields out-mirror-octets out-mirror-packets | as table
+---------------------+----------------------+----------------------+
|      Interface      |  Out-mirror-octets   |  Out-mirror-packets  |
+=====================+======================+======================+
| ethernet-1/50       |               400112 |                 2942 |
+---------------------+----------------------+----------------------+
```

## Summary

Mirroring is a powerful feature that allows you to capture and analyze the traffic that flows through your network. It is a hardware-dependent feature, so some nuances might be present depending on the platform you are using.

In this blog post, we showed how to configure both local and remote mirroring in SR Linux. We used a simple lab topology to demonstrate the mirroring feature in action and showed how to verify the configuration. We hope this blog post will help you to get started with mirroring configuration in your network.

[lab-repo]: https://github.com/srl-labs/srl-mirroring-lab
[capture]: https://github.com/srl-labs/srl-mirroring-lab/raw/main/remote-mirror-gre.pcapng
[clab-install]: https://containerlab.dev/install/
[srlinux-container]: https://github.com/orgs/nokia/packages/container/package/srlinux
[docker-install]: https://docs.docker.com/engine/install/
[mirror-docs]: https://documentation.nokia.com/srlinux/24-7/books/oam/mirror.html
[^1]: these versions were used to create this tutorial. The newer versions might work, but if they don't, please pin the version to the mentioned ones.

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
