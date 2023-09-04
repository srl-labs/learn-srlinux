---
comments: true
tags:
  - multi-homing
  - ethernet-segments
---

In this part, we'll focus on the configurations. The target is to get the SR Linux fabric configured with the necessary configuration items for a multi-homed CE.

The following items must be configured in all ES peers(PEs) that the "ce1" is connected. It's leaf1 and leaf2 in this tutorial.

+ A LAG and member interfaces
+ Ethernet segment
+ MAC-VRF interface association

Remember that the lab is pre-configured with [fabric underlay][fabric-underlay], [EVPN][evpn], and a [MAC-VRF][mac-vrf] for CE-to-CE L2 reachability.

### LAG Configuration

LAG is required for the all-active mode but can be skipped for single-active cases.

In this example, a LAG is created for an all-active multi-homing mode. The target setup between a multihomed CE and PEs is shown below.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":3,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/evpn-mh01.drawio"}'></div>
  <figcaption>LAG between PEs and CE</figcaption>
</figure>


The configuration snippet below shows a LAG with a subinterface and its LACP settings. 
>The same configuration applies for both leaf1 and leaf2.

```
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

The lag1 is created with the `vlan-tagging` enabled so that this LAG can have multiple subinterfaces with different VLAN tags. In this way, each subinterface can be attached to a different MAC-VRF. The subinterface 0 is created here with `untagged` (tag0) encapsulation.

The `lag type` can be LACP or static. Here it is configured as LACP, so its parameters must match in all nodes, leaf1 and leaf2 in this example.

And associate the physical interface(s) with the LAG to complete this part. 

```
enter candidate
    /interface ethernet-1/1 {
        admin-state enable
        ethernet {
            aggregate-id lag1
        }
    }
commit now
```

All PEs that offer a multi-homing to a CE must be configured similarly with the lag and interface configurations.

### Ethernet Segment Configuration

In SR Linux, the `ethernet-segments` are configured under [ system network-instance protocols evpn ] context.
>The same configuration applies for both leaf1 and leaf2.
```
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

An `ethernet-segment` is created with a name (ES-1) under the BGP-instance 1. The ES identifier (`esi`) and the `multi-homing-mode` must match in all leaf routers. At last, we associate the `lag1` interface with the ES-1.

Besides the ethernet segments, the `bgp-vpn` with `bgp-instance 1` is configured to get the ES routes' BGP information (RT/RD).

### MAC-VRF Interface Configuration

Typically, an L2 multi-homed LAG subinterface needs to be associated with a MAC-VRF.
>The same configuration applies for both leaf1 and leaf2.

```
enter candidate
    /network-instance mac-vrf-1 {
        interface lag1.0 {
        }
    }
commit now
```

Also, to enable load-balancing to all-active multi-homing segments, set ecmp to the expected number of leaf (PE) that serves the CE, 2 in this example.
>An ethernet segment can be distrubuted up to 4 PE.

```
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

The whole MAC-VRF with VXLAN configuration is covered [here](https://learn.srlinux.dev/tutorials/l2evpn/evpn/#mac-vrf).

With this, an all-active EVPN-MH configuration is completed.

Let's see the configuration example on the CE side.

## CE (Alpine Linux) Configuration

The ce1 has multi-homed bond0 with slave interfaces eth1 and eth2. Similar to SR Linux part, it's configured with LACP (802.3ad). 

The single homed ce2 has multiple interfaces to a single PE (leaf3). Those interfaces are placed in different VRFs so that ce2 can simulate multiple remote endpoints.

=== "ce1"
    ```yaml
    --8<-- "https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/configs/ce1-config.sh"
    ```
=== "ce2"
    ```yaml
    --8<-- "https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/configs/ce2-config.sh"
    ```

This is primarily to get better enthropy for load-balancing so that you can observe ce1 sends/receives packets to/from both PEs as depicted below.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":4,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/images/evpn-mh.drawio"}'></div>
  <figcaption>CE connections to mac-vrf-1 network instance</figcaption>
</figure>

Verify the configurations with the next chapter!

[fabric-underlay]: https://learn.srlinux.dev/tutorials/l2evpn/fabric/
[evpn]: https://learn.srlinux.dev/tutorials/l2evpn/evpn/
[mac-vrf]: https://learn.srlinux.dev/tutorials/l2evpn/evpn/#mac-vrf
[topology]: https://github.com/srl-labs/learn-srlinux/blob/main/docs/tutorials/evpn-mh/
[configs]: https://github.com/srl-labs/learn-srlinux/blob/main/docs/tutorials/evpn-mh/leaf1.cfg
[path-evpn-mh]: https://github.com/srl-labs/learn-srlinux/blob/main/docs/tutorials/evpn-mh

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>