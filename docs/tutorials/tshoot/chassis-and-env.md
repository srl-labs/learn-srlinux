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

### `show platform control * detail`

/// tab | CLI

```srl
A:srl-b# show platform control A detail
=====================================================================================

Show report for Controller A
=====================================================================================

  Summary
    Admin State      : N/A
    Operational State: up
    Type             : imm48-25g-sfp28+8-100g-qsfp28
    Last Change      : 2023-02-02T12:36:30.933Z

  Hardware Details
    Part number       : Sim Part No.
    CLEI code         : Sim CLEI
    Serial number     : Sim Serial No.
    Manufactured date : 01012019
    Removable         : <Unknown>
    Locator LED status: inactive
    Last booted       : 2023-02-02T12:36:30.933Z
    Failure reason    : -
    Software version  : v22.11.1-184-g6eeaa254f7

  Power
    Allocated: 80 watts
    Used     : 49 watts

  Temperature
    Current     : 50 Celsius
    Alarm status: None

  Disk /dev/sda :
    Model No : StorFly_VSFB25XI240G-NOK
    Serial No: P1T14005171101270083
    Type     : ssd
    Size     : 240057409536

    Partitions
     /dev/sda1 : 240056344064 bytes
--------------------------------------------------------------------------------------
```

///
/// tab | Path
`/platform/control[slot=*]`
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

## CPU

/// tab | CLI

```srl
A:ixr136# show platform control A detail
===========================================================

Show report for Controller A
===========================================================

<snip>
--------------------------------------------------------------------------------------

CPU Details
--------------------------------------------------------------------------------------

    Architecture: x86_64
    Model       : AMD EPYC 3251 8-Core Processor
    Speed       : 2.50 MHz
--------------------------------------------------------------------------------------

Time Utilization of CPU in Percent(%)
--------------------------------------------------------------------------------------

     Task Level      Last Instant   Mean value over    Mean value over Mean value over
                                    the last minute       the last 5       the last 15
                                                           minutes            minutes

System                  0                0                  0                  0
User                    0                0                  0                  0
Nice                    0                0                  0                  0
Idle                    98               98                 98                98
IO Wait                 0                0                  0                  0
Hardware Interrupt      0                0                  0                  0
Software Interrupt      0                0                  0                  0
Total                   2                2                  2                  2
--------------------------------------------------------------------------------------
```

///
/// tab | Path
`/platform/control[slot=*]/cpu[index=*]`
///

## Memory

/// tab | CLI

```srl
A:ixr136# show platform control A detail
===========================================================

Show report for Controller A
===========================================================

<snip>
-----------------------------------------------------------

Memory
-----------------------------------------------------------

    Physical   : 32787104000 bytes
    Reserved   : 7414052000 bytes
    Free       : 25373052000 bytes
    Utilization: 22%
```

///
/// tab | Path
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

```srl
A:srl-a# show platform linecard 1 detail
======================================================================================

Show report for Linecard 1
======================================================================================

<snip>
  ACL resource usage on Forwarding complex 0
--------------------------------------------------------------------------------------

               Resource                 Used   Free

if-output-cpm-stats
  input-ipv4-filter-instances-bridged   0      7
  input-ipv4-filter-instances-routed    0      255
  input-ipv6-filter-instances-bridged   0      7
  input-ipv6-filter-instances-routed    0      255
--------------------------------------------------------------------------------------

TCAM resource usage on Forwarding complex 0
--------------------------------------------------------------------------------------

       Resource         Free Static   Free Dynamic   Reserved   Programmed
  if-input-ipv4         13824         0              0          0
  if-input-ipv4-qos     13824         0              0          0
  if-input-ipv6         4608          0              0          0
```

///
/// tab | Path
`/platform/linecard[slot=*]`
///

## Flash Card Usage

Enter ‘bash’ to go into the Linux shell prompt and run the below command to check the disk usage for each partition.
To increase free space, remove unwanted files like old software images or logs.

```bash
A:ixr137# bash
bash-4.2$ df -kh
Filesystem      Size  Used Avail Use% Mounted on
devtmpfs         16G     0   16G   0% /dev
tmpfs            16G   64K   16G   1% /dev/shm
tmpfs            16G  188M   16G   2% /run
tmpfs            16G     0   16G   0% /sys/fs/cgroup
/dev/sdb2       2.9G  1.7G  1.2G  59% /media/sdb2
/dev/sda1       220G  866M  208G   1% /run/ovl/NOKIA-DATA
rootsrl         220G  866M  208G   1% /
/dev/loop3      1.9G  7.0M  1.8G   1% /run/ovl/NOKIA-OPT
optsrl          1.9G  7.0M  1.8G   1% /opt/srlinux
/dev/sdb3       190M  4.7M  172M   3% /run/ovl/NOKIA-ETC
etcsrl          190M  4.7M  172M   3% /etc/opt/srlinux
tmpfs            16G   20K   16G   1% /etc/opt/srlinux/devices
tmpfs            16G     0   16G   0% /opt/srlinux/var/run
/dev/sdb1       199M   38M  161M  20% /mnt/nokiaboot
tmpfs           512M   77M  436M  15% /run/srlinux/varlog_tmpfs
bash-4.2$
```
