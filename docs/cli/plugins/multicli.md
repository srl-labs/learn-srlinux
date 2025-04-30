# SR Linux MultiCLI project

SR Linux is the industry's most modern Network Operating System (NOS) enabling unmatched automation and programmability features. One of its capabilities is the ability to [customize the CLI](index.md) on SR Linux.

All `show` commands shipped with the SR Linux software are written in executable python scripts leveraging the model-driven infrastructure to query the state.

Users are allowed to take those python scripts, modify them to fit their use case or build a brand new CLI command leveraging the same workflow as our R&D team.  
These user-provided CLI scripts are called **Custom CLI plugins** in SR Linux.

Since everything in SR Linux is modeled in YANG from the ground up, this allows the user to accesses any state object or attribute in the system and display it in the format they are familiar with.

So a valid question arises - can we make SR Linux CLI look and feel like another NOS for show commands?  
The simple answer is a big **YES WE CAN**.

Let's take an example for the BGP neighbor show command on 4 different Operating Systems.

/// tab | SR Linux

```
$ show network-instance default protocols bgp neighbor

-------------------------------------------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow
-------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------
+-----------------+------------------------+-----------------+------+---------+--------------+--------------+------------+------------------------+
|    Net-Inst     |          Peer          |      Group      | Flag | Peer-AS |    State     |    Uptime    |  AFI/SAFI  |     [Rx/Active/Tx]     |
|                 |                        |                 |  s   |         |              |              |            |                        |
+=================+========================+=================+======+=========+==============+==============+============+========================+
| default         | 10.10.10.10            | evpn            | S    | 65500   | established  | 0d:0h:52m:0s | evpn       | [41/33/14]             |
| default         | 192.168.10.3           | ebgp            | S    | 64500   | established  | 0d:0h:52m:29 | ipv4-      | [4/3/1]                |
|                 |                        |                 |      |         |              | s            | unicast    |                        |
| default         | 192:168:10::3          | ebgp            | S    | 64500   | established  | 0d:0h:52m:34 | ipv6-      | [4/3/1]                |
|                 |                        |                 |      |         |              | s            | unicast    |                        |
| default         | 2001::10               | evpn            | S    | 65500   | established  | 0d:0h:52m:0s | evpn       | [55/0/14]              |
+-----------------+------------------------+-----------------+------+---------+--------------+--------------+------------+------------------------+
-------------------------------------------------------------------------------------------------------------------------------------------------------
Summary:
4 configured neighbors, 4 configured sessions are established, 0 disabled peers
0 dynamic peers
```

///

/// tab | Arista

```
$ show ip bgp summary

BGP summary information for VRF default
Router identifier 1.1.1.1, local AS number 64501
Neighbor Status Codes: m – Under maintenance
  Neighbor        V    AS     MsgRcvd   MsgSent   InQ    OutQ   Up/Down   State     PfxRcd    PfxAcc
  10.10.10.10     E    65500  157       126       0      0      52m       Estab     41        33       
  192.168.10.3    4    64500  113       111       0      0      53m       Estab     4         3        
  192:168:10::3   6    64500  114       111       0      0      53m       Estab     4         3        
  2001::10        E    65500  170       126       0      0      52m       Estab     55        0        
```

///

/// tab | Cisco NX-OS

```
$ show ip bgp summary

BGP summary information for VRF default, address family IPv4 Unicast
BGP router identifier 1.1.1.1, local AS number 64501

Neighbor        V    AS    MsgRcvd   MsgSent   InQ  OutQ  Up/Down   State/PfxRcd
---------------------------------------------------------------------------
10.10.10.10    4    65500  159       128       0    0    53m       None
192.168.10.3   4    64500  115       113       0    0    54m       4
192:168:10::3  4    64500  116       113       0    0    54m       None
2001::10       4    65500  172       128       0    0    53m       None
```

///

/// tab | Nokia SR OS

```
$ show router bgp summary

===============================================================================
 BGP Router ID:1.1.1.1              AS:64501      Local AS:64501     
===============================================================================
BGP Admin State         : Up          BGP Oper State              : Up        
Total Peer Groups       : 2           Total Peers                 : 4         
Total VPN Peer Groups   : 0           Total VPN Peers             : 0         
Current Internal Groups : 1           Max Internal Groups         : 1         
Total BGP Paths         : 52          Total Path Memory           : 18872 
--snip---
===============================================================================
BGP Summary
===============================================================================
Legend : D - Dynamic Neighbor
===============================================================================
Neighbor
Description
                   AS PktRcvd InQ  Up/Down   State|Rcv/Act/Sent (Addr Family)
                      PktSent OutQ
-------------------------------------------------------------------------------
10.10.10.10
                65500      161    0 00h54m49s  
                           130    0           
                                             41/33/14 (Evpn)

192.168.10.3
                64500      117    0 00h55m18s  
                           115    0           
                                             4/3/1 (IPv4)

192:168:10::3
                64500      118    0 00h55m24s  
                           115    0           
                                             4/3/1 (IPv6)

2001::10
                65500      174    0 00h54m49s  
                           130    0           
                                             55/0/14 (Evpn)

-------------------------------------------------------------------------------
```

///

As you can see from the above outputs, each NOS has a unique command and output format to check BGP neighbor status.

What if someone can run all those 4 commands on a single NOS?

This is the power of custom CLI plugins in SR Linux. All the 4 outputs seen above are from the same SR Linux node.

## Introducing MultiCLI project for SR Linux

MultiCLI project is an open source initiative to build SR Linux plugins for 3rd party NOS show commands.

The objective of the project is to help with user onboarding, training and re-use of existing tools in a network while adopting SR Linux.

The first phase of this project includes commands from 4 different NOS - Arista EOS, Cisco NX-OS, Juniper JunOS and Nokia SR OS.

Visit the [MultiCLI](https://github.com/srl-labs/MultiCLI/) git repo to see these plugins and try them using the built-in lab in the repo.

### SR Linux Advantages with plugins

As you test these plugins, you will notice some cool CLI features that comes natively with SR Linux CLI.

1. The native command auto-completion feature also applies to plugins.

2. Using the `tab` key will display the next options that can be navigated using the arrow keys on your keyboard.

3. As you type in a keyword, you will see a lighter shade of the full keyword.

4. Each option can have an associated help section which is fully programmable.

At the end of each command's output, we are also providing the equivalent SR Linux command for users to learn and navigate the SR Linux CLI.

### I need more plugins like this. What should I do?

MultiCLI is an open source project. If you have a command in mind and are willing to develop the plugin, join the project and contribute. Take a look at the tutorial and existing plugins to learn more about developing a plugin.
