---
comments: true
tags:
  - multihoming
  - ethernet-segments
---

In this part, we will focus on configurations. The goal is to configure the SR Linux fabric with the necessary configuration items for a multiomed CE.

The following items need to be configured in all ES peers, which are the PEs that has links to the multi-homed `ce1`. In this tutorial, these are `leaf1` and `leaf2`.

+ A LAG and member interfaces
+ Ethernet segment
+ MAC-VRF interface mapping

Remember that the lab is pre-configured with [fabric underlay][fabric-underlay], [EVPN][evpn], and a [MAC-VRF][mac-vrf] for CE-to-CE L2 reachability.

### LAG Configuration

LAG is required for all-active mode but can be skipped in single-active mode.

In this example, a LAG is created with all-active multihoming mode. The target connection between a CE with multihoming and PEs is shown below.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":3,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/images/evpn-mh.drawio"}'></div>
  <figcaption>LAG between PEs and CE</figcaption>
</figure>

The following configuration snippet shows a LAG with a subinterface and its LACP settings.
>The same configuration applies to both leaf1 and leaf2.

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

The `lag1` was created with `vlan-tagging` enabled, so this LAG can have multiple subinterfaces with different VLAN tags. This way each subinterface can be connected to a different MAC-VRF. Subinterface 0 is created here with `untagged` (tag0) encapsulation.

The `lag type` can be LACP or static. Here it is configured as LACP, so its parameters must match in all nodes, in this example in leaf1 and leaf2.

And connect the physical interface(s) to LAG to complete this part.

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

All PEs that provide multihoming to a CE must be similarly configured with the lag and interface configurations.

### Ethernet Segment Configuration

In SR Linux, the `ethernet segments` are configured under the context [ system network-instance protocols evpn ].
> The same configuration applies to leaf1 and leaf2.

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

An `ethernet-segment` is created with a name ES-1 under `bgp-instance 1`. The `esi` and `multi-homing-mode` must match in all ES peers. At last, we assign the interface `lag1` to ES-1.

Besides the ethernet segments, `bgp-vpn` is also configured with `bgp-instance 1` to use the BGP information (RT /RD) for the ES routes.

### MAC-VRF Interface Configuration

Typically, an L2 multi-homed LAG subinterface needs to be associated with a MAC-VRF.
>The same configuration applies to both leaf1 and leaf2.

```
enter candidate
    /network-instance mac-vrf-1 {
        interface lag1.0 {
        }
    }
commit now
```

To provide load balancing for all-active multihoming segments, set ecmp to the expected number of leaves (PE) serving the CE, 2 in this example.
> An Ethernet segment can span up to four provider edge (PE) routers.

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

The entire MAC-VRF with VXLAN configuration is covered [here](https://learn.srlinux.dev/tutorials/l2evpn/evpn/#mac-vrf).

This completes an all-active EVPN-MH configuration. Now let's look at the configuration example on the CE front.

## CE (Alpine Linux) Configuration

The ce1 has a multi-homed `bond0` with slave interfaces `eth1` and `eth2`. Similar to the SR Linux part, it is configured with LACP (802.3ad).

The single-homed ce2 has multiple interfaces to leaf3. These interfaces are placed in different VRFs so that ce2 can simulate multiple remote endpoints.

=== "ce1"
    ```yaml
    --8<-- "https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/configs/ce1-config.sh"
    ```
=== "ce2"
    ```yaml
    --8<-- "https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/configs/ce2-config.sh"
    ```

This is primarily to get better entropy for load balancing, so you can observe ce1 sending/receiving packets to/from both PEs, as shown below.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":4,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/srl-evpn-mh-lab/main/images/evpn-mh.drawio"}'></div>
  <figcaption>CE connections to mac-vrf-1 network instance</figcaption>
</figure>

Now, let's verify the configurations in the next chapter!

[fabric-underlay]: https://learn.srlinux.dev/tutorials/l2evpn/fabric/
[evpn]: https://learn.srlinux.dev/tutorials/l2evpn/evpn/
[mac-vrf]: https://learn.srlinux.dev/tutorials/l2evpn/evpn/#mac-vrf
[topology]: https://github.com/srl-labs/learn-srlinux/blob/main/docs/tutorials/evpn-mh/
[configs]: https://github.com/srl-labs/learn-srlinux/blob/main/docs/tutorials/evpn-mh/leaf1.cfg
[path-evpn-mh]: https://github.com/srl-labs/learn-srlinux/blob/main/docs/tutorials/evpn-mh

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
