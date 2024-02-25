---
date: 2024-02-25
tags:
  - vlan
authors:
  - michelredondo

---

# VLANs on SR Linux (Part 2)

In the previous [VLANs on SR Linux][vlansonsrlinux] article we deep dived into the world of VLANs on SR Linux. In that article we showed that VLAN handling in SR Linux is nothing like Cisco/Arista.

For this second part we thought it would be interesting to mix SR Linux devices with those commonly known in the industry switch vendors like Arista/Cisco. By mixing both vendors in different lab scenarios we will consolidate our knowledge on this fascinating topic of **VLANs!!** 😉

![distracted-vlan](https://github.com/srl-labs/srlinux-eos-vlan-handling-lab/raw/a2191822458dfab9e335c50298c72d28e8564895/distracted-vlan.png){: .img-shadow .img-center style="width:70%"}

<!-- more -->

## Main differences between SR Linux and Cisco/Arista.

Before we start, you can review the core concepts of SR Linux VLAN haddling here:

/// details | Core concepts
    type: tip

VLAN handling on SR Linux  is based on the following core concepts:

1. VLAN IDs (aka dot1q tags) are locally significant within the scope of a subinterface.
2. VLAN IDs are configured on a subinterface level and define the action to be taken on the incoming/outgoing traffic - `pop`/`push` and `accept`/`drop`.
3. The actual switching is powered by the network instances of type `mac-vrf` and one SR Linux instance can have multiple network instances of this type.

For visuals, here is a diagram that shows how VLANs are configured on SR Linux:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":6,"zoom":0.80,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-vlan-handling-lab/diagrams/vlan.drawio"}'></div>

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
interface vlan-tagging false
//////
////// html | td
    markdown: block
no push/pop actions to frames (tagged or untagged) 
//////
/////

///// html | tr
////// html | td
    markdown: block
Single-tagged VLAN
//////
////// html | td
    markdown: block
interface vlan-tagging true

subinterface vlan encap single-tagged vlan-id `id`
//////
////// html | td
    markdown: block
pop action on ingress

push action on egress
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
interface vlan-tagging true

subinterface vlan encap single-tagged vlan-id `any`
//////
////// html | td
    markdown: block
no push/pop actions to frames (tagged or untagged)
//////
/////

///// html | tr
////// html | td
    markdown: block
Single-tagged VLAN range
//////
////// html | td
    markdown: block
interface vlan-tagging true

subinterface subinterface vlan encap single-tagged-range low-vlan-id `id` high-vlan-id `id`
//////
////// html | td
    markdown: block
no push/pop actions to frames within low-hi vlan range

On ingress, drop frames outside the lo-hi vlan range

On egress, no push/pop actions to frames outside the lo-hi vlan range
//////
/////

///// html | tr
////// html | td
    markdown: block
Untagged VLAN
//////
////// html | td
    markdown: block
interface vlan-tagging true

subinterface subinterface vlan encap `untagged`
//////
////// html | td
    markdown: block
no push/pop actions to untagged frames

On ingress, drop frames with VLAN tag being present

On egress, no push/pop actions to frames with VLAN tag being present 
//////
/////

////
///


If we had to name one main difference between the operation of both vendors, that would be lack of the network instances of type `mac-vrf` in Cisco/Arista switches. 

In SR Linux MAC addresses are learned under these different layer 2 bridge domains called `mac-vrfs`. Within a specific `mac-vrf`,  MAC addresses can be learned by frames that use different VLAN ID tags. For example, a host that sends frames tagged with VLAN 10 can communicate with another host that sends frames tagged with VLAN 11, if they are in the same `mac-vrf`.

In Arista/Cisco VLANs are a global property of the switch. When MAC addresses are learned, they are registered in the mac-table together with the information of the vlan and port of the incoming frames. Layer 2 communication is only possible withing the same VLAN bridge domain.

The following diagram that shows this basic difference of operation:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":5,"zoom":0.80,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-eos-vlan-handling-lab/diagrams/srl-eos-vlan.drawio"}'></div>

## Interfaces and VLAN encapsulation

Let's now do a quick review on how Arista handles VLAN encapsulation. Before that, you may want to revisit how SR Linux does it, here: [Interfaces, subinterfaces, and VLAN encapsulation][intsubintvlan].

If you have played with Cisco/Arista devices, you may be tempted to say:  _"switchport access" works on untagged links and "switchport trunk" on tagged ones_, but the reality is a bit more complicated.

When ports are configured in "bridging" operation (`switchport`), they can be configured in two modes [^1]:

1. `switchport mode access` : untagged frames are accepted. MACs are registered in the mac-table with the vlan referenced in the `switchport access vlan <vlan-id>` config of the port. Tagged frames are also accepted, but only if they use the `<vlan-id>` configured.
2. `switchport mode trunk` : both tagged and untagged frames are accepted. Untagged frames are learned under the vlan referenced in the `switchport trunk native vlan  <vlan-id>` config of the port. Tagged frames are learned with the corresponding vlan tag of the frame. The allowed range of vlans is configured with the command `switchport trunk allowed vlan <vlan-id>-<vlan-id>`   

## Lab:

We have also built a lab for this blog post: [srl-labs/srlinux-eos-vlan-handling-lab][lab]. It's quite similar to the lab we built in the previous VLAN Blog post, but in this case we are mixing SR Linux and EOS devices in the same scenarios:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":2,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-eos-vlan-handling-lab/diagrams/srl-eos-vlan.drawio"}'></div>

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
As we go through the lab scenarios, we will be running ping tests between the clients and see how different VLAN configurations affect the traffic. But if you want to see the actual frames, you can run packet captures on any interface of the client or SR Linux nodes, see the [Packet Captures][packet-captures] video where Roman explains how to do it. Or this [one][edgeshark-video] that shows how to use [Edgeshark][edgeshark], if you like having a Web UI for the packet capturing activities.  
///

### Scenario 1: Disabled VLAN tagging

In this scenario of the previous VLAN post, SR Linux switches were configured with the `vlan-tagging false` option. With this option, all incoming frames are forwarded without any modifications. 

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

There is no straightforward  [^1] equivalent scenario in Cisco/Arista that forwards frames transparently. If we want to get as close as possible to the operation in SR Linux, we will have to configure the port in Arista as `trunks` and allow all the VLANs. In Arista, by default, ports are configured in `access` mode and associated with the `VLAN 1`:

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
Ping in VLAN `1` fails. Why??

Remember the `native` VLAN? By default, in EOS, ports send native VLAN traffic with untagged frames. The default native VLAN is ID `1`.  As we are sending traffic with this tag ID, EOS will remove VLAN ID `1` tag when traffic enters through port `Eth1`. SR Linux switch will forward traffic transparently and will be delivered to client2. If you capture the traffic at client2, you will see that, although arp traffic is received untagged, the Linux host is replying with `eth1.1` MAC address through `eth1` interface. This may seem odd but it's standard Linux kernel behavior. You can modify this setting with `arp_announce` and `arp_ignore` kernel parameters. 
Once arp reply is recieved at client1, the Linux kernel will ignore the frame because we performed the arp request using `eth1.1` interface but received the answer through  `eth1`.

This is the visual representation of what's happening:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":1,"zoom":2,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-eos-vlan-handling-lab/diagrams/srl-eos-vlan.drawio"}'></div>

If we want traffic in VLAN `1` to work, we can configure `switchport trunk native vlan tag` in EOS interfaces. With that configuration the ports will send native VLAN traffic with tagged frames. The other effect is that untagged traffic will be discarded.

You can test this alternate configuration with the following command:

```bash
./set-config-eos.sh disabled-tagging-native
```


### Scenario 2: Single-tagged VLAN

In this scenario we are only allowing clients to send tagged traffic with VLAN ID `10`.

With SR Linux, in this mode we configure the interface with VLAN tagging `enabled` and create specific subinterfaces for each required VLAN. The SRL node will drop traffic from VLANs that are not specifically configured. SR Linux Pops and Pushes VLAN tags from client and EOS switch.

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

As per our [single-tagged VLAN](#single-tagged-vlan) section of the original blog post:

1. Untagged frames are dropped, since they don't have a VLAN
2. Single tagged frames with `VLAN 1` are dropped, since they don't match the configured `VLAN 10`.
3. Tagged frames with `VLAN 10` are accepted,  At SRL switch, VLAN tag is popped on ingress and pushed on egress.
4. Single tagged frames with `VLAN 11` are dropped, since they don't match the configured `VLAN 10`.
5. Double tagged frames with outer `VLAN 12` are dropped, since the outer tag doesn't match the configured `VLAN 10`.

This is the visual representation of what's happening:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":2,"zoom":2,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-eos-vlan-handling-lab/diagrams/srl-eos-vlan.drawio"}'></div>


### Scenario 3: Single-tagged-range VLAN

Whenever we want the subinterface to accept frames with a range of VLAN IDs, we can use single-tagged-range encapsulation type.

This mode doesn't pop any VLAN tags on ingress, nor it adds them on ingress. Subinterface will just filter the frames that have VLAN ID within the configured range and pass them through without any modifications.

In this case, for the SR Linux `ethernet-1/10` interface, we have configured the subinterface with vlan-id `any`. So we can also check that tags won't be modified in any way.

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
                    vlan-id any
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

As per our [single-tagged-range VLAN](#single-tagged-range-vlan) section of the original blog post:

1. Untagged frames are dropped, since they don't have a VLAN
2. Single tagged frames with `VLAN 1` are dropped, since they don't match the configured `VLAN 10`.
3. Single tagged frames with `VLAN 10` are accepted. At the SRL switch, frames are forwarded transparently.
4. Single tagged frames with `VLAN 11` are accepted. At the SRL switch, frames are forwarded transparently.
5. Double tagged frames with outer `VLAN 12` are accepted. At the SRL switch, frames are forwarded transparently.

This is the visual representation of what's happening:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":3,"zoom":2,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-eos-vlan-handling-lab/diagrams/srl-eos-vlan.drawio"}'></div>

### Scenario 4: Untagged VLAN

In Arista, ports that only accept untagged frames are configured in `access` mode. We could also use the configuration of the first scenario ([scenario-1-disabled-vlan-tagging](#scenario-1-disabled-vlan-tagging)) to allow untagged traffic, but we would also allow the tagged one.

As we have seen, in Cisco/Arista switches, every MAC address needs to be associated with a VLAN. Even if we configure the port to accept untagged frames, we still need to define the VLAN that will be associated.  We do it with the `switchport access vlan <vlan-id>`.  

In SR Linux we will use the `untagged` vlan encapsulation type.

This scenario has different possible outcomes depending on how we configure the port between the EOS and the SR Linux switch and the VLAN we select:

/// html | table
//// html | thead
///// html | tr
////// html | th
<div style="width:161px">EOS Eth1 config</div>
//////
////// html | th
<div style="width:220px">EOS Eth10 config</div>
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
switchport access vlan 1
//////
////// html | td
    markdown: block
switchport access vlan 1
//////
////// html | td
    markdown: block
Frames are untagged 
//////
/////

///// html | tr
////// html | td
    markdown: block
switchport access vlan 1

(the native vlan)
//////
////// html | td
    markdown: block
switchport trunk allowed vlan 1

switchport trunk native vlan 1
//////
////// html | td
    markdown: block
Frames are untagged because we use the native VLAN
//////
/////

///// html | tr
////// html | td
    markdown: block
switchport access vlan 1

(the native vlan)
//////
////// html | td
    markdown: block
switchport trunk allowed vlan 1

switchport trunk native vlan 1

switchport trunk native vlan tag
//////
////// html | td
    markdown: block
EOS pushes VLAN `1` to frames when egressing Eth10 because we force tagging of the native VLAN
//////
/////

///// html | tr
////// html | td
    markdown: block
switchport access vlan 10
//////
////// html | td
    markdown: block
switchport trunk allowed vlan 1-10

switchport trunk native vlan 1
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

If we had to summarize the key concepts about working with VLANs, it would be:

1. Always consider that in EOS the `native` VLAN can be tagged or untagged depending on the switchport configuration.
2. In SR Linux, ports do push/pop VLAN tags only when VLAN tagging is enabled and configured with specific single-tagged VLAN IDs. This option is great if you want fine-grained control per VLAN/subinterface.
3. In SR Linux, With `vlan-tagging false`, `single-tagged vlan-id any` or `single-tagged-range` frame's tags won't be modified in any way. Whis this option it's very easy to transport a `trunk` of vlans from one port to another. Quite handy for those `switchport trunk allowed vlan 1-4000` configurations. 

Hopefully, this blog post has given you an in-depth view on the vlan switching operation for both SR Linux and EOS. The Lab is at your disposal to try more scenarios.


[vlansonsrlinux]: https://learn.srlinux.dev/blog/2024/vlans-on-sr-linux/
[intsubintvlan]: https://learn.srlinux.dev/blog/2024/vlans-on-sr-linux/#interfaces-subinterfaces-and-vlan-encapsulation
[lab]: https://github.com/srl-labs/srlinux-eos-vlan-handling-lab
[client-config]:https://github.com/srl-labs/srlinux-eos-vlan-handling-lab/blob/main/configs/client.sh
[packet-captures]:https://www.youtube.com/watch?v=qojiQ38troc
[edgeshark]: https://edgeshark.siemens.io/
[edgeshark-video]: https://www.youtube.com/watch?v=iY90a_Gn5W0
[anyvlan]:https://learn.srlinux.dev/blog/2024/vlans-on-sr-linux/#any-or-optional-vlan-id
[single-tagged-vlan]: https://learn.srlinux.dev/blog/2024/vlans-on-sr-linux/#single-tagged-vlan
[single-tagged-range-vlan]: https://learn.srlinux.dev/blog/2024/vlans-on-sr-linux/#single-tagged-range-vlan
[scenario-1-disabled-vlan-tagging]: https://learn.srlinux.dev/blog/2024/vlans-on-sr-linux-part-2/#scenario-1-disabled-vlan-tagging

[^1]: More complex scenarios like dot1q-tunnel mode are also available, but we will stick to the basic trunk/access modes for now.
[^2]: Outer VLAN ID is 12, inner VLAN ID is 13.


<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
