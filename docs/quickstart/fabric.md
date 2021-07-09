<script type="text/javascript" src="https://cdn.jsdelivr.net/gh/hellt/drawio-js@main/embed2.js" async></script>
Prior to configuring EVPN based overlay, a routing protocol needs to be configured in the fabric to dynamically discover and advertise the reachability of all the leaf VXLAN Termination End Point (VTEP) addresses throughout the IP fabric.

With SR Linux, the following routing protocols can be used in the underlay: 

* ISIS
* OSPF
* EBGP

We will use a BGP based fabric design as described in [RFC7938](https://tools.ietf.org/html/rfc7938) due to its simplicity, scalability, and ease of multi-vendor interoperability.

## Leaf-Spine interfaces
Let's start with configuring the IP interfaces on the inter-switch links to ensure L3 connectivity is established. According to our lab topology configuration, and using the `192.168.xx.0/30` network to address the links, we will move towards the following underlay addressing design:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:2,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/learn-srlinux/site/diagrams/quickstart.drawio&quot;}"></div>

On each leaf and spine we will bring up the relevant [interface](ifaces.md) and address its routed [subinterface](ifaces.md#subinterfaces) to achieve L3 connectivity.

We begin with connecting to the CLI of our nodes via SSH[^1]:

```bash
# connecting to leaf1
ssh admin@clab-quickstart-leaf1
```

Then on each node we enter into [candidate configuration mode](cfgmgmt.md#configuration-modes) and proceed with the relevant interfaces configuration.

Let's see the step by step process of an interface configuration on leaf1 with providing the paste-ables snippets for the rest of the nodes

1. Enter the candidate configuration mode to make edits
    ```
    Welcome to the srlinux CLI.
    Type 'help' (and press <ENTER>) if you need any help using this.


    --{ running }--[  ]--
    A:leaf1# enter candidate
    ```
2. The prompt will indicate the changed active mode
    ```
    --{ candidate shared default }--[  ]--                                                                     
    A:leaf1#                                                                                                   
    ```
3. Enter into the interface configuration context
    ```
    --{ candidate shared default }--[  ]--                                                                     
    A:leaf1# interface ethernet-1/49                                                                           
    ```
4. Create a subinterface under the parent interface to configure IPv4 address on it
    ```
    --{ * candidate shared default }--[ interface ethernet-1/49 ]--                                            
    A:leaf1# subinterface 0                                                                                    
    --{ * candidate shared default }--[ interface ethernet-1/49 subinterface 0 ]--                             
    A:leaf1# ipv4 address 192.168.11.1/30                                                                      
    ```
5. Now apply the changes by issuing a `commit now` command
    ```
    --{ * candidate shared default }--[ interface ethernet-1/49 subinterface 0 ipv4 address 192.168.11.1/30 ]--
    A:leaf1# commit now                                                                                        
    All changes have been committed. Leaving candidate mode.
    ```

Below you will find the relevant configuration snippets[^2] for leafs and spine of our fabric which you can paste in the terminal while being in candidate mode.

=== "leaf1"
    ```
    interface ethernet-1/49 {
        subinterface 0 {
            ipv4 {
                address 192.168.11.1/30 {
                }
            }
        }
    }
    ```

=== "leaf2"
    ```
    interface ethernet-1/49 {
        subinterface 0 {
            ipv4 {
                address 192.168.12.1/30 {
                }
            }
        }
    }
    ```
=== "spine1"
    ```
    interface ethernet-1/1 {
        subinterface 0 {
            ipv4 {
                address 192.168.11.2/30 {
                }
            }
        }
    }
    interface ethernet-1/2 {
        subinterface 0 {
            ipv4 {
                address 192.168.12.2/30 {
                }
            }
        }
    }
    ```

Once those snippets are committed to the running configuration with `commit now` command, we can ensure that the changes have been applied:

```
--{ + running }--[  ]--                             
A:spine1# show interface ethernet-1/1               
====================================================
ethernet-1/1 is up, speed 10G, type None
  ethernet-1/1.0 is up
    Network-instance: 
    Encapsulation   : null
    Type            : routed
    IPv4 addr    : 192.168.11.2/30 (static, None)
----------------------------------------------------
====================================================
```

At this moment, the configured interfaces can not be used as they are not yet associated with any [network instance](netwinstance.md). Below we are placing the interfaces to the network-instance `default` that is created automatically created by SR Linux.

=== "leaf1 & leaf2"
    ```
    --{ + candidate shared default }--[  ]--                                                   
    A:leaf1# network-instance default interface ethernet-1/49.0                                
    
    --{ +* candidate shared default }--[ network-instance default interface ethernet-1/49.0 ]--
    A:leaf1# commit now                                                                        
    All changes have been committed. Leaving candidate mode.
    ```

=== "spine1"
    ```
    --{ + candidate shared default }--[  ]--                                                   
    A:spine1# network-instance default interface ethernet-1/1.0                               
    
    --{ +* candidate shared default }--[ network-instance default interface ethernet-1/1.0 ]--
    A:spine1# /network-instance default interface ethernet-1/2.0                               
    
    --{ +* candidate shared default }--[ network-instance default interface ethernet-1/2.0 ]--
    A:spine2# commit now                                                                       
    All changes have been committed. Leaving candidate mode.
    ```

When interfaces are owned by the network-instance default, we can ensure that the basic IP connectivity is working by issuing a ping between the pair of interfaces. For example from `spine1` to `leaf2`:

```
--{ + running }--[  ]--                                     
A:spine1# ping 192.168.12.1 network-instance default        
Using network instance default
PING 192.168.12.1 (192.168.12.1) 56(84) bytes of data.
64 bytes from 192.168.12.1: icmp_seq=1 ttl=64 time=31.4 ms
64 bytes from 192.168.12.1: icmp_seq=2 ttl=64 time=10.0 ms
64 bytes from 192.168.12.1: icmp_seq=3 ttl=64 time=13.1 ms
64 bytes from 192.168.12.1: icmp_seq=4 ttl=64 time=16.5 ms
^C
--- 192.168.12.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3003ms
rtt min/avg/max/mdev = 10.034/17.786/31.409/8.199 ms
```

## EBGP
Since in this exercise the design decision was to use BGP in the data center, we need to configure EBGP peering for the leaf-spine pairs. The EBGP will make sure of advertising the VTEPs across the fabric. The VTEPs will be configured later, in this step we will take care of adding the eBGP peering.

Using the following diagram with ASN/Router ID allocation let's turn this into working configuration:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:3,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/learn-srlinux/site/diagrams/quickstart.drawio&quot;}"></div>

Here is a breakdown of the steps that are needed to configure eBGP on `leaf1` towards `spine1`:

1. **Add BGP protocol to network-instance**  
    Routing protocols are configured under a network-instance context. By adding BGP protocol to the default network-instance we implicitly enable this protocol.  
    ```
    --{ + candidate shared default }--[  ]--       
    A:leaf1# network-instance default protocols bgp
    ```

1. **Assign ASN**  
    The ASN reported to peers when this network-instance opens a BGP session toward another router (unless it is overridden by a local-as configuration).  
    According to the diagram above, `leaf1` has ASN 101.  
    ```
    --{ +* candidate shared default }--[ network-instance default protocols bgp ]--
    A:leaf1# autonomous-system 101
    ```

1. **Assign Router ID**  
    This is the BGP identifier reported to peers when this network-instance opens a BGP session toward another router. This overrides the router-id configuration at the network-instance level.  
    Leaf1 has a router-id of 10.0.0.1.
    ```
    --{ +* candidate shared default }--[ network-instance default protocols bgp ]--
    A:leaf1# router-id 10.0.0.1
    ```

1. **Enable AF**  
    Enable all address families that should be enabled globally as a default for all peers of the BGP instance.  
    When you later configure individual neighbors or groups, you can override the enabled families at those levels.
    ```
    --{ +* candidate shared default }--[ network-instance default protocols bgp ]--
    A:leaf1# ipv4-unicast admin-state enable
    ```

1. **Create export/import policies**  
    The export policy is required to advertise any routes.  
    The "pass-all-bgp" export policy matches and accepts all BGP routes, while rejecting all non-BGP routes.
    ```
    --{ +* candidate shared default }--[ routing-policy ]--
    A:leaf1# info
        policy pass-all-bgp {
            default-action {
                reject {
                }
            }
            statement 10 {
                match {
                    protocol bgp
                }
                action {
                    accept {
                    }
                }
            }
        }
    ```

1. **Create peer-group config**  
    A peer group should include sessions that have a similar or almost identical configuration.  
    In this example, the peer group is named "eBGP-underlay" since it will be used to enable underlay routing between the leafs and spines.  
    New groups are administratively enabled by default.
    ```
    --{ +* candidate shared default }--[ network-instance default protocols bgp ]--
    A:leaf1# group eBGP-underlay

    --{ +* candidate shared default }--[ network-instance default protocols bgp group eBGP-underlay ]--                                                
    A:leaf1# peer-as 201                                                                                                                               

    --{ +* candidate shared default }--[ network-instance default protocols bgp group eBGP-underlay ]--                                                
    A:leaf1# export-policy pass-all-bgp                                                                                                                
    ```
    The common group configuration includes the `peer-as` and `export-policy`

1. **Configure neighbor**  
    Configure the BGP session with `spine1`. In this example, `spine1` is reachable through the `ethernet-1/49.0` subinterface. On this subnet, `spine1` has the IPv4 address `192.168.11.2`.  
    In this minimal configuration example, the only required configuration for the neighbor is its association with the group "spine" that was previously created.  
    New neighbors are administratively enabled by default.
    ```
    --{ +* candidate shared default }--[ network-instance default protocols bgp ]--
    A:leaf1# neighbor 192.168.11.2 peer-group eBGP-underlay
    ```

1. **Commit configuration**  
    If everything looks OK, commit the configuration.
    ```
    --{ +* candidate shared default }--[ network-instance default protocols bgp ]--
    A:leaf1# commit now
    ```

[^1]: default SR Linux credentials are `admin:admin`.
[^2]: the snippets were extracted with `info interface ethernet-1/x` command issued in running mode.