---
comments: true
title: Chassis and Environment
---

## Chassis

### `show platform chassis`

/// tab | CLI

```srl
A:srl-b# show platform chassis
----------------------------------------------------------------------

Type             : 7220 IXR-D2
Last Boot type   : normal
HW MAC address   : 1A:16:01:FF:00:00
Slots            : 1
Oper Status      : up
Last booted      : 2023-02-02T12:36:30.933Z
Last change      : 2023-02-02T12:36:30.933Z
Part number      : Sim Part No.
CLEI code        : Sim CLEI
----------------------------------------------------------------------
```

///

/// tab | Path
`/platform/chassis`
///

### `show platform environment`

/// tab | CLI

```srl
A:srl-ixr6# show platform environment
  +--------------+----+-------------+-------------------+---------------------------------+-------------+
  | Module Type  | ID | Admin State | Operational State |              Model              | Temperature |
  +==============+====+=============+===================+=================================+=============+
  | control      | A  | N/A         | up                | cpm2-ixr                        | 36          |
  | control      | B  | N/A         | empty             |                                 |             |
  | linecard     | 1  | enable      | empty             |                                 |             |
  | linecard     | 2  | enable      | empty             |                                 |             |
  | linecard     | 3  | enable      | up                | imm32-100g-qsfp28+4-400g-qsfpdd | 34          |
  | linecard     | 4  | enable      | empty             |                                 |             |
  | fan-tray     | 1  | N/A         | up                | fan-ixr-6                       | 0           |
  | fan-tray     | 2  | N/A         | up                | fan-ixr-6                       | 0           |
  | fan-tray     | 3  | N/A         | up                | fan-ixr-6                       | 0           |
  | power-supply | 1  | N/A         | up                | psu-ixr-ac-hvdc-3000            | 29          |
  | power-supply | 2  | N/A         | up                | psu-ixr-ac-hvdc-3000            | 28          |
  | power-supply | 3  | N/A         | up                | psu-ixr-ac-hvdc-3000            | 28          |
  | power-supply | 4  | N/A         | down              | psu-ixr-ac-hvdc-3000            | 0           |
  | power-supply | 5  | N/A         | down              | psu-ixr-ac-hvdc-3000            | 0           |
  | power-supply | 6  | N/A         | empty             |                                 |             |
  | fabric       | 1  | enable      | up                | sfm2-ixr-6                      | 25          |
  | fabric       | 2  | enable      | up                | sfm2-ixr-6                      | 26          |
  | fabric       | 3  | enable      | up                | sfm2-ixr-6                      | 27          |
  | fabric       | 4  | enable      | up                | sfm2-ixr-6                      | 29          |
  | fabric       | 5  | enable      | up                | sfm2-ixr-6                      | 28          |
  | fabric       | 6  | enable      | up                | sfm2-ixr-6                      | 29          |
  +--------------+----+-------------+-------------------+---------------------------------+-------------+
```

///

### `show platform control * detail`

/// tab | CLI

```{.srl .code-scroll-lg}
A:srl-ixr6# show platform control A detail
====================================================================================================================
  Show report for Controller A
====================================================================================================================
  Summary
    Admin State      : N/A
    Operational State: up/active
    Type             : cpm2-ixr
    Last Change      : 2023-09-07T08:07:57.974Z

  Hardware Details
    Part number       : 3HE12458AARC01
    CLEI code         : INCPAEVGAA
    Serial number     : NS210362948
    Manufactured date : 02132021
    Removable         : true
    Locator LED status: inactive
    Last booted       : 2023-09-07T08:07:57.974Z
    Failure reason    : -
    Software version  : v22.11.1-184-g6eeaa254f7

  Power
    Allocated: 80 watts
    Used     : 48 watts

  Temperature
    Current     : 36 Celsius
    Alarm status: None

  Disk /dev/sda :
    Model No : StorFly_VSFB25XI240G-NOK
    Serial No: P1T13005131310240044
    Type     : ssd
    Size     : 240057409536

    Partitions
     /dev/sda1 : 240056344064 bytes

  Disk /dev/sdb :
    Model No : Ultra_HS-COMBO
    Serial No: 000000225001
    Type     : compactflash
    Size     : 31914983424

    Partitions
     /dev/sdb1 : 209715200 bytes
     /dev/sdb2 : 5242880000 bytes
     /dev/sdb3 : 209715200 bytes
     /dev/sdb4 : 26251607552 bytes
--------------------------------------------------------------------------------------------------------------------
  CPU Details
--------------------------------------------------------------------------------------------------------------------
    Architecture: x86_64
    Model       : AMD EPYC 3251 8-Core Processor
    Speed       : 2.50 GHz
--------------------------------------------------------------------------------------------------------------------
  Time Utilization of CPU in Percent(%)
--------------------------------------------------------------------------------------------------------------------
      Task Level       Last Instant   Mean value over the last   Mean value over the last   Mean value over the last
                                               minute                   5 minutes                  15 minutes
  System                    1                    1                          1                          1
  User                      7                    7                          7                          7
  Nice                      0                    0                          0                          0
  Idle                      90                   90                         90                         90
  IO Wait                   0                    0                          0                          0
  Hardware Interrupt        0                    0                          0                          0
  Software Interrupt        0                    0                          0                          0
  Total                     10                   10                         10                         10
--------------------------------------------------------------------------------------------------------------------
  Memory
--------------------------------------------------------------------------------------------------------------------
    Physical   : 30714980000 bytes
    Reserved   : 7346716000 bytes
    Free       : 23368264000 bytes
    Utilization: 23%
--------------------------------------------------------------------------------------------------------------------
  Process table
--------------------------------------------------------------------------------------------------------------------
    PID          Name                Start time          CPU utilization   Memory usage   Memory utilization
  1         systemd           2023-09-29T16:27:25.000Z                0%       11800576                   0%
  1377      systemd-journal   2023-09-29T16:27:51.000Z                0%       68644864                   0%
  1393      systemd-udevd     2023-09-29T16:27:51.000Z                0%        9420800                   0%
  1449      irqbalance        2023-09-29T16:27:51.000Z                0%        5386240                   0%
  1454      systemd-logind    2023-09-29T16:27:51.000Z                0%        7565312                   0%
  1458      dbus-daemon       2023-09-29T16:27:51.000Z                0%       11767808                   0%
  1461      agetty            2023-09-29T16:27:51.000Z                0%        1744896                   0%
  1483      crond             2023-09-29T16:27:51.000Z                0%        3543040                   0%
  1530      sr_wd             2023-09-29T16:27:52.000Z                0%         200704                   0%
  1550      python            2023-09-29T16:27:53.000Z                0%       80146432                   0%
  1828      sshd              2023-09-29T16:27:55.000Z                0%        7012352                   0%
  2801      polkitd           2023-09-29T16:28:01.000Z                0%       32354304                   0%
  2866      rngd              2023-09-29T16:28:02.000Z                0%        9064448                   0%
  3210      sr_linux          2023-09-29T16:28:17.000Z                0%        3530752                   0%
  3226      sudo              2023-09-29T16:28:17.000Z                0%       12005376                   0%
  3240      runuser           2023-09-29T16:28:17.000Z                0%        4747264                   0%
  3435      sr_linux          2023-09-29T16:28:19.000Z                0%        3543040                   0%
  3453      sr_app_mgr        2023-09-29T16:28:19.000Z                0%       92225536                   0%
  3481      sr_supportd       2023-09-29T16:28:28.000Z                0%       37453824                   0%
  3493      top               2023-09-29T16:28:28.000Z                0%       13803520                   0%
  3504      sr_device_mgr     2023-09-29T16:28:29.000Z                0%     1557520384                   4%
  3771      sr_idb_server     2023-09-29T16:28:33.000Z                0%       74838016                   0%
  3783      sr_eth_switch     2023-09-29T16:28:34.000Z                0%      483614720                   1%
  3876      sr_aaa_mgr        2023-09-29T16:28:38.000Z                0%       80572416                   0%
  3894      sr_acl_mgr        2023-09-29T16:28:39.000Z                0%       96456704                   0%
  3971      sr_arp_nd_mgr     2023-09-29T16:28:39.000Z                0%      170151936                   0%
  3993      sr_chassis_mgr    2023-09-29T16:28:40.000Z                0%       82665472                   0%
  4009      sr_dhcp_client_   2023-09-29T16:28:40.000Z                0%       96890880                   0%
  4043      sr_evpn_mgr       2023-09-29T16:28:41.000Z                0%       82829312                   0%
  4069      sr_fib_mgr        2023-09-29T16:28:42.000Z                0%       74981376                   0%
  4091      sr_l2_mac_learn   2023-09-29T16:28:42.000Z                0%       70959104                   0%
  4113      sr_l2_mac_mgr     2023-09-29T16:28:42.000Z                0%       72859648                   0%
  4135      sr_lag_mgr        2023-09-29T16:28:43.000Z                0%       73678848                   0%
  4238      sr_linux_mgr      2023-09-29T16:28:43.000Z                0%       79740928                   0%
  4295      chronyd           2023-09-29T16:28:43.000Z                0%        3375104                   0%
  4321      sr_log_mgr        2023-09-29T16:28:44.000Z                0%       71634944                   0%
  4346      sr_mcid_mgr       2023-09-29T16:28:44.000Z                0%       72007680                   0%
  4388      sr_mfib_mgr       2023-09-29T16:28:44.000Z                0%       74137600                   0%
  4420      sr_mgmt_server    2023-09-29T16:28:45.000Z                0%      155193344                   0%
  4448      sr_net_inst_mgr   2023-09-29T16:28:45.000Z                0%       73256960                   0%
  4478      sr_sdk_mgr        2023-09-29T16:28:46.000Z                0%       75358208                   0%
  4507      sr_sflow_sample   2023-09-29T16:28:46.000Z                0%       93384704                   0%
  4527      sr_xdp_cpm        2023-09-29T16:28:46.000Z                6%      667652096                   2%
  4993      sr_bfd_mgr        2023-09-29T16:28:49.000Z                0%       95600640                   0%
  5041      sr_bgp_mgr        2023-09-29T16:28:50.000Z                0%      124129280                   0%
  5072      sr_label_mgr      2023-09-29T16:28:50.000Z                0%       71946240                   0%
  5096      sr_lldp_mgr       2023-09-29T16:28:51.000Z                0%       92176384                   0%
  5136      sr_plcy_mgr       2023-09-29T16:28:52.000Z                0%       85323776                   0%
  5156      sr_qos_mgr        2023-09-29T16:28:52.000Z                0%       76746752                   0%
  5184      sr_segrt_mgr      2023-09-29T16:28:53.000Z                0%       77574144                   0%
  5223      sr_static_route   2023-09-29T16:28:54.000Z                0%       87601152                   0%
  5398      rsyslogd          2023-09-29T16:28:54.000Z                0%       12992512                   0%
  5909      sshd              2023-09-29T16:28:56.000Z                0%        3870720                   0%
  1408393   agetty            2023-10-02T23:57:22.000Z                0%        2039808                   0%
  2045466   sshd              2023-11-07T19:24:34.000Z                0%       15945728                   0%
  2045658   sshd              2023-11-07T19:24:39.000Z                0%        5525504                   0%
  2045679   ssh_sr_cli        2023-11-07T19:24:39.000Z                0%        1245184                   0%
  2045681   bash              2023-11-07T19:24:39.000Z                0%       13291520                   0%
  2045775   python            2023-11-07T19:24:40.000Z                0%       81108992                   0%
  3011767   chronyd           2023-10-20T14:11:31.000Z                0%        3375104                   0%
--------------------------------------------------------------------------------------------------------------------
```

///
/// tab | Path
`/platform/control[slot=*]`
///

### `show platform redundancy`

/// tab | CLI

```srl
A:ixr136# show platform redundancy
-------------------------------------------------
 Show report for Redundancy
-------------------------------------------------
Active Module         : A
Failover Time         : -
Synchronization Status: <Unknown>
Last Synchronization  : -
Overlay
    Sync frequency: 60 seconds
    Last sync     : None
    Next Sync     : None
-------------------------------------------------
```

///
/// tab | Path
`/platform/redundancy`
///

### `show platform linecard * detail`

/// tab | CLI

```{.srl .code-scroll-lg}
A:srl-ixr6# show platform linecard 3 detail
====================================================================================================================
  Show report for Linecard 3
====================================================================================================================
  Summary
    Admin State      : enable
    Operational State: up
    Model            : imm32-100g-qsfp28+4-400g-qsfpdd
    Last Change      : 2023-09-29T16:32:08.296Z

  Hardware Details
    Part number       : 3HE12522AARD01
    CLEI code         : IPUCBRU1AA
    Serial number     : NS210461228
    Manufactured date : 04212021
    Removable         : true
    Locator LED status: inactive
    Last booted       : 2023-09-29T16:32:08.296Z
    Failure reason    : -
    Software version  : v22.11.1-184-g6eeaa254f7

  Power
    Allocated: 1000
    Used     : 176

  Temperature
    Current     : 32
    Alarm status: None
--------------------------------------------------------------------------------------------------------------------
   ACL resource usage on Forwarding complex 0
--------------------------------------------------------------------------------------------------------------------
               Resource                 Used   Free
  if-input-ipv4-stats                   0      8192
  if-input-ipv6-stats                   0      8192
  if-output-ipv4-stats                  0      8191
  if-output-ipv6-stats                  0      8191
  input-ipv4-filter-instances           0      255
  input-ipv4-qos-multifield-instances   0      15
  input-ipv6-filter-instances           0      255
  input-ipv6-qos-multifield-instances   0      15
--------------------------------------------------------------------------------------------------------------------
   TCAM resource usage on Forwarding complex 0
--------------------------------------------------------------------------------------------------------------------
         Resource          Free Static   Free Dynamic   Reserved   Programmed
  cpm-capture-ipv4         937           0              86         86
  cpm-capture-ipv6         977           0              46         46
  if-input-ipv4            0             18432          0          0
  if-input-ipv6            0             8192           0          0
  if-output-ipv4           0             18432          0          0
  if-output-ipv6           0             8192           0          0
  policy-forwarding-ipv4   0             18432          0          0
--------------------------------------------------------------------------------------------------------------------
   Datapath resource usage on Forwarding complex 0
--------------------------------------------------------------------------------------------------------------------
           Resource            Used Percent   Used Entries   Free Entries
  xdp-arp-nd-entries           0              4              8187
  xdp-direct-next-hops         0              4              1019
  xdp-ecmp-groups              0              0              24574
  xdp-ecmp-members             0              0              72190
  xdp-indirect-next-hops       0              4              1019
  xdp-ip-lpm-routes            0              10             1515510
  xdp-mpls-incoming-labels     -              -              -
  xdp-mpls-next-hops           -              -              -
  xdp-tunnels                  0              0              4096
  asic-exact-match-entries     -              -              -
  asic-level-1-ecmp-groups     0              0              16383
  asic-level-1-ecmp-members    0              0              36607
  asic-level-1-non-ecmp-fecs   0              0              24575
  asic-level-2-ecmp-groups     0              0              8191
  asic-level-2-ecmp-members    0              0              35583
  asic-level-2-non-ecmp-fecs   0              3              16380
--------------------------------------------------------------------------------------------------------------------
   MTU resource usage on Forwarding complex 0
--------------------------------------------------------------------------------------------------------------------
  Resource   Used   Free
  ip-mtu     1      3
  mpls-mtu   1      3
  port-mtu   1      7
--------------------------------------------------------------------------------------------------------------------
   QOS resource usage on Forwarding complex 0
--------------------------------------------------------------------------------------------------------------------
       Resource         Used   Free
  classifier-profiles   1      15
  rewrite-policies      0      28
  rewrite-profiles      1      31
--------------------------------------------------------------------------------------------------------------------
   Buffer memory resource usage on Forwarding complex 0
--------------------------------------------------------------------------------------------------------------------
     Resource       Used     Free     Reserved
  SRAM (in bytes)   256    33554176   N/A
  DRAM (in %)       0      N/A        N/A
--------------------------------------------------------------------------------------------------------------------
```

///
/// tab | Path
`/platform/linecard[slot=*]`
///

### `show platform fabric * detail`

/// tab | CLI

```srl
A:ixr136# show platform fabric 1 detail
====================================================================================================================
  Show report for Fabric 1
====================================================================================================================
  Summary
    Admin State      : enable
    Operational State: up
    Type             : sfm2-ixr-6
    Last Change      : 2023-09-29T16:29:23.982Z

  Hardware Details
    Part number       : 3HE12382AARA01
    CLEI code         : INCPAELGAA
    Serial number     : NS203962343
    Manufactured date : 10132020
    Removable         : true
    Last booted       : 2023-09-29T16:29:23.982Z
    Failure reason    : -

  Power
    Allocated: 185 watts
    Used     : 34 watts

  Temperature
    Current     : 24 Celsius
    Alarm status: None
--------------------------------------------------------------------------------------------------------------------
```

///
/// tab | Path
`/platform/fabric[slot=*]`
///

## Fans

### `show platform fan-tray`

/// tab | CLI

```srl
A:ixr136# show platform fan-tray
  +-------------+----+-------------+-------------------+-----------+------------------
  | Module Type | ID | Admin State | Operational State |   Model   | Last Change     |
  +=============+====+=============+===================+===========+====================
  | fan-tray    | 1  | N/A         | up                | fan-ixr-6 | 2022-11-08T16:28:46.225Z |
  | fan-tray    | 2  | N/A         | up                | fan-ixr-6 | 2022-11-08T16:28:46.271Z |
  | fan-tray    | 3  | N/A         | up                | fan-ixr-6 | 2022-11-08T16:28:46.318Z |
  +-------------+----+-------------+-------------------+-----------+------------------
```

```srl
A:ixr136# show platform fan-tray 1 detail
======================================================================================

Show report for Fan Tray 1
======================================================================================

  Summary
    Admin State      : N/A
    Operational State: up
    Type             : fan-ixr-6
    Last Change      : 2022-11-08T16:28:46.225Z

  Hardware Details
    Part number       : 3HE11759AARA01
    CLEI code         : INCPABAGAA
    Serial number     : NS1945F0301
    Manufactured date : 11082019
    Removable         : true
    Locator LED status: inactive
    Failure reason    : -

Power
    Allocated: 333 watts
    Used     : 99 watts
--------------------------------------------------------------------------------------
```

///
/// tab | Path
`/platform/fan-tray[id=*]`
///

## Power Supplies

### `show platform power-supply`

/// tab | CLI

```srl
A:ixr136# show platform power-supply
+--------------+----+-------------+-------------------+-----------------+--------------------------+
| Module Type  | ID | Admin State | Operational State |      Model      |       Last Change        |
| power-supply | 1  | N/A         | up                | psu-ixr-dc-3000 | 2022-11-08T16:28:52.317Z |
| power-supply | 2  | N/A         | empty             |                 |                          |
+--------------+----+-------------+-------------------+-----------------+--------------------------+
```

```srl
A:ixr136# show platform power-supply 1 detail
======================================================================================
  Show report for Power Supply 1
======================================================================================
  Summary
    Admin State      : N/A
    Operational State: up
    Type             : psu-ixr-dc-3000
    Last Change      : 2022-11-08T16:28:52.317Z

  Hardware Details
    Part number       : 3HE11752AARA01
    CLEI code         : INPSAAZFAA
    Serial number     : NS1911W0038
    Manufactured date : 03132019
    Removable         : true
    Last booted       : 2022-11-08T16:28:52.249Z
    Failure reason    : -

  Power 
    Capacity     : 3000 watts
    Input Voltage: 53.50 volts
    Input Current: 9.61 amps
    Input Power  : 514.00 watts

  Temperature 
    Current     : 35 Celsius
    Alarm status: None
------------------------------------------------------
```

///
/// tab | Path
`/platform/power-supply[id=*]`
///

## Temperature

### `show platform environment`

/// tab | CLI

```srl
A:srl-b# show platform environment
+--------------+----+-------------+------------+-------------------------------+-------------+
| Module Type  | ID | Admin State | Oper State |            Model              | Temperature |
+==============+====+=============+============+===============================+=============+
| control      | A  | N/A         | up         | imm48-25g-sfp28+8-100g-qsfp28 | 50          |
| linecard     | 1  | N/A         | empty      |                               | 0           |
| fan-tray     | 1  | N/A         | up         | fan-ixr-6                     | 0           |
| fan-tray     | 2  | N/A         | up         | fan-ixr-6                     | 0           |
| fan-tray     | 3  | N/A         | up         | fan-ixr-6                     | 0           |
| power-supply | 1  | N/A         | up         | psu-ixr-dc-3000               | 35          |
| power-supply | 2  | N/A         | empty      |                               |             |
+--------------+----+-------------+-------------------+--------------------------------------+
```

///

/// tab | Path
gNMI paths:

* `/platform/control[slot=*]/temperature/instant`
* `/platform/power-supply[id=*]/temperature/instant`
///

## CPU & Memory

/// tab | CLI

```{.srl .code-scroll-lg}
A:srl-ixr6# show platform control A detail
====================================================================================================================
  Show report for Controller A
====================================================================================================================
  Summary
    Admin State      : N/A
    Operational State: up/active
    Type             : cpm2-ixr
    Last Change      : 2023-09-07T08:07:57.974Z

  Hardware Details
    Part number       : 3HE12458AARC01
    CLEI code         : INCPAEVGAA
    Serial number     : NS210362948
    Manufactured date : 02132021
    Removable         : true
    Locator LED status: inactive
    Last booted       : 2023-09-07T08:07:57.974Z
    Failure reason    : -
    Software version  : v22.11.1-184-g6eeaa254f7

  Power
    Allocated: 80 watts
    Used     : 48 watts

  Temperature
    Current     : 36 Celsius
    Alarm status: None

  Disk /dev/sda :
    Model No : StorFly_VSFB25XI240G-NOK
    Serial No: P1T13005131310240044
    Type     : ssd
    Size     : 240057409536

    Partitions
     /dev/sda1 : 240056344064 bytes

  Disk /dev/sdb :
    Model No : Ultra_HS-COMBO
    Serial No: 000000225001
    Type     : compactflash
    Size     : 31914983424

    Partitions
     /dev/sdb1 : 209715200 bytes
     /dev/sdb2 : 5242880000 bytes
     /dev/sdb3 : 209715200 bytes
     /dev/sdb4 : 26251607552 bytes
--------------------------------------------------------------------------------------------------------------------
  CPU Details
--------------------------------------------------------------------------------------------------------------------
    Architecture: x86_64
    Model       : AMD EPYC 3251 8-Core Processor
    Speed       : 2.50 GHz
--------------------------------------------------------------------------------------------------------------------
  Time Utilization of CPU in Percent(%)
--------------------------------------------------------------------------------------------------------------------
      Task Level       Last Instant   Mean value over the last   Mean value over the last   Mean value over the last
                                               minute                   5 minutes                  15 minutes
  System                    1                    1                          1                          1
  User                      7                    7                          7                          7
  Nice                      0                    0                          0                          0
  Idle                      90                   90                         90                         90
  IO Wait                   0                    0                          0                          0
  Hardware Interrupt        0                    0                          0                          0
  Software Interrupt        0                    0                          0                          0
  Total                     10                   10                         10                         10
--------------------------------------------------------------------------------------------------------------------
  Memory
--------------------------------------------------------------------------------------------------------------------
    Physical   : 30714980000 bytes
    Reserved   : 7346716000 bytes
    Free       : 23368264000 bytes
    Utilization: 23%
--------------------------------------------------------------------------------------------------------------------
  Process table
--------------------------------------------------------------------------------------------------------------------
    PID          Name                Start time          CPU utilization   Memory usage   Memory utilization
  1         systemd           2023-09-29T16:27:25.000Z                0%       11800576                   0%
  1377      systemd-journal   2023-09-29T16:27:51.000Z                0%       68644864                   0%
  1393      systemd-udevd     2023-09-29T16:27:51.000Z                0%        9420800                   0%
  1449      irqbalance        2023-09-29T16:27:51.000Z                0%        5386240                   0%
  1454      systemd-logind    2023-09-29T16:27:51.000Z                0%        7565312                   0%
  1458      dbus-daemon       2023-09-29T16:27:51.000Z                0%       11767808                   0%
  1461      agetty            2023-09-29T16:27:51.000Z                0%        1744896                   0%
  1483      crond             2023-09-29T16:27:51.000Z                0%        3543040                   0%
  1530      sr_wd             2023-09-29T16:27:52.000Z                0%         200704                   0%
  1550      python            2023-09-29T16:27:53.000Z                0%       80146432                   0%
  1828      sshd              2023-09-29T16:27:55.000Z                0%        7012352                   0%
  2801      polkitd           2023-09-29T16:28:01.000Z                0%       32354304                   0%
  2866      rngd              2023-09-29T16:28:02.000Z                0%        9064448                   0%
  3210      sr_linux          2023-09-29T16:28:17.000Z                0%        3530752                   0%
  3226      sudo              2023-09-29T16:28:17.000Z                0%       12005376                   0%
  3240      runuser           2023-09-29T16:28:17.000Z                0%        4747264                   0%
  3435      sr_linux          2023-09-29T16:28:19.000Z                0%        3543040                   0%
  3453      sr_app_mgr        2023-09-29T16:28:19.000Z                0%       92225536                   0%
  3481      sr_supportd       2023-09-29T16:28:28.000Z                0%       37453824                   0%
  3493      top               2023-09-29T16:28:28.000Z                0%       13803520                   0%
  3504      sr_device_mgr     2023-09-29T16:28:29.000Z                0%     1557520384                   4%
  3771      sr_idb_server     2023-09-29T16:28:33.000Z                0%       74838016                   0%
  3783      sr_eth_switch     2023-09-29T16:28:34.000Z                0%      483614720                   1%
  3876      sr_aaa_mgr        2023-09-29T16:28:38.000Z                0%       80572416                   0%
  3894      sr_acl_mgr        2023-09-29T16:28:39.000Z                0%       96456704                   0%
  3971      sr_arp_nd_mgr     2023-09-29T16:28:39.000Z                0%      170151936                   0%
  3993      sr_chassis_mgr    2023-09-29T16:28:40.000Z                0%       82665472                   0%
  4009      sr_dhcp_client_   2023-09-29T16:28:40.000Z                0%       96890880                   0%
  4043      sr_evpn_mgr       2023-09-29T16:28:41.000Z                0%       82829312                   0%
  4069      sr_fib_mgr        2023-09-29T16:28:42.000Z                0%       74981376                   0%
  4091      sr_l2_mac_learn   2023-09-29T16:28:42.000Z                0%       70959104                   0%
  4113      sr_l2_mac_mgr     2023-09-29T16:28:42.000Z                0%       72859648                   0%
  4135      sr_lag_mgr        2023-09-29T16:28:43.000Z                0%       73678848                   0%
  4238      sr_linux_mgr      2023-09-29T16:28:43.000Z                0%       79740928                   0%
  4295      chronyd           2023-09-29T16:28:43.000Z                0%        3375104                   0%
  4321      sr_log_mgr        2023-09-29T16:28:44.000Z                0%       71634944                   0%
  4346      sr_mcid_mgr       2023-09-29T16:28:44.000Z                0%       72007680                   0%
  4388      sr_mfib_mgr       2023-09-29T16:28:44.000Z                0%       74137600                   0%
  4420      sr_mgmt_server    2023-09-29T16:28:45.000Z                0%      155193344                   0%
  4448      sr_net_inst_mgr   2023-09-29T16:28:45.000Z                0%       73256960                   0%
  4478      sr_sdk_mgr        2023-09-29T16:28:46.000Z                0%       75358208                   0%
  4507      sr_sflow_sample   2023-09-29T16:28:46.000Z                0%       93384704                   0%
  4527      sr_xdp_cpm        2023-09-29T16:28:46.000Z                6%      667652096                   2%
  4993      sr_bfd_mgr        2023-09-29T16:28:49.000Z                0%       95600640                   0%
  5041      sr_bgp_mgr        2023-09-29T16:28:50.000Z                0%      124129280                   0%
  5072      sr_label_mgr      2023-09-29T16:28:50.000Z                0%       71946240                   0%
  5096      sr_lldp_mgr       2023-09-29T16:28:51.000Z                0%       92176384                   0%
  5136      sr_plcy_mgr       2023-09-29T16:28:52.000Z                0%       85323776                   0%
  5156      sr_qos_mgr        2023-09-29T16:28:52.000Z                0%       76746752                   0%
  5184      sr_segrt_mgr      2023-09-29T16:28:53.000Z                0%       77574144                   0%
  5223      sr_static_route   2023-09-29T16:28:54.000Z                0%       87601152                   0%
  5398      rsyslogd          2023-09-29T16:28:54.000Z                0%       12992512                   0%
  5909      sshd              2023-09-29T16:28:56.000Z                0%        3870720                   0%
  1408393   agetty            2023-10-02T23:57:22.000Z                0%        2039808                   0%
  2045466   sshd              2023-11-07T19:24:34.000Z                0%       15945728                   0%
  2045658   sshd              2023-11-07T19:24:39.000Z                0%        5525504                   0%
  2045679   ssh_sr_cli        2023-11-07T19:24:39.000Z                0%        1245184                   0%
  2045681   bash              2023-11-07T19:24:39.000Z                0%       13291520                   0%
  2045775   python            2023-11-07T19:24:40.000Z                0%       81108992                   0%
  3011767   chronyd           2023-10-20T14:11:31.000Z                0%        3375104                   0%
--------------------------------------------------------------------------------------------------------------------
```

///
/// tab | CPU Path
`/platform/control[slot=*]/cpu[index=*]`
///

/// tab | Mem Path
`/platform/control[slot=*]/memory`
///

## Software Version

/// tab | CLI

```srl
A:srl-b# show version
-----------------------------------------------------------------

Hostname             : srl-b
Chassis Type         : 7220 IXR-D2
Part Number          : Sim Part No.
Serial Number        : Sim Serial No.
System HW MAC Address: 1A:16:01:FF:00:00
Software Version     : v22.11.1
Build Number         : 184-g6eeaa254f7
Architecture         : x86_64
Last Booted          : 2023-02-02T12:36:30.933Z
Total Memory         : 18974488 kB
Free Memory          : 15512714 kB
------------------------------------------------------------------
```

///
/// tab | Path
gNMI paths:

* `/platform/control[slot=*]/software-version`
* `/platform/linecard[slot=*]/software-version`
* `/system/information/version`
///

## System Limits

/// tab | CLI

```{.srl .code-scroll-lg}
A:srl-ixr6# show platform linecard 3 detail
====================================================================================================================
  Show report for Linecard 3
====================================================================================================================
  Summary
    Admin State      : enable
    Operational State: up
    Model            : imm32-100g-qsfp28+4-400g-qsfpdd
    Last Change      : 2023-09-29T16:32:08.296Z

  Hardware Details
    Part number       : 3HE12522AARD01
    CLEI code         : IPUCBRU1AA
    Serial number     : NS210461228
    Manufactured date : 04212021
    Removable         : true
    Locator LED status: inactive
    Last booted       : 2023-09-29T16:32:08.296Z
    Failure reason    : -
    Software version  : v22.11.1-184-g6eeaa254f7

  Power
    Allocated: 1000
    Used     : 176

  Temperature
    Current     : 32
    Alarm status: None
--------------------------------------------------------------------------------------------------------------------
   ACL resource usage on Forwarding complex 0
--------------------------------------------------------------------------------------------------------------------
               Resource                 Used   Free
  if-input-ipv4-stats                   0      8192
  if-input-ipv6-stats                   0      8192
  if-output-ipv4-stats                  0      8191
  if-output-ipv6-stats                  0      8191
  input-ipv4-filter-instances           0      255
  input-ipv4-qos-multifield-instances   0      15
  input-ipv6-filter-instances           0      255
  input-ipv6-qos-multifield-instances   0      15
--------------------------------------------------------------------------------------------------------------------
   TCAM resource usage on Forwarding complex 0
--------------------------------------------------------------------------------------------------------------------
         Resource          Free Static   Free Dynamic   Reserved   Programmed
  cpm-capture-ipv4         937           0              86         86
  cpm-capture-ipv6         977           0              46         46
  if-input-ipv4            0             18432          0          0
  if-input-ipv6            0             8192           0          0
  if-output-ipv4           0             18432          0          0
  if-output-ipv6           0             8192           0          0
  policy-forwarding-ipv4   0             18432          0          0
--------------------------------------------------------------------------------------------------------------------
   Datapath resource usage on Forwarding complex 0
--------------------------------------------------------------------------------------------------------------------
           Resource            Used Percent   Used Entries   Free Entries
  xdp-arp-nd-entries           0              4              8187
  xdp-direct-next-hops         0              4              1019
  xdp-ecmp-groups              0              0              24574
  xdp-ecmp-members             0              0              72190
  xdp-indirect-next-hops       0              4              1019
  xdp-ip-lpm-routes            0              10             1515510
  xdp-mpls-incoming-labels     -              -              -
  xdp-mpls-next-hops           -              -              -
  xdp-tunnels                  0              0              4096
  asic-exact-match-entries     -              -              -
  asic-level-1-ecmp-groups     0              0              16383
  asic-level-1-ecmp-members    0              0              36607
  asic-level-1-non-ecmp-fecs   0              0              24575
  asic-level-2-ecmp-groups     0              0              8191
  asic-level-2-ecmp-members    0              0              35583
  asic-level-2-non-ecmp-fecs   0              3              16380
--------------------------------------------------------------------------------------------------------------------
   MTU resource usage on Forwarding complex 0
--------------------------------------------------------------------------------------------------------------------
  Resource   Used   Free
  ip-mtu     1      3
  mpls-mtu   1      3
  port-mtu   1      7
--------------------------------------------------------------------------------------------------------------------
   QOS resource usage on Forwarding complex 0
--------------------------------------------------------------------------------------------------------------------
       Resource         Used   Free
  classifier-profiles   1      15
  rewrite-policies      0      28
  rewrite-profiles      1      31
--------------------------------------------------------------------------------------------------------------------
   Buffer memory resource usage on Forwarding complex 0
--------------------------------------------------------------------------------------------------------------------
     Resource       Used     Free     Reserved
  SRAM (in bytes)   256    33554176   N/A
  DRAM (in %)       0      N/A        N/A
--------------------------------------------------------------------------------------------------------------------
```

///
/// tab | Path
`/platform/linecard[slot=*]`
///

## Flash Card Usage

By system design, compact flash card is part of the control card.

/// tab | CLI

```srl
A:srl-ixr6# info from state platform control A disk /dev/sdb
    platform {
        control A {
            disk /dev/sdb {
                model-number Ultra_HS-COMBO
                serial-number 000000225001
                size 31914983424
                type compactflash
                partition /dev/sdb1 {
                    uuid c2d8a98e-aab8-4043-a031-3011f0007616
                    mount-point /mnt/nokiaboot
                    mount-status rw
                    size 209715200
                    used 39984128
                    free 168088576
                    percent-used 19
                }
                partition /dev/sdb2 {
                    uuid 0891244c-39fc-43f2-ba90-3abb1f78e222
                    mount-point /run/initramfs/live
                    mount-status rw
                    size 5242880000
                    used 2350632960
                    free 2809933824
                    percent-used 45
                }
                partition /dev/sdb3 {
                    uuid d62e7427-b3bc-4122-b49b-19f1320eae6d
                    mount-point /run/ovl/NOKIA-ETC
                    mount-status rw
                    size 209715200
                    used 16600064
                    free 182296576
                    percent-used 8
                }
                partition /dev/sdb4 {
                    uuid 42063cbb-9c05-419f-838f-99f501147fea
                    mount-point /run/ovl/NOKIA-OPT
                    mount-status rw
                    size 26251607552
                    used 1378955264
                    free 24460578816
                    percent-used 5
                }
            }
        }
    }

```

///
/// tab | Path
`/platform/control[slot=A]/disk[name=/dev/sdb]`
///

## Factory Reset

Factory reset may involve changing the software version to a golden image, cleaning up configuration, logs, certificates and licenses or a subset of these.

A complete factory reset including all the above mentioned changes can be achieved using gNOI FactoryReset service.

For this section, we will focus on restoring the configuration to factory default. Use the `load factory` command in config edit mode to restore the router to factory default config.

Note - All user defined configuration including inband and management IPs will be wiped out. Only console access will be available after this action.

/// tab | CLI

```srl
A:srlinux# enter candidate private
--{ + candidate private private-admin }--[  ]--
A:srlinux# load factory
/system/configuration/checkpoint[id=__factory__]:
    Loaded factory configuration

--{ + candidate private private-admin }--[  ]--
A:srlinux# commit stay
All changes have been committed. Starting new transaction.
```
///
