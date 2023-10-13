---
comments: true
---

# EVPN-MH Configuration

In this part, we will focus on configuration tasks required to enable multihoming in our fabric.

EVPN-MH configuration touches Ethernet Segment (ES) peers. ES peer is a leaf that has links to a multihomed host. In our case `leaf1` and `leaf2` are ES peers, because CE1 is connected to both of them.

The following items need to be configured on ES Peers:

+ A LAG and member interfaces
+ Ethernet segment
+ MAC-VRF interface mapping

Remember that the lab is pre-configured with [fabric underlay][fabric-underlay], [EVPN][evpn], and a [MAC-VRF][mac-vrf] for CE-to-CE L2 reachability.

## LAG

For an all-active multihoming SR Linux nodes need to be configured with a LAG interface facing the CE.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":3,"zoom":2.5,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/images/evpn-mh.drawio"}'></div>
  <figcaption>LAG between PEs and CE</figcaption>
</figure>

The following configuration snippet can be pasted in the CLI of `leaf1` and `leaf2` to create a logical LAG interface `lag1` with LACP support.

```srl
enter candidate
    /interface lag1 {
        admin-state enable
        vlan-tagging true
        subinterface 0 {
            type bridged
            vlan {
                encap {
                    untagged {
                    }
                }
            }
        }
        lag {
            lag-type lacp
            member-speed 10G
            lacp {
                interval SLOW
                lacp-mode ACTIVE
                admin-key 11
                system-id-mac 00:00:00:00:00:11
                system-priority 11
            }
        }
    }
commit now
```

The `lag1` interface was created with `vlan-tagging` enabled that allows multiple subinterfaces with different VLAN tags to use it. This way each subinterface can be connected to a different MAC-VRF.  
Subinterface `0` has been added to `lag1` with `untagged` encapsulation.

The `lag type` can be LACP or static. For this lab we chose to use LACP for our LAG, so LACP parameters must match in all ES-peer nodes - leaf1 and leaf2.

And finally, we bind the physical interface(s) to the logical LAG interface to complete the LAG configuration part.

```srl
enter candidate
    /interface ethernet-1/1 {
        admin-state enable
        ethernet {
            aggregate-id lag1
        }
    }
commit now
```

As shown in config snippet above, the physical interface `ethernet-1/1` will be part of `lag1` interface on both leaf1 and leaf2 nodes.

All PEs that provide multihoming to a CE must be similarly configured with the lag and interface configurations.

## Ethernet Segment

When a CE device is connected to one or more PEs via a set of Ethernet links, then this set of Ethernet links constitutes an "Ethernet segment". This is a key concept of EVPN Multihoming.

In SR Linux, the `ethernet segments` are configured under the `system network-instance protocols` context.

```srl title="ES configuration applied on both leaf1 and leaf2"
enter candidate
/system network-instance protocols 
    evpn {
        ethernet-segments {
            bgp-instance 1 {
                ethernet-segment ES-1 {
                    admin-state enable
                    esi 01:11:11:11:11:11:11:00:00:01
                    multi-homing-mode all-active
                    interface lag1 {
                    }
                }
            }
        }
    }
    bgp-vpn {
        bgp-instance 1 {
        }
    }
commit now
```

The `ethernet-segment` is created with a name ES-1 under `bgp-instance 1` with the `all-active` mode.

For a multihomed site, each Ethernet segment (ES) is identified by a unique non-zero identifier called an Ethernet Segment Identifier (ESI).  
An ESI is encoded as a 10-octet integer in line format with the most significant octet sent first.

The `esi` and `multi-homing-mode` must match in all ES peers. At last, we assign the interface `lag1` to ES-1.

Besides the ethernet segments, `bgp-vpn` is also configured with `bgp-instance 1` to use the BGP information (RT/RD) for the ES routes exchanged in EVPN to enable multihoming.

## MAC-VRF Interface

Typically, an L2 multi-homed LAG subinterface needs to be associated with a MAC-VRF.

```srl title="MAC-VRF interface configuration applied on both leaf1 and leaf2"
enter candidate
    /network-instance mac-vrf-1 {
        interface lag1.0 {
        }
    }
commit now
```

To provide the load-balancing for all-active multihoming segments, set `ecmp` to the expected number of leaves (PE) serving the CE[^1].  
Since we have two leaves connected to CE1, we set `ecmp 2`.

```srl title="MAC-VRF ECMP configuration applied on all, leaf1, leaf2 and leaf3."
enter candidate
    /network-instance mac-vrf-1 {
        protocols {
            bgp-evpn {
                bgp-instance 1 {
                    ecmp 2
                }
            }
    }
commit now
```

The entire MAC-VRF with VXLAN configuration is covered [here](../../l2evpn/evpn.md#mac-vrf).

This completes an all-active EVPN-MH configuration. Now let's have a look at the multihomed CE1 host and its configuration.

## Customer Edge Device

To create a multihomed connection, our CE1 emulated host has a `bond0` interface configured with interfaces `eth1` and `eth2` underneath. Similar to the SR Linux part, it is configured with LACP (802.3ad).

The single-homed CE2 has multiple interfaces to a single leaf3 switch. These interfaces are placed in different VRFs so that CE2 can simulate multiple remote endpoints.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":5,"zoom":2.5,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/images/evpn-mh.drawio"}'></div>
  <figcaption>Multiple IP hosts in CE2</figcaption>
</figure>

Below are the CE interface configurations that are executed by containerlab during the deployment.

=== "ce1"
    ```yaml
    --8<-- "https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/configs/ce1-config.sh"
    ```
=== "ce2"
    ```yaml
    --8<-- "https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/configs/ce2-config.sh"
    ```

This is primarily to get better entropy for load balancing, so you can observe CE1 sending/receiving packets to/from both PEs, as shown below.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":4,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/images/evpn-mh.drawio"}'></div>
  <figcaption>CE connections to mac-vrf-1 network instance</figcaption>
</figure>

Now, let's see how EVPN-MH control plane works and which commands you can use to verify the configuration.

[fabric-underlay]: https://learn.srlinux.dev/tutorials/l2evpn/fabric/
[evpn]: https://learn.srlinux.dev/tutorials/l2evpn/evpn/
[mac-vrf]: https://learn.srlinux.dev/tutorials/l2evpn/evpn/#mac-vrf

[^1]: An Ethernet segment can span up to four provider edge (PE) routers.

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
