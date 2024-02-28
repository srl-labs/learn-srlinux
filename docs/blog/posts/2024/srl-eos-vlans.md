---
date: 2024-02-25
tags:
  - vlan
authors:
  - michelredondo
links:
  - blog/posts/2024/srl-vlans.md
---

# VLANs on SR Linux and Arista/Cisco

In the recent [VLANs on SR Linux][vlansonsrlinux] blog post we dived deep into the world of VLANs on SR Linux where we saw that VLAN handling in SR Linux is not quite like what we used to see on Cisco/Arista systems.

As a sequel to the original post we decided to mix SR Linux with another popular Network OS - Arista EOS. By mixing different vendor implementations we wanted to provide clear guidance on how to interop between distinct VLAN implementations and help new SR Linux to map existing VLAN concepts to the SR Linux model.

![distracted-vlan](https://github.com/srl-labs/srlinux-eos-vlan-handling-lab/raw/a2191822458dfab9e335c50298c72d28e8564895/distracted-vlan.png){: .img-shadow .img-center style="width:70%"}

<!-- more -->

## Main differences

Before we start, you can review the core concepts of SR Linux VLAN handling:

/// details | Core concepts
    type: tip
--8<-- "docs/blog/posts/2024/srl-vlans.md:concepts"
///

And you can also check the following table that summarizes the SR Linux operation for the different configuration modes:

/// html | table
//// html | thead
///// html | tr
////// html | th
Operation mode
//////
////// html | th
Config
//////
////// html | th
Actions
//////
/////
////

//// html | tbody

///// html | tr
////// html | td
    markdown: block
VLAN tagging disabled
//////
////// html | td
    markdown: block

`interface vlan-tagging false`

//////
////// html | td
    markdown: block
no push/pop actions applied to the frames (tagged or untagged)
//////
/////

///// html | tr
////// html | td
    markdown: block
Single-tagged VLAN
//////
////// html | td
    markdown: block

`interface vlan-tagging true`

`subinterface vlan encap single-tagged vlan-id <vid>`

//////
////// html | td
    markdown: block
pop `<vid>` action on ingress

push `<vid>` action on egress
//////
/////

///// html | tr
////// html | td
    markdown: block
Single-tagged VLAN
`any` vlan
//////
////// html | td
    markdown: block

`interface vlan-tagging true`

`subinterface vlan encap single-tagged vlan-id any`

//////
////// html | td
    markdown: block
no push/pop actions applied to the frames (tagged or untagged)
//////
/////

///// html | tr
////// html | td
    markdown: block
Single-tagged VLAN range
//////
////// html | td
    markdown: block

`interface vlan-tagging true`

`subinterface subinterface vlan encap single-tagged-range low-vlan-id <lvid> high-vlan-id <hvid>`

//////
////// html | td
    markdown: block
no push/pop actions applied to the frames within low-high vlan range

On ingress, drop frames outside the low-high vlan range

On egress, no push/pop actions to frames outside the low-high vlan range
//////
/////

///// html | tr
////// html | td
    markdown: block
Untagged VLAN
//////
////// html | td
    markdown: block

`interface vlan-tagging true`

`subinterface subinterface vlan encap untagged`

//////
////// html | td
    markdown: block
no push/pop actions applied to the untagged frames

On ingress, drop frames with VLAN tag being present

On egress, no push/pop actions applied to the frames with VLAN tag being present
//////
/////

////
///

Probably the most notable difference between SR Linux and IOS-like systems is that there is no notion of a mac-vrf (a.k.a broadcast domain) instance in Cisco/Arista implementations and VLANs are defined globally for a whole system.

In SR Linux MAC addresses belong to the layer 2 bridge domains called `mac-vrfs`, they are like virtual switching instances. For a frame to be classified to a certain mac-vrf a user of SR Linux configures VLAN tagging on a subinterface and associates it with the mac-vrf network instance.

This flexible classification and mapping technique makes it possible to have mac-vrfs network instances that connects network segments with different VLAN tags. For example, a host that sends frames tagged with VLAN 10 can communicate with another host that sends frames tagged with VLAN 11 if they have been classified to the same `mac-vrf` instance.

In Arista/Cisco VLANs are a global property of the switch. When MAC addresses are learned, they are registered in the mac-table together with the information of the vlan and port of the incoming frames. Layer 2 communication is only possible withing the same VLAN bridge domain.

The following diagram shows this major difference between SR Linux and EOS/IOS:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":5,"zoom":0.80,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-eos-vlan-handling-lab/diagrams/srl-eos-vlan.drawio"}'></div>

## Interfaces and VLAN encapsulation

Let's do a quick review of how Arista handles VLAN encapsulation. Before that, you may want to revisit [how SR Linux does it][intsubintvlan] to get the basic concepts refreshed.

If you have played with Cisco/Arista devices, you may be tempted to say:  _"switchport access" works on untagged links and "switchport trunk" on tagged ones_, but the reality is a bit more complicated.

When ports are configured in "bridging" operation (`switchport`), they can be configured in two modes [^1]:

1. `switchport mode access` : untagged frames are accepted. MACs are registered in the mac-table with the vlan referenced in the `switchport access vlan <vlan-id>` config of the port. Tagged frames are also accepted, but only if they use the `<vlan-id>` configured.
2. `switchport mode trunk` : both tagged and untagged frames are accepted. Untagged frames are learned under the vlan referenced in the `switchport trunk native vlan  <vlan-id>` config of the port. Tagged frames are learned with the corresponding vlan tag of the frame. The allowed range of vlans is configured with the command `switchport trunk allowed vlan <vlan-id>-<vlan-id>`

## Lab

Nothing beats some practical exercises, so have built a lab to support this blog post: [srl-labs/srlinux-eos-vlan-handling-lab][lab]. It's quite similar to the lab we built in the previous post, but in this case we are mixing SR Linux and EOS devices:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":2,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-eos-vlan-handling-lab/diagrams/srl-eos-vlan.drawio"}'></div>

For this lab to work you need to have the cEOS image available; check [containerlab][ceoscontainerlab] docs on how to get it.

The two clients are connected to the `ethernet-1/1` and `Ethernet1` interface of the respective SR Linux and Arista switches and have five interfaces [configured][client-config] on them:

| Interface | VLAN ID | IP address | MAC address |
| --------- | ------- | ---------- | ----------- |
| `eth1`    | -       | `10.1.0.${ID}/30` | `aa:c1:ab:00:00:0${ID}` |
| `eth1.1`  | `1`     | `10.1.1.${ID}/30` | `aa:c1:ab:00:01:0${ID}` |
| `eth1.10` | `10`    | `10.1.10.${ID}/30` | `aa:c1:ab:00:10:0${ID}` |
| `eth1.11` | `11`    | `10.1.11.${ID}/30` | `aa:c1:ab:00:11:0${ID}` |
| `eth1.12.13` | `12.13`[^2] | `10.1.12.${ID}/30` | `aa:c1:ab:00:12:0${ID}` |

where `${ID}` is the client ID (1 or 2).

Deploy the lab:

```
sudo containerlab deploy -c -t srl-labs/srlinux-eos-vlan-handling-lab
```

Containerlab will clone the repository in your current working directory and deploy the lab topology. All is ready for us to get started with our practical exercises.

To automate the configuration of the different scenarios we leverage [gnmic](https://gnmic.openconfig.net).

/// tip | packet captures
As we go through the lab scenarios, we will be running ping tests between the clients and see how different VLAN configurations affect the traffic. But if you want to see the actual frames, you can run packet captures on any interface of the client or SR Linux nodes, see the [Packet Captures][packet-captures] video where Roman explains how to do it. Or [this one][edgeshark-video] that shows how to use [Edgeshark][edgeshark], if you like having a Web UI for the packet capturing activities.
///

### Scenario 1: Disabled VLAN tagging

In this scenario SR Linux are configured with the `vlan-tagging false` option. With this option, all incoming frames are forwarded without any modifications.

/// details | SR Linux Configuration
    type: tip

``` srl
# no vlan tagging configured
/ interface ethernet-1/1 {
    admin-state enable
    subinterface 0 {
        type bridged
        admin-state enable
    }
}

/ interface ethernet-1/10 {
    admin-state enable
    subinterface 0 {
        type bridged
        admin-state enable
    }
}

# bridge domain is like a L2 switch instance
/ network-instance bridge-1 {
    type mac-vrf
    admin-state enable
    interface ethernet-1/1.0 {
    }
    interface ethernet-1/10.0 {
    }
}
```

///

There is no straightforward configuration in EOS/IOS that would make transparent forwarding of tagged and untagged frames. If we want to get as close as possible to the operation in SR Linux, we will have to configure the port in Arista EOS as `trunks` and allow all the VLAN IDs. In EOS, by default, ports are configured in `access` mode and associated with the `VLAN 1`:

/// details | EOS Configuration
    type: tip

``` srl
vlan 1-4094
!
interface Ethernet1
   switchport trunk allowed vlan 1-4094
   switchport mode trunk
!
interface Ethernet10
   switchport trunk allowed vlan 1-4094
   switchport mode trunk
!
```

///

To apply this configuration we run these two commands:

```bash
./set-config-srl.sh disabled-tagging
./set-config-eos.sh disabled-tagging
```

Let's see how this configuration affects the traffic between the clients by running our pinger script:

```diff
❯ ./ping-from-cli1.sh all
+ Ping to 10.1.0.2 (no tag) was successful.
- Ping to 10.1.1.2 (single tag VID: 1) failed.
+ Ping to 10.1.10.2 (single tag VID: 10) was successful.
+ Ping to 10.1.11.2 (single tag VID: 11) was successful.
+ Ping to 10.1.12.2 (double tag outer VID: 12, inner VID: 13) was successful.
```

Ping in `VLAN 1` fails. Why?

Remember the `native` VLAN? By default, in EOS, ports send native VLAN traffic with untagged frames. The default native VLAN is ID `1`.  
As we are sending traffic with this tag ID, EOS will remove VLAN ID `1` tag when traffic enters through port `Eth1`.

SR Linux forwards the traffic transparently and deliver the ethernet frames to the client2. If you capture the traffic at client2, you will see that, although ARP traffic is received untagged, the Linux host is replying with `eth1.1` MAC address via `eth1` interface. This may seem odd, but it's a standard Linux kernel behavior. You can modify this setting with `arp_announce` and `arp_ignore` kernel parameters.

Once ARP reply is received at client1, the Linux kernel will ignore the frame because we performed the ARP request using `eth1.1` interface but received the answer via `eth1`.

This is the visual representation of what's happening:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":1,"zoom":2,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-eos-vlan-handling-lab/diagrams/srl-eos-vlan.drawio"}'></div>

If we want the traffic in `VLAN 1` to work, we can configure `switchport trunk native vlan tag` on EOS interfaces; with this configuration in effect, EOS sends native VLAN traffic as tagged frames. The side effect of this configuration is that the untagged traffic will be discarded entirely.

You can test this alternate configuration with the following command:

```bash
./set-config-eos.sh disabled-tagging-native
```

### Scenario 2: Single-tagged VLAN

In this scenario we are only allowing clients to send tagged traffic with VLAN tag `10`.

In SR Linux we configure the interface with VLAN tagging `enabled` and create subinterfaces for each specific dot1q tag. The SR Linux node will drop frames with dot1q tags that were not specifically configured on its subinterfaces. SR Linux performs Pop and Push operations on the frames ingressing and egressing from the mac-vrf.

This is the configuration on SR Linux:

/// details | SR Linux Configuration
    type: tip

``` srl
# vlan tagging enabled
interface ethernet-1/1 {
    admin-state enable
    vlan-tagging true
    subinterface 10 {
        type bridged
        admin-state enable
        vlan {
            encap {
                single-tagged {
                    vlan-id 10
                }
            }
        }
    }
}

interface ethernet-1/10 {
    admin-state enable
    vlan-tagging true
    subinterface 10 {
        type bridged
        admin-state enable
        vlan {
            encap {
                single-tagged {
                    vlan-id 10
                }
            }
        }
    }
}

network-instance bridge-1 {
    type mac-vrf
    admin-state enable
    interface ethernet-1/1.10 {
    }
    interface ethernet-1/10.10 {
    }
}

```

///

And this is the required config for EOS:

/// details | EOS Configuration
    type: tip

``` srl
vlan 10
!
interface Ethernet1
   switchport trunk allowed vlan 10
   switchport mode trunk
!
interface Ethernet10
   switchport trunk allowed vlan 10
   switchport mode trunk
!
```

///

To apply this configuration we run these two commands:

```bash
./set-config-srl.sh single-tag
./set-config-eos.sh single-tag
```

Let's run the pinger to see how this affects our setup:

```diff
❯ ./ping-from-cli1.sh all
- Ping to 10.1.0.2 (no tag) failed.
- Ping to 10.1.1.2 (single tag VID: 1) failed.
+ Ping to 10.1.10.2 (single tag VID: 10) was successful.
- Ping to 10.1.11.2 (single tag VID: 11) failed.
- Ping to 10.1.12.2 (double tag outer VID: 12, inner VID: 13) failed.
```

As per the [single-tagged VLAN](./srl-vlans.md#single-tagged-vlan) section of the original blog post:

1. Untagged frames are dropped, since they don't have a VLAN tag present.
2. Single tagged frames with `VLAN 1` tag are dropped, since they don't match the configured `VLAN 10`.
3. Tagged frames with `VLAN 10` tag are accepted; on SR Linux side VLAN tag is popped on ingress and pushed on egress.
4. Single tagged frames with `VLAN 11` tag are dropped, since they don't match the configured `VLAN 10`.
5. Double tagged frames with outer `VLAN 12` tag are dropped, since the outer tag doesn't match the configured `VLAN 10`.

This is the visual representation of the packet flow for this scenario:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":2,"zoom":2,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-eos-vlan-handling-lab/diagrams/srl-eos-vlan.drawio"}'></div>

### Scenario 3: Single-tagged-range VLAN

Whenever we want the subinterfaces to accept frames with a range of VLAN IDs, we can configure the `single-tagged-range` encapsulation type in SR Linux.

This mode doesn't pop any VLAN tags on ingress, nor it adds them on ingress. Subinterface will just filter the frames that have VLAN ID within the configured range and pass them through without any modifications.

In Arista, this scenario is similar to the previous one, the only difference is that we will increase the range of allowed vlans.

This is the configuration for SR Linux:

/// details | SR Linux Configuration
    type: tip

``` srl
# vlan tagging enabled
interface ethernet-1/1 {
    admin-state enable
    vlan-tagging true
    subinterface 10 {
        type bridged
        admin-state enable
        vlan {
            encap {
                single-tagged-range {
                    low-vlan-id 10 {
                        high-vlan-id 15
                    }
                }
            }
        }
    }
}

interface ethernet-1/10 {
    admin-state enable
    vlan-tagging true
    subinterface 0 {
        type bridged
        admin-state enable
        vlan {
            encap {
                single-tagged {
                    vlan-id any #(1)!
                }
            }
        }
    }
}

network-instance bridge-1 {
    type mac-vrf
    admin-state enable
    interface ethernet-1/1.10 {
    }
    interface ethernet-1/10.0 {
    }
}
```

1. For a change, we configure `ethernet-1/10.0` subinterface with the `vlan-id any` encapsulation. This encapsulation will ensure that we have the same vlan transparency as with the `vlan-tagging false` option, but it allows us to configure VLANs on the other subinterfaces under the `ethernet-1/10` interface.

///

And this is the configuration in EOS:

/// details | EOS Configuration
    type: tip

``` srl
vlan 10-15
!
interface Ethernet1
   switchport trunk native vlan tag
   switchport trunk allowed vlan 10-15
   switchport mode trunk
!
interface Ethernet10
   switchport trunk native vlan tag
   switchport trunk allowed vlan 10-15
   switchport mode trunk
!
```

///

To apply this configuration we run these two commands:

```bash
./set-config-srl.sh single-tag-range
./set-config-eos.sh single-tag-range
```

And let's run the pinger:

```diff
❯ ./ping-from-cli1.sh all
- Ping to 10.1.0.2 (no tag) failed.
- Ping to 10.1.1.2 (single tag VID: 1) failed.
+ Ping to 10.1.10.2 (single tag VID: 10) was successful.
+ Ping to 10.1.11.2 (single tag VID: 11) was successful.
+ Ping to 10.1.12.2 (double tag outer VID: 12, inner VID: 13) was successful.
```

As per our [single-tagged-range VLAN](./srl-vlans.md#single-tagged-range-vlan) section of the original blog post:

1. Untagged frames are dropped, since they don't have a VLAN tag present.
2. Single tagged frames with `VLAN 1` are dropped, since they don't match the configured `VLAN 10`.
3. Single tagged frames with `VLAN 10` are accepted. At the SRL switch, frames are forwarded transparently.
4. Single tagged frames with `VLAN 11` are accepted. At the SRL switch, frames are forwarded transparently.
5. Double tagged frames with outer `VLAN 12` are accepted. At the SRL switch, frames are forwarded transparently.

This is the visual representation of what's happening:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":3,"zoom":2,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-eos-vlan-handling-lab/diagrams/srl-eos-vlan.drawio"}'></div>

### Scenario 4: Untagged VLAN

In Arista, ports that only accept untagged frames are configured in `access` mode. We could also use the configuration of the [first scenario](#scenario-1-disabled-vlan-tagging) to allow untagged traffic, but we would also allow the tagged one.

As we have seen, in EOS/IOS systems, every MAC address needs to be associated with a VLAN. Even if we configure the port to accept untagged frames, we still need to define the VLAN that will be associated. We do it with the `switchport access vlan <vlan-id>`.

In SR Linux we will use the `untagged` vlan encapsulation type.

This scenario has different possible outcomes depending on how we configure the port between the EOS and the SR Linux switch and the VLAN we select:

/// html | table
//// html | thead
///// html | tr
////// html | th
    markdown: block
EOS `Eth1` config
//////
////// html | th
    markdown: block
EOS `Eth10` config
//////
////// html | th
Actions
//////
/////
////

//// html | tbody

///// html | tr
////// html | td
    markdown: block
`switchport access vlan 1`
//////
////// html | td
    markdown: block
`switchport access vlan 1`
//////
////// html | td
    markdown: block
Frames are untagged
//////
/////

///// html | tr
////// html | td
    markdown: block
`switchport access vlan 1`

(the native vlan)
//////
////// html | td
    markdown: block
`switchport trunk allowed vlan 1`

`switchport trunk native vlan 1`
//////
////// html | td
    markdown: block
Frames are untagged because we use the native VLAN
//////
/////

///// html | tr
////// html | td
    markdown: block
`switchport access vlan 1`

(the native vlan)
//////
////// html | td
    markdown: block
`switchport trunk allowed vlan 1`

`switchport trunk native vlan 1`

`switchport trunk native vlan tag`
//////
////// html | td
    markdown: block
EOS pushes VLAN `1` to frames when egressing Eth10 because we force tagging of the native VLAN
//////
/////

///// html | tr
////// html | td
    markdown: block
`switchport access vlan 10`
//////
////// html | td
    markdown: block
`switchport trunk allowed vlan 1-10`

`switchport trunk native vlan 1`
//////
////// html | td
    markdown: block
EOS pushes VLAN `10` to frames when egressing Eth10
//////
/////

////
///

As you can see, the usage of the native VLAN introduces many variations. For our ping tests we will stick to the last configuration, where EOS tags VLAN `10` between both switches.

This is the configuration for SR Linux:

/// details | SR Linux Configuration
    type: tip

``` srl
# vlan tagging enabled
interface ethernet-1/1 {
    admin-state enable
    vlan-tagging true
    subinterface 10 {
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

interface ethernet-1/10 {
    admin-state enable
    vlan-tagging true
    subinterface 10 {
        type bridged
        admin-state enable
        vlan {
            encap {
                single-tagged {
                    vlan-id 10
                }
            }
        }
    }
}

network-instance bridge-1 {
    type mac-vrf
    admin-state enable
    interface ethernet-1/1.10 {
    }
    interface ethernet-1/10.10 {
    }
}
```

///

And this is the configuration in EOS:

/// details | EOS Configuration
    type: tip

``` srl
vlan 10
!
interface Ethernet1 #(1)!
   switchport access vlan 10
   switchport mode access
!
interface Ethernet10
   switchport mode trunk
   switchport trunk allowed vlan 10
!
```

1. You can apply the default configuration for a port by applying `default interface Eth1`

///

To apply this configuration we run these two commands:

```bash
./set-config-srl.sh untagged
./set-config-eos.sh untagged
```

Let's run the pinger and see the results:

```diff
❯ ./ping-from-cli1.sh all
+ Ping to 10.1.0.2 (no tag) was successful.
- Ping to 10.1.1.2 (single tag VID: 1) failed.
- Ping to 10.1.10.2 (single tag VID: 10) failed.
- Ping to 10.1.11.2 (single tag VID: 11) failed.
- Ping to 10.1.12.2 (double tag outer VID: 12, inner VID: 13) failed.
```

And the visual representation of what's happening:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":4,"zoom":2,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-eos-vlan-handling-lab/diagrams/srl-eos-vlan.drawio"}'></div>

You can see that `EOS` device still forwards VLAN `10` traffic. This is because `access` port accepts untagged and tagged traffic of the VLAN ID configured.  

## Summary

We have seen how a simple concept as a VLAN can keep us busy for quite a long time. The flexibility of SR Linux VLAN handling provides many options to handle all the different scenarios.

If we had to summarize the key concepts about working with VLAN on SR Linux and IOS-like platforms, here are a few takeaways:

1. Always consider that in EOS the `native` VLAN can be tagged or untagged depending on the switchport configuration.
2. In SR Linux, ports do push/pop VLAN tags only when VLAN tagging is enabled and configured with specific single-tagged VLAN IDs. This option is great if you want fine-grained control per VLAN/subinterface.
3. In SR Linux, With `vlan-tagging false`, `single-tagged vlan-id any` or `single-tagged-range` frame's tags won't be modified in any way. With this option it's very easy to transport a `trunk` of vlans from one port to another. Quite handy for those `switchport trunk allowed vlan 1-4000` configurations.

Hopefully, this blog post has given you an in-depth view on the vlan switching operation for both SR Linux and EOS. The Lab is at your disposal to try more scenarios and see how the different configurations affect the traffic.

[vlansonsrlinux]: ./srl-vlans.md
[intsubintvlan]: ./srl-vlans.md#interfaces-subinterfaces-and-vlan-encapsulation
[lab]: https://github.com/srl-labs/srlinux-eos-vlan-handling-lab
[client-config]: https://github.com/srl-labs/srlinux-eos-vlan-handling-lab/blob/main/configs/client.sh
[packet-captures]: https://www.youtube.com/watch?v=qojiQ38troc
[edgeshark]: https://edgeshark.siemens.io/
[edgeshark-video]: https://www.youtube.com/watch?v=iY90a_Gn5W0
[ceoscontainerlab]: https://containerlab.dev/manual/kinds/ceos/

[^1]: More complex scenarios like dot1q-tunnel mode are also available, but we will stick to the basic trunk/access modes in this post.
[^2]: Outer VLAN ID is 12, inner VLAN ID is 13.

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
