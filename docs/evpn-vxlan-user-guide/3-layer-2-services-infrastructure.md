## 3.1. mac-vrf network instance
The network instance type mac-vrf functions as a broadcast domain. Each mac-vrf network instance builds a bridge table composed of MAC addresses that can be learned via the data path on network instance interfaces or via static configuration. You can configure the size of the bridge table for each mac-vrf network instance, as well as the aging for dynamically learned MAC addresses and other parameters related to the bridge table.

The mac-vrf network instance type features a MAC duplication mechanism that monitors MAC address moves across network-instance interfaces and across interfaces.

### 3.1.1. MAC selection
Each mac-vrf network instance builds a bridge table to forward Layer 2 frames based on a MAC address lookup. The SR Linux selects the MAC addresses to be sent for installation to the line card (XDP), based on the following priority:

- Local application MACs (for example, IRB interface MACs)
- Local static MACs
- EVPN static MACs
- Local duplicate MACs
- Learned / EVPN-learned MACs

### 3.1.2. MAC duplication detection and actions
MAC duplication is the mechanism used by SR Linux for loop prevention. MAC duplication monitors MAC addresses that move between subinterfaces. It consists of detection, actions, and process restart.

##### 3.1.2.1. MAC duplication detection
Detection of duplicate MAC addresses is necessary when extending broadcast domains to multiple leaf nodes. SR Linux supports a MAC duplication mechanism that monitors MAC address moves across network instance interfaces.

A MAC address is considered a duplicate when its number of detected moves is greater than a configured threshold within a configured time frame where the moves are observed. Upon exceeding the threshold, the system holds on to the prior local destination of the MAC and executes an action.

##### 3.1.2.2. MAC duplication actions
The action taken upon detecting one or more MAC addresses as duplicate on a subinterface can be configured for the mac-vrf network instance or for the subinterface. The following are the configurable actions:

- **oper-down**: When one or more duplicate MAC addresses are detected on the subinterface, the subinterface is brought operationally down.
- **blackhole**: Upon detecting a duplicate MAC on the subinterface, the MAC will be blackholed.
- **stop learning**: Upon detecting a duplicate MAC on the subinterface, the MAC address will not be relearned anymore on this or any subinterface. This is the default action for a mac-vrf network instance.
- **use-network-instance-action**: (Available for subinterfaces only) Use the action specified for the mac-vrf network instance. This is the default action for a subinterface.

##### 3.1.2.3. MAC duplication process restarts
When at least one duplicate MAC address is detected, the duplicate MAC addresses are visible in the state datastore and can be displayed with the info from state mac-duplication duplicate-entries CLI command. See [Displaying bridge table information](#35-displaying-bridge-table-information).

This command also displays the hold-down time for each duplicate MAC address. Once the hold-down-time expires for all of the duplicate MAC addresses for the subinterface, the oper-down or stop-learning action is cleared, and the subinterface is brought operationally up or starts learning again.

### 3.1.3. Bridge table configuration
The bridge table, its MAC address limit, and maximum number of entries can be configured on a per mac-vrf or per-subinterface basis.

When the size of the bridge table exceeds its maximum number of entries, the MAC addresses are removed in reverse order of the priority listed in [MAC selection](#311-mac-selection).

You can also configure aging for dynamically learned MAC addresses and other parameters related to the bridge table.

## 3.2. Interface extensions for Layer 2 services
To accommodate the Layer 2 services infrastructure, SR Linux interfaces support the following features:

Traffic classification and ingress/egress mapping actions
Subinterfaces of type routed and bridged

### 3.2.1. Traffic classification and ingress/egress mapping actions
On mac-vrf network instances, traffic can be classified based on VLAN tagging. Interfaces where VLAN tagging is set to false or true can be used with mac-vrf network instances.

A default subinterface can be specified, which captures untagged and non-explicitly configured VLAN-tagged frames in tagged subinterfaces.

Within a tagged interface, a default subinterface (vlan-id value is set to any) and an untagged subinterface can be configured. This kind of configuration behaves as follows:

- The vlan-id any subinterface captures untagged and non-explicitly configured VLAN-tagged frames.
- The untagged subinterface captures untagged and packets with tag0 as outermost tag.

When vlan-id any and untagged subinterfaces are configured on the same tagged interface, packets for unconfigured VLANs go to the vlan-id any subinterface, and tag0/untagged packets go to the untagged subinterface.

Classification is based on the following:

- All traffic for interfaces where VLAN tagging is set to false, regardless of existing VLAN tags.
- Single outermost tag for tagged interfaces where VLAN tagging is set to true. Only Ethertype 0x8100 is considered for tags; other Ethertypes are treated as payload.

The following ingress and egress VLAN mapping actions are supported:

- At ingress, pop the single outermost tag (tagged interfaces), or perform no user-visible action (untagged interfaces).
- At egress, push a specified tag at the top of the stack (tagged interfaces) or perform no user-visible action (untagged interfaces).
- If the vlan-id value is set to any or the subinterface uses an untagged configuration, no tag is popped at ingress or pushed at egress.  
  There is one exception: On a subinterface that uses an untagged configuration, if a received packet has tag0 as its outermost tag, the subinterface pops tag0.

Dot1p is not supported.

### 3.2.2. Routed and bridged subinterfaces
SR Linux subinterfaces can be specified as type routed or bridged:

- Routed subinterfaces can be assigned to a network-instance of type mgmt, default, or ip-vrf.
- Bridged subinterfaces can be assigned to a network-instance of type mac-vrf.

Routed subinterfaces allow for configuration of IPv4 and IPv6 settings, and bridged subinterfaces allow for configuration of bridge table and VLAN ingress/egress mapping.

Bridged subinterfaces do not have MTU checks other than the interface-level MTU (port MTU) or the value set with the l2-mtu command. The IP MTU is only configurable on routed subinterfaces.

## 3.3. IRB interfaces
Integrated routing and bridging (IRB) interfaces enable inter-subnet forwarding. Network instances of type mac-vrf are associated with a network instance of type ip-vrf via an IRB interface. See Figure 1 for an illustration of the relationship between mac-vrf and ip-vrf network instances.

On SR Linux, IRB interfaces are named irbN, where N is 0 to 255. Up to 4095 subinterfaces can be defined under an IRB interface. An ip-vrf network instance can have multiple IRB subinterfaces, while a mac-vrf network instance can refer to only one IRB subinterface.

IRB subinterfaces are type routed. They cannot be configured as type bridged.

IRB subinterfaces operate in the same way as other routed subinterfaces, including support for the following:

- IPv4 and IPv6 ACLs
- DSCP based QoS (input and output classifiers and rewrite rules)
- Static routes and BGP (IPv4 and IPv6 families)
- IP MTU (with the same range of valid values as Ethernet subinterfaces)
- All settings in the subinterface/ipv4 and subinterface/ipv6 containers. For IPv6, the IRB subinterface also gets an IPv6 link local address
- BFD
- Subinterface statistics

IRB interfaces do not support sFlow, VLAN tagging, or interface statistics.

### 3.3.1. Using ACLs with IRB interfaces and Layer 2 subinterfaces
Note the following when using Access Control Lists with an IRB interface or Layer 2 subinterface:

- Input ACLs associated to Layer 2 subinterfaces match all the traffic entering the subinterface, including Layer 2 switched traffic or Layer 3 traffic forwarded to the IRB.
- Input ACLs associated to IRB subinterfaces only match Layer 3 traffic; that is, traffic with a MAC destination address matching the IRB MAC address.
- The same ACL can be attached to a Layer 2 subinterface and an IRB subinterface in the same service. In this case, there are two ACL instances, one for the IRB with higher priority and another one for the bridged traffic. Routed traffic matches the higher priority instance entries of the ACL.
- The same ACL can be attached to IRB subinterfaces and Layer 2 subinterfaces if both belong to different services.
- On 7220 IXR-D1, D2, and D3 systems, egress ACLs, unlike ingress ACLs, cannot match both routed and switched traffic when a Layer 2 IP ACL is attached.
- Received traffic on a mac-vrf is automatically discarded if the MAC source address matches the IRB MAC address, unless the MAC is an anycast gateway MAC.
- Packet capture filters show the Layer 2 subinterface for switched traffic and the IRB interface for routed traffic.

## 3.4. Layer 2 services configuration
The examples in this section show how to configure a mac-vrf network instance, bridged interface, and IRB interface.

### 3.4.1. mac-vrf network instance configuration example
The following example configures a mac-vrf network instance and settings for the bridge table. The bridge table is set to a maximum of 500 entries. Learned MAC addresses are aged out of the bridge table after 600 seconds.

MAC duplication detection is configured so that a MAC address is considered a duplicate when its number of detected moves across network instance interfaces is greater than 3 over a 5-minute interval. In this example, the MAC address is blackholed. After the hold-down-time of 3 minutes, the MAC address is flushed from the bridge table, and the monitoring process for the MAC address is restarted.

The example includes configuration for a static MAC address in the bridge table.

The mac-vrf network instance is associated with a bridged interface and an IRB interface.

Example:
```
--{ candidate shared default }--[  ]--
 network-instance mac-vrf-1 {
        description "Sample mac-vrf network instance" 
        type mac-vrf
        admin-state enable
        interface ethernet-1/1.1 {
        }
        interface irb1.1 {
        }
        bridge-table {
            mac-limit {
                mac-limit 500
            }
            mac-learning {
                admin-state enable
                aging {
                    admin-state enable
                    age-time 600
                }
            }
            mac-duplication {
                admin-state enable
                monitoring-window 5
                num-moves 3
                hold-down-time 3
                action blackhole
            static-mac {
                address [mac1
                }
            }
            }
        }
 }
```

### 3.4.2. Bridged subinterface configuration example
The following example configures the bridged subinterface that is associated with the mac-vrf in the previous example.
```
--{ candidate shared default }--[  ]--
 interface ethernet-1/1 {
        admin-state enable
        subinterface 1 {
            admin-state enable
            type bridged
            vlan {
                encap {
                    single-tagged {
                        vlan-id 10
                        }
                    }
                }
            }
        }
 }
```

The vlan-id value can be configured as a specific valid number or with the keyword any, which means any frame that does not hit the vlan-id configured in other subinterfaces of the same interface is classified in this subinterface.

In the following example, the vlan encap untagged setting is enabled for subinterface 1. This setting allows untagged frames to be captured on tagged interfaces.

For subinterface 2, the vlan encap single-tagged vlan-id any setting allows non-configured VLAN IDs and untagged traffic to be classified to this subinterface.

With the vlan encap untagged setting on one subinterface, and the vlan encap single-tagged vlan-id any setting on the other subinterface, traffic enters the appropriate subinterface; that is, traffic for unconfigured VLANs goes to subinterface 2, and tag0/untagged traffic goes to subinterface 1.
```
--{ candidate shared default }--[  ]--
 interface ethernet-1/2
  vlan-tagging true
  subinterface 1 {
    type bridged
    vlan {
      encap {
        untagged
             }
         }
  subinterface 2 {
    type bridged
    vlan {
      encap {
        single-tagged {
          vlan-id any
      } 
```
### 3.4.3. IRB interface configuration example
The following example configures an IRB interface. The IRB interface is operationally up when its admin-state is enabled, and its IRB subinterfaces are operationally up when associated with mac-vrf and ip-vrf network instances. At least one IPv4 or IPv6 address must be configured for the IRB subinterface to be operationally up.
```
--{ candidate shared default }--[  ]--
 interface irb1 {
        description IRB_Interface
        admin-state enable
        subinterface 1 {
            admin-state enable
            ipv4 {
                address 172.16.1.1/24 {
                }
            }
        }
    }
```

## 3.5. Displaying bridge table information
You can display information from the bridge table of a mac-vrf network instance using show commands and info from state command.

Examples:

To display a summary of the bridge table contents for the mac-vrf network instances configured on the system:
```
# show network-instance * bridge-table mac-table summary
------------------------------------------------------------------------------------
Network-Instance Bridge table summary
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
Name                            : mac-vrf-1
Irb mac                         :   1 Total   1 Active 
Static macs                     :  19 Total  19 Active
Duplicate macs                  :  10 Total  10 Active
Learnt macs                     :  15 Total  14 Active
Total macs                      :  45 Total  44 Active
Maximum-Entries                 : 200
Warning Threshold Percentage    :  95% (190)
Clear Warning                   :  90% (180)
------------------------------------------------------------------------------------
Name                            : mac-vrf-2
Irb mac                         :   1 Total   1 Active 
Static macs                     :   1 Total   1 Active
Duplicate macs                  :  10 Total  10 Active
Learnt macs                     :  15 Total  14 Active
Total macs                      :  27 Total  26 Active
Maximum-Entries                 : 200
Warning Threshold Percentage    :  95% (190)
Clear Warning                   :  90% (180)
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
Total Irb macs             : 2  Total 2 Active
Total Static macs          : 29 Total 29 Active 
Total Duplicate macs       : 20 Total 20 Active
Total Learnt macs          : 30 Total 29 Active
Total Macs                 : 81 Total 80 Active
------------------------------------------------------------------------------------
```
To list the contents of the bridge table for a mac-vrf network instance:
```
# show network-instance mac-vrf-1 bridge-table mac-table all
------------------------------------------------------------------------------------
Mac-table of network instance mac-vrf-1
------------------------------------------------------------------------------------
+------------------+--------------+----------+---------+------+-----+-----------------------+
| Mac              |Destination   |Dest-Index|Type     |Active|Aging|Last-update   |
+==================+==============+==========+=========+======+=====+=======================+
| 00:00:00:00:00:01|ethernet-1/1.1|65        |Learnt   |True  |256  |2020-2-3T3:37:26|
| 00:00:00:00:00:02|        irb1.1| 0        |Irb      |True  |N/A  |2019-2-1T3:37:26|
| 00:00:00:00:00:03|     blackhole| 0        |Duplicate|True  |N/A  |2019-2-1T3:37:26|
| 00:00:00:00:00:04|ethernet-1/1.2|66        |Learnt   |True  |256  |2019-2-1T3:37:26|
------------------------------------------------------------------------------------
Total Irb macs             : 2  Total 2 Active
Total Static macs          : 0  Total 0 Active 
Total Duplicate macs       : 1  Total 1 Active
Total Learnt macs          : 3  Total 3 Active
Total Macs                 : 6  Total 6 Active
------------------------------------------------------------------------------------
```
To display information about a specific MAC address in the bridge table:
```
# show network-instance * bridge-table mac-table mac 00:00:00:00:00:01
------------------------------------------------------------------------------------
Mac-table of network instance mac-vrf-1
------------------------------------------------------------------------------------
Mac                     : 00:00:00:00:00:01
Destination             : ethernet-1/1.1
Destination Index       : 65
Type                    : Learnt
Programming status      : Success | Failed | Pending
Aging                   : 250 seconds
Last update             : 2019-12-13T23:37:26.000
Duplicate Detect Time   : N/A
Hold-down-time-remaining: N/A
------------------------------------------------------------------------------------
```
To display the duplicate MAC address entries in the bridge table:
```
# show network-instance * bridge-table mac-duplication duplicate-entries 
------------------------------------------------------------------------------------
Mac-duplication in network instance mac-vrf-1
------------------------------------------------------------------------------------
Admin-state             : Enabled
Monitoring window       : 3 minutes
Number of moves allowed : 5
Hold-down-time          : 10 seconds
Action                  : Stop Learning
------------------------------------------------------------------------------------
Duplicate entries in network instance mac-vrf-1
------------------------------------------------------------------------------------
+------------------+----------------+----------+------------------------+--------------------------
| Duplicate mac    | Destination    |Dest-Index| Detec Time             | Hold down time remaining 
+==================+================+==========+========================+==========================
| 00:00:00:00:00:01|ethernet-1/1.1  |65        |2019-12-13T23:37:26.000 | 6  
| 00:00:00:00:00:02|ethernet-1/1.1  |65        |2019-12-13T23:37:26.000 | 6  
| 00:00:00:00:00:03|ethernet-1/1.1  |65        |2019-12-13T23:37:26.000 | 6   
------------------------------------------------------------------------------------
Total Duplicate macs       : 3  Total 3 Active
------------------------------------------------------------------------------------
```
You can display the duplicate/learned/static MAC address entries in the bridge table using info from state commands. For example, the following command displays the duplicate MAC entries:
```
# info from state network-instance * bridge-table mac-duplication duplicate-entries mac * | as table
+--------------------+---------------------+---------+------------------------+-------------------------+
| Network-instance   | Duplicate-mac       | Dest-idx| Detect-time            | Hold-down-time-remaining|
+====================+=====================+=========+========================+=========================+
| red                | 00:00:00:00:00:01   |       1 | 2019-12-13T23:37:26.000|                      10 |
| red                | 00:00:00:00:00:02   |       2 | 2019-12-13T23:37:26.000|                      20 |
| red                | 00:00:00:00:00:03   |       3 | 2019-12-13T23:37:26.000|                      90 |
| blue               | 00:00:00:00:00:04   |       4 | 2019-12-13T23:37:26.000|                      90 |
| blue               | 00:00:00:00:00:05   |       0 | 2019-12-13T23:37:26.000|                      90 |
+--------------------+---------------------+---------+------------------------+-------------------------+
```
The following command displays the learned MAC entries in the table:
```
# info from state network-instance * bridge-table mac-learning learnt-entries mac * | as table
+------------------+------------------+--------------+---------+------------------------+
| Network-instance | Learnt-mac       | Dest         | Aging   | Last-update            |
+==================+==================+==============+=========+========================+
| red              | 00:00:00:00:00:01|ethernet-1/1.1| 300     | 2019-12-13T23:37:26.000|
| red              | 00:00:00:00:00:02|ethernet-1/1.1| 212     | 2019-12-13T23:37:26.000|
| red              | 00:00:00:00:00:03|ethernet-1/1.2| 10      | 2019-12-13T23:37:26.000|
| blue             | 00:00:00:00:00:04|ethernet-1/1.3| 10      | 2019-12-13T23:37:26.000|
| blue             | 00:00:00:00:00:05|ethernet-1/1.4| 20      | 2019-12-13T23:37:26.000|
+------------------+------------------+--------------+---------+------------------------+
```
The following command displays the static MAC entries in the table:
```
# info from state network-instance * bridge-table static-mac mac * | as table
+------------------+------------------+--------------+
| Network-instance | Static-mac       | Dest         |
+==================+==================+==============+
| red              | 00:00:00:00:00:01|ethernet-1/1.1| 
| red              | 00:00:00:00:00:02|        irb1.1|
| red              | 00:00:00:00:00:03|     blackhole|
| blue             | 00:00:00:00:00:04|ethernet-1/1.3|
| blue             | 00:00:00:00:00:05|ethernet-1/1.4|
+------------------+------------------+--------------+
```
## 3.6. Deleting entries from the bridge table
The SR Linux features commands to delete duplicate or learned MAC entries from the bridge table. For a mac-vrf or subinterface, you can delete all MAC entries, MAC entries with a blackhole destination, or a specific MAC entry.

Examples:

The following example clears MAC entries in the bridge table for a mac-vrf network instance that have a blackhole destination:
```
--{ candidate shared default }--[  ]-- 
# tools network-instance mac-vrf-1 bridge-table mac-duplication delete-blackhole-
macs
```
The following example deletes a specified learned MAC address from the bridge table for a mac-vrf network instance:
```
--{ candidate shared default }--[  ]-- 
# tools network-instance mac-vrf-1 bridge-table mac-learning delete-
mac 00:00:00:00:00:04
```
The following example clears all duplicate MAC entries in the bridge table for a subinterface:
```
--{ candidate shared default }--[  ]-- 
# tools interface ethernet-1/1.1 bridge-table mac-duplication delete-all-macs
```

## 3.7. Server aggregation configuration example
Figure 4 shows an example of using MAC-VRF network-instances to aggregate servers into the same subnet.

In this example, Leaf-1 and Leaf-2 are configured with MAC-VRF instances that aggregate a group of servers. These servers are assigned IP addresses in the same subnet and are connected to the Leaf default network-instance by a single IRB subinterface. The servers use a PE-CE BGP session with the IRB IP address to exchange reachability.

Using the MAC-VRF with an IRB subinterface saves routed subinterfaces on the default network-instance; only one routed subinterface is needed, as opposed to one per server.

<figure>
  <img id="fig4" src="https://infocenter.nokia.com/public/SRLINUX213R1A/topic/com.srlinux.evpnl2l3/html/graphics/sw4058.gif"/>
  <figcaption>Figure 4: Server aggregation example </figcaption>
</figure>

In this example:

1. TORs peer (eBGP) to 2 or 4 RIFs
2. MAC-VRF 20 is defined in TORs with an IRB interface with IPv4/IPv4 addresses. DHCP relay is supported on IRB subinterfaces.
3. The following Layer 2 features are implemented or loop and MAC duplication protection:
    * MAC duplication with oper-down or blackhole actions configured on the bridged subinterfaces
    * Storm control for BUM traffic on bridged subinterfaces

This example uses the following features:

- MAC-VRF with bridge subinterfaces and IRB subinterfaces to the default network-instance
- PE-CE BGP sessions for IPv4 and IPv6 address families
- MAC duplication with oper-down or blackhole actions configured on the bridged subinterfaces
- Storm control for BUM traffic on bridged subinterfaces

### 3.7.1. Configuration for server aggregation example
The following shows the configuration of Leaf-1 in Figure 4 and its BGP session via IRB to server 1. Similar configuration is used for other servers and other TORs.
```
--{ [FACTORY] + candidate shared default }--[ interface * ]--
A:Leaf-1# info
    interface ethernet-1/1 {
        description tor1-server1
        vlan-tagging true
        subinterface 1 {
            type bridged
            vlan {
                encap {
                    single-tagged {
                        vlan-id 100
                    }
                }
            }
        }
    }
 
// Configure an IRB interface and sub-interface that will connect
 the MAC-VRF to the existing default network-instance.
 
--{ [FACTORY] + candidate shared default }--[ interface irb* ]--
A:Leaf-1# info 
    interface irb1 {
        subinterface 1 {
            ipv4 {
                address 10.0.0.2/24 {
                }
            }
            ipv6 {
                address 2001:db8::2/64 {
                }
            }
        }
    }
 
// Configure the network-instance type mac-vrf 
and associate the bridged and irb interfaces to it.
 
--{ [FACTORY] + candidate shared default }--[ network-instance MAC-VRF-1 ]--
A:Leaf-1# info
    type mac-vrf
    admin-state enable
    interface ethernet-1/1.1 {
    }
    interface irb1.1 {
    }
 
// Associate the same IRB interface to the network-
instance default and configure the BGP IPv4 and IPv6 neighbors to DUT1 and DUT3.
 
--{ [FACTORY] + candidate shared default }--[ network-instance default ]--
A:Leaf-1# info
    type default
    admin-state enable
    router-id 2.2.2.2
    interface irb1.1 {
    }
    protocols {
        bgp {
            admin-state enable
            autonomous-system 64502
            router-id 10.0.0.2
            ebgp-default-policy {
                import-reject-all false
            }
            failure-detection {
                enable-bfd true
                fast-failover true
            }
            group leaf {
                admin-state enable
                export-policy pass-all
                ipv4-unicast {
                    admin-state enable
                }
                ipv6-unicast {
                    admin-state enable
                }
                local-as 64502 {
                }
                timers {
                    minimum-advertisement-interval 1
                }
            }
            ipv4-unicast {
                admin-state enable
            }
            ipv6-unicast {
                admin-state enable
            }
            neighbor 10.0.0.1 {
                peer-as 64501
                peer-group leaf
                transport {
                    local-address 10.0.0.2
                }
            }
            neighbor 2001:db8::1 {
                peer-as 64501
                peer-group leaf
                transport {
                    local-address 2001:db8::2
                }
            }
        }
    }
```