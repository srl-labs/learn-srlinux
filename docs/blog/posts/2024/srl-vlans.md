---
date: 2024-01-16
tags:
  - vlan
authors:
  - rdodin
  - reda
  - sfomin
links:
  - blog/posts/2024/srl-eos-vlans.md
---

# VLANs on SR Linux

<small> Discussions: [:material-twitter:][twitter-discuss] · [:material-linkedin:][linkedin-discuss]</small>

What was one of the most common questions in our SR Linux discord in 2023?

EVPN?
YANG?
Streaming Telemetry?
Programmability?
Scaling DC workloads?

No. **VLANs** 😅

This buddy hurt you good in your early days, right? With global VLANs, trunks, and forgotten `add`? Your understanding of VLANs provisioning might get clouded by the industry-standard way of doing things, which may result in a lot of
confusion when you start working with SR Linux.

Get yourself comfy, we are about to have a deep dive into VLANs on SR Linux.

![cisco-man](https://gitlab.com/rdodin/pics/-/wikis/uploads/427e51e83b663612ed94d6cf3bd788d9/image.png){: .img-shadow .img-center style="width:80%"}

<!-- more -->

## Core concepts
<!-- --8<-- [start:concepts] -->
VLAN handling on SR Linux is nothing like Cisco and is based on the following core concepts:

1. VLAN IDs (aka dot1q tags) are locally significant within the scope of a subinterface.
2. VLAN IDs are configured on a subinterface level and define the action to be taken on the incoming/outgoing traffic - `pop`/`push` and `accept`/`drop`.
3. The actual switching is powered by the network instances of type `mac-vrf` and one SR Linux instance can have multiple network instances of this type.

For visuals, here is a diagram that shows how VLANs are configured on SR Linux:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":6,"zoom":2,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-vlan-handling-lab/diagrams/vlan.drawio"}'></div>
<!-- --8<-- [end:concepts] -->
Now let's go through each of these concepts in detail and see how they work together to provide a flexible and scalable solution for VLAN handling.

///note
Everything described in this post is applicable to SR Linux 23.10.1 running on D/H platforms.
///

/// details | TLDR
    type: tip

The executive engineering summary of this post can be summarized in the following graphics that explains core configuration concepts and VLAN handling on SR Linux in both directions.

(clickable)

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":1,"zoom":1,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-vlan-handling-lab/diagrams/vlan.drawio"}'></div>
///

## Interfaces, subinterfaces, and VLAN encapsulation

VLAN encapsulation is a property of an interface/subinterface pair and **not** a globally significant property of SR Linux. Whenever you want to configure VLANs on SR Linux, you need to

1. enable VLAN tagging support on the interface level
2. and then configure VLANs on the subinterface level.

///admonition | What is a subinterface?
    type: question
Subinterface is a logical interface that is created on top of a physical interface. It is used to provide a logical separation of traffic on the same physical interface.

When an interface `ethernet-1/1` is configured with a `subinterface 0`, the latter can be referenced as `ethernet-1/1.0`. Subinterface index (`0` in our example) has nothing to do with the VLAN ID and is used to uniquely identify a subinterface within the scope of a physical interface.
///

The VLAN configuration is significant to that particular pair of interface/subinterface and is not shared with other interfaces/subinterfaces. This means that you can have different VLAN configurations on different subinterfaces of the same physical interface.

Here is an example of a basic interface/subinterface configuration that enables VLAN tagging on the interface level and configures a single subinterface with VLAN ID `100`:

```srl
--{ + running }--[  ]--
A:srl1# info / interface ethernet-1/1
    interface ethernet-1/1 {
        admin-state enable #(1)!
        vlan-tagging true #(4)!
        subinterface 0 { #(3)!
            type bridged
            admin-state enable
            vlan { #(2)!
                encap {
                    single-tagged {
                        vlan-id 100
                    }
                }
            }
        }
    }
```

1. To make VLAN tagging work, you need to enable it on the interface level first.
2. On subinterface level you configure the vlan encapsulation. In this example we configure a single-tagged VLAN with ID `100`.
3. Subinterface index is used to uniquely identify a subinterface within the scope of a physical interface and has no relation to the VLAN ID.  
    However, often it is convenient to use the same index as the VLAN ID, so we could use `subinterface 100` name to denote that traffic with VLAN ID `100` is handled by it.
4. `vlan-tagging` is a statement that enables the ability to do a lookup on the tags on the interface. When not enabled (set to `true`) the interface (and all its subinterface) will be agnostic to any VLAN information present/absent in the incoming frames and will not perform any VLAN-related actions on them in any direction.

There is a number of encapsulation modes one can configure on SR Linux; Let's dive into each and every one of them to understand what they entail for the incoming and outgoing traffic.

### VLAN tagging disabled

It makes sense to start with a basic configuration (or no configuration at all) of the `ethernet-1/1` interface that has no `vlan-tagging` enabled and has a single `bridged` subinterface with index `0` that is enabled.

```srl
--{ + running }--[  ]--
A:srl1# info / interface ethernet-1/1
    interface ethernet-1/1 {
        admin-state enable
        subinterface 0 {
            type bridged
            admin-state enable
        }
    }
```

This configuration effectively means that all ethernet frames received on the `ethernet-1/1.0` subinterface will be forwarded to network instance this subinterface is attached to **without modifications**.

With this configuration, SR Linux is agnostic to any VLAN information present/absent in the incoming frames and will not perform any VLAN-related actions on them in any direction. See [lab scenario 1](#scenario-1-disabled-vlan-tagging) for a practical example.

### Single-tagged VLAN

Sticking the next gear and we have a configuration that enables VLAN tagging on the `ethernet-1/1` interface and configures a single-tagged VLAN with ID `10` on the `ethernet-1/1.0` subinterface.

```srl
--{ + running }--[  ]--
A:srl1# info / interface ethernet-1/1
    interface ethernet-1/1 {
        admin-state enable
        vlan-tagging true
        subinterface 0 {
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
```

Now we have a whole lot of behavioral patterns applied to the frames in the incoming and outgoing directions:

/// html | table
//// html | thead
///// html | tr
////// html | th
Frame type
//////
////// html | th
Ingress
//////
////// html | th
Egress
//////
/////
////

//// html | tbody

///// html | tr
////// html | td
    markdown: block
Untagged
//////
////// html | td
    markdown: block
Dropped, due to VLAN tag missing
//////
////// html | td
    markdown: block
Accepted, VLAN tag `10` is added (push)
//////
/////

///// html | tr
////// html | td
    markdown: block
Single tag VLAN ID `10`
//////
////// html | td
    markdown: block
Accepted, VLAN tag `10` is removed (pop)
//////
////// html | td
    markdown: block
Accepted, VLAN tag `10` is added (push)
//////
/////

///// html | tr
////// html | td
    markdown: block
Single tag VLAN ID `99`
//////
////// html | td
    markdown: block
Dropped, VLAN tag `99` doesn't match configured VLAN `10`
//////
////// html | td
    markdown: block
Accepted, VLAN tag `10` is added (push)
//////
/////

///// html | tr
////// html | td
    markdown: block
Double tag (q-in-q) with outer VLAN `10`
//////
////// html | td
    markdown: block
Accepted, VLAN tag `10` is removed (pop)
//////
////// html | td
    markdown: block
Accepted, VLAN tag `10` is added (push)
//////
/////

////
///

This encapsulation mode is covered in the 2nd lab scenario - [Single-tagged VLAN](#scenario-2-single-tagged-vlan).

#### Any or optional VLAN ID

You might have noticed that the `vlan-id` parameter under the `single-tagged` block can take either an integer value in the range of `1..4094` or a special value `any`[^3].

```srl
--{ candidate shared default }--[  ]--
A:srl1# interface ethernet-1/1 subinterface 0 vlan encap single-tagged vlan-id any
usage: vlan-id <value>

VLAN identifier for single-tagged packets.

Positional arguments:
  value             [number, range 1..4094]|[any]
```

The `any` value is a "catch all" value that will classify frames with any VLAN ID present or VLAN ID absent (untagged) as belonging to this subinterface. This is a convenient way to configure a subinterface to accept all the frames that were not classified to any other subinterface of the same physical interface.

As for the tag push/pop behavior, the frame's tags won't be modified in any way.

Another interesting behavior of the `any` value is that it will be considered less specific when it comes to matching untagged frames, when the `untagged` encapsulation is configured on any subinterface of the same physical interfaces. Let us know in the comments if you want a diagram for that :smile:

### Single-tagged-range VLAN

Whenever you want the subinterface to accept frames with a range of VLAN IDs, you can use `single-tagged-range` encapsulation type. This configuration enables VLAN tagging on the `ethernet-1/1` interface and configures a single-tagged VLAN with ID range `10-15` on the `ethernet-1/1.0` subinterface. Frames with VLAN IDs from 10 to 15 (inclusive) will be accepted by this subinterface.

```srl
--{ + running }--[  ]--
A:srl1# info / interface ethernet-1/1
    interface ethernet-1/1 {
        admin-state enable
        vlan-tagging true
        subinterface 0 {
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
```

The interesting thing about this mode is that it doesn't pop any VLAN tags on ingress, nor it adds them on ingress. Subinterface will just filter the frames that have VLAN ID within the configured range and pass them through without any modifications.

/// html | table
//// html | thead
///// html | tr
////// html | th
Frame type
//////
////// html | th
Ingress
//////
////// html | th
Egress
//////
/////
////

//// html | tbody

///// html | tr
////// html | td
    markdown: block
Untagged
//////
////// html | td
    markdown: block
Dropped, due to VLAN tag missing
//////
////// html | td
    markdown: block
Accepted, no modifications done to the VLAN stack
//////
/////

///// html | tr
////// html | td
    markdown: block
Single tag VLAN ID `10`
//////
////// html | td
    markdown: block
Accepted, no modifications done to the VLAN stack
//////
////// html | td
    markdown: block
Accepted, no modifications done to the VLAN stack
//////
/////

///// html | tr
////// html | td
    markdown: block
Single tag VLAN ID `99`
//////
////// html | td
    markdown: block
Dropped, VLAN tag `99` doesn't belong to the configured range `10-15`
//////
////// html | td
    markdown: block
Accepted, no modifications done to the VLAN stack
//////
/////

///// html | tr
////// html | td
    markdown: block
Double tag (q-in-q) with outer VLAN `10`
//////
////// html | td
    markdown: block
Accepted since outer tag is in the configured range, no modifications done to the VLAN stack
//////
////// html | td
    markdown: block
Accepted, no modifications done to the VLAN stack
//////
/////

////
///

Refer to the scenario 3 - [Single-tagged-range VLAN](#scenario-3-single-tagged-range-vlan) for a practical example.

### Untagged

What if you want to ensure that only untagged[^1] frames are being accepted by a subinterface? The untagged vlan encapsulation mode covers this use case. This configuration enables VLAN tagging on the `ethernet-1/1` interface and configures an untagged VLAN on the `ethernet-1/1.0` subinterface.  
Frames with no VLAN tags will be accepted by this subinterface, but tagged frames will be dropped.

```srl
--{ + running }--[  ]--
A:srl1# info / interface ethernet-1/1
    interface ethernet-1/1 {
        admin-state enable
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
```

Here is what happens to different types of frames in the incoming and outgoing directions:

/// html | table
//// html | thead
///// html | tr
////// html | th
Frame type
//////
////// html | th
Ingress
//////
////// html | th
Egress
//////
/////
////

//// html | tbody

///// html | tr
////// html | td
    markdown: block
Untagged
//////
////// html | td
    markdown: block
Accepted, due to VLAN tag missing
//////
////// html | td
    markdown: block
Accepted, no modifications done to the VLAN stack
//////
/////

///// html | tr
////// html | td
    markdown: block
Single tag VLAN ID `10`
//////
////// html | td
    markdown: block
Dropped, due to VLAN tag being present
//////
////// html | td
    markdown: block
Accepted, no modifications done to the VLAN stack
//////
/////

///// html | tr
////// html | td
    markdown: block
Single tag VLAN ID `99`
//////
////// html | td
    markdown: block
Dropped, due to VLAN tag being present
//////
////// html | td
    markdown: block
Accepted, no modifications done to the VLAN stack
//////
/////

///// html | tr
////// html | td
    markdown: block
Double tag (q-in-q) with outer VLAN `10`
//////
////// html | td
    markdown: block
Dropped, due to VLAN tag being present
//////
////// html | td
    markdown: block
Accepted, no modifications done to the VLAN stack
//////
/////

////
///

Best to see this encapsulation mode in action in the scenario 4 - [Untagged VLAN](#scenario-4-untagged-vlan).

## MAC-VRF

We've been focusing on the interfaces so far where frame classification is done based on the VLAN ID. However, interfaces themselves doesn't perform any switching. In SR Linux switching is done by the network instances of type `mac-vrf`.

Whenever you create a network instance of type `mac-vrf`, you create an instance of a virtual layer 2 switch. This switch will have a MAC address table and will perform switching based on the destination MAC address of the incoming frames.

How do you create a network instance of type `mac-vrf`? Easy:

```srl
--{ + running }--[  ]--
A:srl1# info network-instance bridge-1
    network-instance bridge-1 {
        type mac-vrf
        admin-state enable
    }
```

Here we created a mac-vrf (or virtual switch, if you want) with the name `bridge-1`. As any switch, it has a MAC address table that is populated with the MAC addresses of the incoming frames. The MAC address table is populated based on the source MAC address of the incoming frames and switching is done based on the destination MAC address of the incoming frames.

A newly created mac-vrf instance has a pristine MAC address table with no entries in it:

```srl
--{ + running }--[  ]--
A:srl1# show network-instance bridge-1 bridge-table mac-table summary
-----------------------------------------------------------------------------------------
Network Instance Bridge Table Summary
-----------------------------------------------------------------------------------------
Network Instance: bridge-1
Irb Macs             :    0 Total    0 Active
Static Macs          :    0 Total    0 Active
Duplicate Macs       :    0 Total    0 Active
Learnt Macs          :    0 Total    0 Active
Evpn Macs            :    0 Total    0 Active
Evpn Static Macs     :    0 Total    0 Active
Irb anycast Macs     :    0 Total    0 Active
Proxy Antispoof Macs :    0 Total    0 Active
Reserved Macs        :    0 Total    0 Active
Eth-cfm Macs         :    0 Total    0 Active
Total Macs           :    0 Total    0 Active
Maximum Entries  : -
Warning Threshold: -
Clear Warning    : -
-----------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------
Total Irb Macs                 :    0 Total    0 Active
Total Static Macs              :    0 Total    0 Active
Total Duplicate Macs           :    0 Total    0 Active
Total Learnt Macs              :    0 Total    0 Active
Total Evpn Macs                :    0 Total    0 Active
Total Evpn Static Macs         :    0 Total    0 Active
Total Irb Anycast Macs         :    0 Total    0 Active
Total Proxy Antispoof Macs     :    0 Total    0 Active
Total Reserved Macs            :    0 Total    0 Active
Total Eth-cfm Macs             :    0 Total    0 Active
Total Macs                     :    0 Total    0 Active
-----------------------------------------------------------------------------------------
```

What happens next? Does our `bridge-1` virtual switch start to glean frames from all the interfaces in the system? No. It doesn't. It will only start to learn MAC addresses from the interfaces that are attached to it.  
Explicitness is one of the core principles of SR Linux, so you need to explicitly attach **subinterfaces** to the network instance for frames to start entering the mac-vrf.

Here is how the configuration of the `bridge-1` network instance looks like after we attached the `ethernet-1/1.0` and `ethernet-1/10.0` subinterfaces to it:

```srl
--{ + running }--[  ]--
A:srl1# info network-instance bridge-1
    network-instance bridge-1 {
        type mac-vrf
        admin-state enable
        interface ethernet-1/1.0 {
        }
        interface ethernet-1/10.0 {
        }
    }
```

With this config, the `bridge-1` subinterfaces `ethernet-1/1.0` and `ethernet-1/10.0` will classify the incoming frames based on the VLAN configuration and will forward them to the `bridge-1` network instance. The latter will learn the source MAC addresses of the incoming frames and will populate its MAC address table.

## The Lab

No surprise, we have built a lab for this post - [srl-labs/srlinux-vlan-handling-lab][lab]. You shouldn't trust anything that is written here unless you lab it yourself, and we are here to help you with that.

Throughout the rest of this post we will be using the following lab topology to demonstrate various VLAN handling scenarios:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":2,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-vlan-handling-lab/diagrams/vlan.drawio"}'></div>

The two clients are connected to the `ethernet-1/1` interface of the respective SR Linux switches and have four interfaces [configured][client-config] on them:

| Interface | VLAN ID | IP address | MAC address |
| --------- | ------- | ---------- | ----------- |
| `eth1`    | -       | `10.1.0.${ID}/30` | `aa:c1:ab:00:00:0${ID}` |
| `eth1.10` | `10`    | `10.1.1.${ID}/30` | `aa:c1:ab:00:01:0${ID}` |
| `eth1.11` | `11`    | `10.1.2.${ID}/30` | `aa:c1:ab:00:02:0${ID}` |
| `eth1.12.13` | `12.13`[^2] | `10.1.3.${ID}/30` | `aa:c1:ab:00:03:0${ID}` |

where `${ID}` is the client ID (1 or 2).

With a static configuration on the clients we will change the encapsulation type on the `ethernet-1/1` interface of the SR Linux switches and see how it affects the traffic between the clients' interfaces.

Deploy the lab:
/// tab | Locally

```
sudo containerlab deploy -c -t srl-labs/srlinux-vlan-handling-lab
```

///
/// tab | With Codespaces
<div align=center markdown>
<a href="https://codespaces.new/srl-labs/srlinux-vlan-handling-lab?quickstart=1">
<img src="https://gitlab.com/rdodin/pics/-/wikis/uploads/d78a6f9f6869b3ac3c286928dd52fa08/run_in_codespaces-v1.svg?sanitize=true" style="width:50%"/></a>

**[Run](https://codespaces.new/srl-labs/srlinux-vlan-handling-lab?quickstart=1) this lab in GitHub Codespaces for free**.  
[Learn more](https://containerlab.dev/manual/codespaces) about Containerlab for Codespaces.  
<small>Machine type: 2 vCPU · 8 GB RAM</small>
</div>
///

Containerlab will clone the repository in your current working directory and deploy the lab topology. All is ready for us to get started with our practical exercises.

/// tip | packet captures
As we go through the lab scenarios, we will be running ping tests between the clients and see how different VLAN configurations affect the traffic. But if you want to see the actual frames, you can run packet captures on any interface of the client or SR Linux nodes, see the [Packet Captures](#packet-captures)
///

### Scenario 1: Disabled VLAN tagging

When the lab starts, the [startup configuration][srl-startup] is applied to both SR Linux switches which render them using the following configuration:

```srl
--8<-- "https://raw.githubusercontent.com/srl-labs/srlinux-vlan-handling-lab/main/configs/srl.cfg"
```

A single mac-vrf instance `bridge-1` is created on both SR Linux switches and the `ethernet-1/1` interface is attached to it from the clients side. Both switches are connected to each other via the `ethernet-1/10` interface, and this interface is also attached to the `bridge-1` network instance of the respective switches.

All switch interfaces are configured with the `vlan-tagging` **not enabled**, which means that all the incoming and outgoing frames will be forwarded to the `bridge-1` network instance without any modifications (just as we covered in the [VLAN tagging disabled](#vlan-tagging-disabled) section).

Let's see how this configuration affects the traffic between the clients by running our pinger script:

```{.bash .no-select}
sudo ./ping.sh all
```

<div class="embed-result">
```{.diff .no-select .no-copy}
+ Ping to 10.1.0.2 (no tag) was successful.
+ Ping to 10.1.1.2 (single tag VID: 10) was successful.
+ Ping to 10.1.2.2 (single tag VID: 11) was successful.
+ Ping to 10.1.3.2 (double tag outer VID: 12, inner VID: 13) was successful.
```
</div>

Hey, all pings succeeded! And this is because this happened:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":2,"zoom":2,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-vlan-handling-lab/diagrams/vlan.drawio"}'></div>

When the parent interface has not enabled `vlan-tagging`, all the incoming frames are forwarded to the `bridge-1` network instance without any modifications. The latter will learn the source MAC addresses of the incoming frames and will populate its MAC address table.

### Scenario 2: Single-tagged VLAN

Let's now enable `vlan-tagging` on the `ethernet-1/1` interface of both SR Linux switches. To automate the configuration we leverage [gnmic](https://gnmic.openconfig.net) in the CLI mode and run the following command:

```{.bash .no-select}
./set-iface.sh single-tag
```

///details | Interface configuration
    type: example

```srl
--{ running }--[  ]--
A:srl1# info interface ethernet-1/1
    interface ethernet-1/1 {
        admin-state enable
        vlan-tagging true
        subinterface 0 {
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
```

///

This command enables `vlan-tagging` on the `ethernet-1/1` interface and configures a single-tagged VLAN with ID `10` on the `ethernet-1/1.0` subinterface. Re-run the pinger to see how this affects our setup:

```{.bash .no-select}
sudo ./ping.sh all
```

<div class="embed-result">
```{.diff .no-select .no-copy}
- Ping to 10.1.0.2 (no tag) failed.
+ Ping to 10.1.1.2 (single tag VID: 10) was successful.
- Ping to 10.1.2.2 (single tag VID: 11) failed.
- Ping to 10.1.3.2 (double tag outer VID: 12, inner VID: 13) failed.
```
</div>

Well, entirely different picture now:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":3,"zoom":2,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-vlan-handling-lab/diagrams/vlan.drawio"}'></div>

As per our [single-tagged VLAN](#single-tagged-vlan) section:

1. Untagged frames are dropped, since they don't have a VLAN
2. Single tagged frames with VLAN ID `10` are accepted and the VLAN tag is removed (popped) on `srl1` and added (pushed) on `srl2` when the frame egresses the `bridge-1` network instance over the `ethernet-1/10` interface.
3. Single tagged frames with VLAN ID `11` are dropped, since they don't match the configured VLAN ID `10`.
4. Double tagged frames with outer VLAN ID `12` are dropped, since the outer tag doesn't match the configured VLAN ID `10`.

### Scenario 3: Single-tagged-range VLAN

Now it is time to configure VLAN tagging on the `ethernet-1/1` interface of both SR Linux switches with a `single-tagged-range` VLAN. As we identified in the [single-tagged-range VLAN](#single-tagged-range-vlan) section, this configuration will accept frames with VLAN IDs from `10` to `15` (inclusive). Let's apply this configuration:

```bash
./set-iface.sh single-tag-range
```

///details | Interface configuration
    type: example

```srl
--{ + running }--[  ]--
A:srl1# info interface ethernet-1/1
    interface ethernet-1/1 {
        admin-state enable
        vlan-tagging true
        subinterface 0 {
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
```

///

Running the pinger:

```{.bash .no-select}
sudo ./ping.sh all
```

<div class="embed-result">
```{.diff .no-select .no-copy}
- Ping to 10.1.0.2 (no tag) failed.
+ Ping to 10.1.1.2 (single tag VID: 10) was successful.
+ Ping to 10.1.2.2 (single tag VID: 11) was successful.
+ Ping to 10.1.3.2 (double tag outer VID: 12, inner VID: 13) was successful.
```
</div>

Let's look at the packet diagram to see what happened:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":4,"zoom":2,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-vlan-handling-lab/diagrams/vlan.drawio"}'></div>

Remember that the `single-tagged-range` VLAN encapsulation type doesn't pop or push any VLAN tags on ingress or egress? It just classifies frames on ingress and then leaves them intact. This is exactly what we see here. The `bridge-1` network instance will accept all the frames with VLAN IDs from `10` to `15` (inclusive) and will forward them to the `ethernet-1/10` interface without any modifications.

But frames without VLAN tags will be dropped, since they don't match the configured VLAN range.

### Scenario 4: Untagged VLAN

One last for today. Let's configure the `ethernet-1/1` interface of both SR Linux switches with the `untagged` VLAN encapsulation type. This configuration will accept only untagged frames and will drop all the tagged frames. Let's apply this configuration:

```bash
./set-iface.sh untagged
```

///details | Interface configuration
    type: example

```srl
--{ + running }--[  ]--
A:srl1# info interface ethernet-1/1
    interface ethernet-1/1 {
        admin-state enable
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
```

///

Running the pinger:

```{.bash .no-select}
sudo ./ping.sh all
```

<div class="embed-result">
```{.diff .no-select .no-copy}
+ Ping to 10.1.0.2 (no tag) was successful.
- Ping to 10.1.1.2 (single tag VID: 10) failed.
- Ping to 10.1.2.2 (single tag VID: 11) failed.
- Ping to 10.1.3.2 (double tag outer VID: 12, inner VID: 13) failed.
```
</div>

Let's look at the packet diagram to see what happened:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":5,"zoom":2,"highlight":"#0000ff","nav":false,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srlinux-vlan-handling-lab/diagrams/vlan.drawio"}'></div>

## Packet Captures

Containerlab makes it super easy to capture and visualise frames as they pass through any of the interfaces of the nodes in the lab. Here is Roman showing how to do it based on the lab we just went through:

<div class="iframe-container">
<iframe width="100%" src="https://www.youtube.com/embed/qojiQ38troc" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>

## Summary

As you can see, SR Linux VLAN handling is not quite the same as you might be used to coming from Cisco. It is more akin to Juniper's way of doing things, but with a pedigree of SR OS. It is flexible, scalable and reasonable if you think about switching as a separate entity from the interfaces.

We hope this definitive guide to VLANs on SR Linux will help you navigate the VLAN configuration jungle no matter what your previous experience is. With a [lab][lab] at your disposal, you can try out various VLAN configurations and see how they affect the traffic between the clients.

The handy diagram in the TLDR section in the beginning of this post summarizes the VLAN handling on SR Linux in both directions and will surely help you to understand the way VLANs are handled on SR Linux.

Keep the man happy, this is all for today.

![cisco-man-happy](https://gitlab.com/rdodin/pics/-/wikis/uploads/001ed6308bd7ea9657ac8850facbbb31/image.png){: .img-shadow .img-center style="width:80%"}

///details | Psst... One more thing.
Wanted to know how Cisco/Arista VLAN configuration is mapped to the SR Linux's VLAN concepts? Here is a [deep dive on that](./srl-eos-vlans.md).
///

[client-config]:https://github.com/srl-labs/srlinux-vlan-handling-lab/blob/main/configs/client.sh
[lab]: https://github.com/srl-labs/srlinux-vlan-handling-lab
[srl-startup]: https://github.com/srl-labs/srlinux-vlan-handling-lab/blob/main/configs/srl.cfg
[twitter-discuss]: https://twitter.com/ntdvps/status/1747400112484040792
[linkedin-discuss]: https://www.linkedin.com/feed/update/urn:li:activity:7153167033734475776/

[^1]: Untagged interface configuration also accepts frames with VLAN ID 0, aka null tag. We are not covering null tag cases here, since they are not that relevant.
[^2]: Outer VLAN ID is 12, inner VLAN ID is 13.
[^3]: The `any` keyword will change to `optional` in SR Linux 24.3.1 release. The configuration auto-upgrade should handle this for you if you are upgrading from an older release.

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
