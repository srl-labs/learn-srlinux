---
comments: true
---

# Customizing SNMP MIBs and Traps in SR Linux

In version 24.10.1, SR Linux introduces a customizable SNMP framework allowing users to define their own SNMP MIBs and traps.
This same framework powers [SR Linux's built-in MIBs and traps](https://documentation.nokia.com/srlinux/24-10/books/system-mgmt/snmp.html), offering flexibility to tailor SNMP functionalities to specific requirements.

The framework utilizes:

* Mapping files (YAML): To define MIB tables and traps.
* Conversion scripts ([uPython](https://micropython.org/)): To process data from the management server and expose it via SNMP.

## SR Linux Built-In MIBs

Built-in MIB mappings are defined in the configuration file available on the SR Linux's filesystem:

```bash
cat /opt/srlinux/snmp/snmp_files_config.yaml
```

<div class="embed-result">
```yaml
table-definitions:
  - scripts/snmpv2_mib.yaml
  - scripts/if_mib.yaml
  - scripts/timetra_bgp.yaml
  - scripts/timetra_chassis.yaml
  - scripts/timetra_system.yaml
trap-definitions:
  - scripts/rfc3418_traps.yaml
  - scripts/timetra_bgp_traps.yaml
```
</div>

### Table definitions

The table definition YAML file describes the framework components used to define a particular MIB table. Take the `if_mib.yaml` file for example, it maps interface-related data to standard MIB tables such as `ifTable`, `ifXTable`, and `ifStackTable`.

You can list the contents of this file with `cat /opt/srlinux/snmp/scripts/if_mib.yaml` command and we provide it here for reference:

/// details | `if_mib.yaml` definition file
    type: subtle-note

```yaml
#- This is the mapping for interfaces and subinterfaces. It defines MIB tables ifTable, ifXTable and ifStackTable.
paths:
    - /interface/
    - /interface/ethernet
    - /interface/lag
    - /interface/statistics
    - /interface/transceiver
    - /interface/subinterface/
    - /interface/subinterface/statistics
python-script: if_mib.py
enabled: true
debug: false
tables:
    - name:    ifTable
      enabled: true
      oid:     1.3.6.1.2.1.2.2
      indexes:
            - name:   ifIndex
              oid:    1.3.6.1.2.1.2.2.1.1
              syntax: integer
      columns:
            - name:   ifIndex
              oid:    1.3.6.1.2.1.2.2.1.1
              syntax: integer
            - name:   ifDescr
              oid:    1.3.6.1.2.1.2.2.1.2
              syntax: octet string
            - name:   ifType
              oid:    1.3.6.1.2.1.2.2.1.3
              syntax: integer
            - name:   ifMtu
              oid:    1.3.6.1.2.1.2.2.1.4
              syntax: integer
            - name:   ifSpeed
              oid:    1.3.6.1.2.1.2.2.1.5
              syntax: gauge32
            - name:   ifPhysAddress
              oid:    1.3.6.1.2.1.2.2.1.6
              syntax: octet string
              binary: true
            - name:   ifAdminStatus
              oid:    1.3.6.1.2.1.2.2.1.7
              syntax: integer
            - name:   ifOperStatus
              oid:    1.3.6.1.2.1.2.2.1.8
              syntax: integer
            - name:   ifLastChange
              oid:    1.3.6.1.2.1.2.2.1.9
              syntax: timeticks
            - name:   ifInOctets
              oid:    1.3.6.1.2.1.2.2.1.10
              syntax: counter32
            - name:   ifInUcastPkts
              oid:    1.3.6.1.2.1.2.2.1.11
              syntax: counter32
            - name:   ifInNUcastPkts
              oid:    1.3.6.1.2.1.2.2.1.12
              syntax: counter32
            - name:   ifInDiscards
              oid:    1.3.6.1.2.1.2.2.1.13
              syntax: counter32
            - name:   ifInErrors
              oid:    1.3.6.1.2.1.2.2.1.14
              syntax: counter32
            - name:   ifInUnknownProtos
              oid:    1.3.6.1.2.1.2.2.1.15
              syntax: counter32
            - name:   ifOutOctets
              oid:    1.3.6.1.2.1.2.2.1.16
              syntax: counter32
            - name:   ifOutUcastPkts
              oid:    1.3.6.1.2.1.2.2.1.17
              syntax: counter32
            - name:   ifOutNUcastPkts
              oid:    1.3.6.1.2.1.2.2.1.18
              syntax: counter32
            - name:   ifOutDiscards
              oid:    1.3.6.1.2.1.2.2.1.19
              syntax: counter32
            - name:   ifOutErrors
              oid:    1.3.6.1.2.1.2.2.1.20
              syntax: counter32
            - name:   ifOutQLen
              oid:    1.3.6.1.2.1.2.2.1.21
              syntax: gauge32
            - name:   ifSpecific
              oid:    1.3.6.1.2.1.2.2.1.22
              syntax: object identifier
    - name:    ifXTable
      enabled: true
      oid:     1.3.6.1.2.1.31.1.1
      augment: ifTable
      columns:
            - name:   ifName
              oid:    1.3.6.1.2.1.31.1.1.1.1
              syntax: octet string
            - name:   ifInMulticastPkts
              oid:    1.3.6.1.2.1.31.1.1.1.2
              syntax: counter32
            - name:   ifInBroadcastPkts
              oid:    1.3.6.1.2.1.31.1.1.1.3
              syntax: counter32
            - name:   ifOutMulticastPkts
              oid:    1.3.6.1.2.1.31.1.1.1.4
              syntax: counter32
            - name:   ifOutBroadcastPkts
              oid:    1.3.6.1.2.1.31.1.1.1.5
              syntax: counter32
            - name:   ifHcInOctets
              oid:    1.3.6.1.2.1.31.1.1.1.6
              syntax: counter64
            - name:   ifHcInUcastPkts
              oid:    1.3.6.1.2.1.31.1.1.1.7
              syntax: counter64
            - name:   ifHcInMulticastPkts
              oid:    1.3.6.1.2.1.31.1.1.1.8
              syntax: counter64
            - name:   ifHcInBroadcastPkts
              oid:    1.3.6.1.2.1.31.1.1.1.9
              syntax: counter64
            - name:   ifHcOutOctets
              oid:    1.3.6.1.2.1.31.1.1.1.10
              syntax: counter64
            - name:   ifHcOutUcastPkts
              oid:    1.3.6.1.2.1.31.1.1.1.11
              syntax: counter64
            - name:   ifHcOutMulticastPkts
              oid:    1.3.6.1.2.1.31.1.1.1.12
              syntax: counter64
            - name:   ifHcOutBroadcastPkts
              oid:    1.3.6.1.2.1.31.1.1.1.13
              syntax: counter64
            - name:   ifLinkUpDownTrapEnable
              oid:    1.3.6.1.2.1.31.1.1.1.14
              syntax: integer
            - name:   ifHighSpeed
              oid:    1.3.6.1.2.1.31.1.1.1.15
              syntax: gauge32
            - name:   ifPromiscuousMode
              oid:    1.3.6.1.2.1.31.1.1.1.16
              syntax: integer
            - name:   ifConnectorPresent
              oid:    1.3.6.1.2.1.31.1.1.1.17
              syntax: integer
            - name:   ifAlias
              oid:    1.3.6.1.2.1.31.1.1.1.18
              syntax: octet string
            - name:   ifCounterDiscontinuityTime
              oid:    1.3.6.1.2.1.31.1.1.1.19
              syntax: timeticks
    - name:    ifStackTable
      enabled: true
      oid:     1.3.6.1.2.1.31.1.2
      indexes:
            - name:    ifStackHigherLayer
              oid:     1.3.6.1.2.1.31.1.2.1.1 
              syntax:  integer
            - name:    ifStackLowerLayer
              oid:     1.3.6.1.2.1.31.1.2.1.2
              syntax:  integer
      columns:
            - name:    ifStackStatus
              oid:     1.3.6.1.2.1.31.1.2.1.3
              syntax:   integer
scalars:
    - name:     ifNumber
      enabled:  true
      oid:      1.3.6.1.2.1.2.1
      syntax:   integer
    - name:     ifTableLastChange
      enabled:  true
      oid:      1.3.6.1.2.1.31.1.5
      syntax:   timeticks
```

///

The table definition file has the following important top level fields:

* `paths`: Specifies the gNMI paths for retrieving data.
* `python-script`: References the uPython script used for data conversion.
* `tables`: Lists MIB tables, their structure, and their OIDs.
* `scalars`: Defines scalar OIDs.

Under the `tables` key you find the list of MIB table definitions, where each table has the following structure:

* `name`: Specifies the name of the SNMP table. This is used for identification and reference in the SNMP configuration.
* `enabled`: Determines whether the table is active (true) or inactive (false).
* `oid`: The base Object Identifier (OID) for the table. All rows and columns in the table are extensions of this base OID.
* `indexes`: Indexes uniquely identify rows in the table. Each index maps a specific OID to a value that differentiates rows. A list of column definitions that serve as unique identifiers for rows.
    * `name`: The name of the index column.
    * `oid`: The OID for the index.
    * `syntax`: The data type of the index value.
* `columns`: Columns represent attributes or properties for each row in the table. Each column is defined with an OID and a data type.
    * `name`: The name of the column.
    * `oid`: The OID for the column.
    * `syntax`: The data type of the column's value.
    * `binary`: (optional) Indicates if the value is base64-encoded.
    * `enabled`: (optional) Enables or disables the column.

The `syntax` field in SNMP table and scalar definitions specifies the data type of the OID value. Each data type maps to a specific ASN.1 type, defining how the data is represented and transmitted in SNMP operations. Below is a detailed explanation of the supported data types.

/// details | Data Types
    type: subtle-note

* `octet string`: Represents a sequence of octets (bytes). Commonly used for textual information (e.g., names, descriptions) or raw binary data. E.g: `ifDescr`.
* `integer / integer32`: Represents a signed 32-bit integer. Used for numeric attributes like counters, states, or enumerations. E.g: `ifType`, `ifAdminStatus`, `ifOperStatus`.
* `unsigned / unsigned32`: Represents an unsigned 32-bit integer. E.g: values that should not be negative like counts or identifiers.
* `counter / counter32`: Represents a counter that increments over time and wraps back to 0 when it exceeds the maximum value (4,294,967,295). E.g: `ifInOctets`, `ifOutOctets`.
* `counter64`: Represents a 64-bit counter for high-capacity devices or metrics with large values. E.g: `ifHCInOctets`, `ifHCOutOctets`.
* `gauge / gauge32`: Represents a non-negative integer that can increase or decrease but cannot wrap. E.g `ifSpeed`.
* `timeticks`: Represents time in hundredths of a second since a device was last initialized or restarted. E.g: `ifLastChange`.
* `ipaddress`: Represents an IPv4 address as a 32-bit value. Stored and transmitted in network byte order (big-endian).
* `object identifier`: Represents an OID as a series of numbers identifying objects or properties in the SNMP tree.
* `bits`: Represents a sequence of bits, often used to define flags or multiple binary states.
///

## Creating Custom MIBs

Users can create custom MIB definitions following these steps:

1. Define the Mapping File: Use YAML to specify paths, tables, scalars, and their structure.
2. Write the Conversion Script: Implement a `snmp_main` function in uPython that processes the input JSON and generates SNMP objects.
3. Add the mapping file to the list of table-definitions under `/etc/opt/srlinux/snmp/snmp_files_config.yaml`

### Input JSON Format

Recall, that SNMP framework is powered by the underlying SR Linux's gNMI infrastructure. The `paths` you define in the table mapping file will retrieve the data that the conversion script will work on to create the SNMP MIB tables.  

A thing to note is that the `paths` you define in the mapping file are non-recursive; this means that the returned data will be limited to the immediate children of the path you specify. To recursively retrieve data from a path, add `...` to the end of the path, e.g. `/interface/ethernet/...`.

The uPython script receives data in JSON format, including global SNMP information and the gNMI query results. Here is an example of a payload the `if_mib.py` script receives.

```{.json .code-scroll-lg}
{
  "_snmp_info_": {
    "boottime": "2024-11-11T16:42:44Z",
    "datetime": "2024-11-15T19:23:29Z",
    "debug": true,
    "is-cold-boot": false,
    "network-instance": "mgmt",
    "platform-type": "7220 IXR-D2",
    "script": "if_mib.yaml",
    "sysobjectid": "1.3.6.1.4.1.6527.1.20.22",
    "sysuptime": 35524500,
    "paths": [
      "/interface",
      "/interface/ethernet",
      "/interface/lag",
      "/interface/statistics",
      "/interface/transceiver",
      "/interface/subinterface",
      "/interface/subinterface/statistics"
    ],
    "scalars": [
      "ifNumber",
      "ifTableLastChange"
    ],
    "tables": [
      "ifTable",
      "ifXTable",
      "ifStackTable"
    ]
  },
  "interface": [
    {
      "name": "ethernet-1/1",
      "admin-state": "enable",
      "forwarding-complex": 0,
      "forwarding-mode": "store-and-forward",
      "ifindex": 16382,
      "last-change": "2024-11-11T16:42:50.815Z",
      "linecard": 1,
      "loopback-mode": "none",
      "mtu": 9232,
      "oper-state": "up",
      "tpid": "srl_nokia-interfaces-vlans:TPID_0X8100",
      "vlan-tagging": false,
      "ethernet": {
        "dac-link-training": false,
        "hw-mac-address": "1A:5E:00:FF:00:01",
        "lacp-port-priority": 32768,
        "port-speed": "25G"
      },
      "statistics": {
        "carrier-transitions": 0,
        "in-broadcast-packets": 0,
        "in-discarded-packets": 0,
        "in-error-packets": 0,
        "in-fcs-error-packets": 0,
        "in-multicast-packets": 11946,
        "in-octets": 2103314,
        "in-packets": 11946,
        "in-unicast-packets": 0,
        "out-broadcast-packets": 0,
        "out-discarded-packets": 0,
        "out-error-packets": 0,
        "out-mirror-octets": 0,
        "out-mirror-packets": 0,
        "out-multicast-packets": 11842,
        "out-octets": 2096034,
        "out-packets": 11842,
        "out-unicast-packets": 0
      },
      "transceiver": {
        "ddm-events": true,
        "forward-error-correction": "disabled",
        "oper-down-reason": "not-present",
        "oper-state": "down",
        "tx-laser": false
      }
    },
    {
      "name": "ethernet-1/10",
      "admin-state": "disable",
      "forwarding-complex": 0,
      "forwarding-mode": "store-and-forward",
      "ifindex": 311294,
      "last-change": "2024-11-11T16:42:47.867Z",
      "linecard": 1,
      "loopback-mode": "none",
      "oper-down-reason": "port-admin-disabled",
      "oper-state": "down",
      "ethernet": {
        "dac-link-training": false,
        "hw-mac-address": "1A:5E:00:FF:00:0A",
        "port-speed": "25G"
      },
      "transceiver": {
        "ddm-events": false,
        "forward-error-correction": "disabled",
        "oper-down-reason": "not-present",
        "oper-state": "down",
        "tx-laser": false
      }
    },
    {
      // ...
    },
}
```

### Output JSON Format

The script should output JSON containing tables and scalars.

```{.json .code-scroll-lg}
{
  "tables": {
    "ifTable": [
      {
        "path": "/interface[name=ethernet-1/1]",
        "objects": {
          "ifIndex": 16382,
          "ifDescr": "ethernet-1/1",
          "ifType": 6,
          "ifMtu": 9232,
          "ifSpeed": 4294967295,
          "ifPhysAddress": "0x1A5E00FF0001",
          "ifAdminStatus": 1,
          "ifOperStatus": 1,
          "ifLastChange": 600,
          "ifInOctets": 2103314,
          "ifInUcastPkts": 0,
          "ifInNUcastPkts": 11946,
          "ifInDiscards": 0,
          "ifInErrors": 0,
          "ifInUnknownProtos": 0,
          "ifOutOctets": 2096034,
          "ifOutUcastPkts": 0,
          "ifOutNUcastPkts": 11842,
          "ifOutDiscards": 0,
          "ifOutErrors": 0,
          "ifOutQLen": 0,
          "ifSpecific": "0.0"
        }
      },
      {
        ...
      }
    ]
  },
  "scalars": {
    "ifNumber": 58,
    "ifTableLastChange": 600
  }
}
```

### uPython script

The script entry point is a function called `snmp_main` that takes a JSON string as input and returns a JSON string.

```python
def snmp_main(in_json_str: str) -> str:
```

See the built-in scripts as examples.
The `/opt/srlinux/snmp/scripts/utilities.py` contains some useful helper functions to perform various checks and common type conversions.

## SR Linux Built-In Traps

Traps are defined with the mapping files that look similar to the MIB ones, but include additional parameters for triggers and variable bindings. As we've seen in the beginning of this document, the traps mapping files are listed in the global `/opt/srlinux/snmp/snmp_files_config.yaml`.

### Trap definitions

The trap definition YAML file has exactly the same top level elements as the table definition file but instead of `tables` the file contains `traps` top-level key. Here is the contents of the `/opt/srlinux/snmp/scripts/rfc3418_traps.yaml` mapping file that defines the traps as per RFC 3418:

/// details | `rfc3418_traps.yaml` definition file
    type: subtle-note

```yaml
python-script: rfc3418_traps.py
enabled: true
debug: false
traps:
    - name:    coldStart
      enabled: true
      oid:     1.3.6.1.6.3.1.1.5.1
      startup: true
      triggers:
          - /platform/chassis/last-booted
    - name:    warmStart
      enabled: true
      oid:     1.3.6.1.6.3.1.1.5.2
      startup: true
      triggers:
          - /platform/chassis/last-booted
    - name:    linkDown
      enabled: true
      oid:     1.3.6.1.6.3.1.1.5.3
      triggers:
          - /interface/oper-state
          - /interface/subinterface/oper-state
      context:
          - /interface
          - /interface/subinterface
      data:
          - indexes:
                - name:     ifIndex
                  syntax:   integer
            objects:
                - name:     ifIndex
                  oid:      1.3.6.1.2.1.2.2.1.1
                  syntax:   integer
                - name:     ifAdminStatus
                  oid:      1.3.6.1.2.1.2.2.1.7
                  syntax:   integer
                - name:     ifOperStatus
                  oid:      1.3.6.1.2.1.2.2.1.8
                  syntax:   integer
                - name:     ifName # non-standard, but useful
                  enabled:  true
                  oid:      1.3.6.1.2.1.31.1.1.1.1
                  syntax:   octet string
                  optional: true
    - name:    linkUp
      enabled: true
      oid:     1.3.6.1.6.3.1.1.5.4
      triggers:
          - /interface/oper-state
          - /interface/subinterface/oper-state
      context:
          - /interface
          - /interface/subinterface
      data:
          - indexes:
                - name:     ifIndex
                  syntax:   integer
            objects:
                - name:     ifIndex
                  oid:      1.3.6.1.2.1.2.2.1.1
                  syntax:   integer
                - name:     ifAdminStatus
                  oid:      1.3.6.1.2.1.2.2.1.7
                  syntax:   integer
                - name:     ifOperStatus
                  oid:      1.3.6.1.2.1.2.2.1.8
                  syntax:   integer
                - name:     ifName # non-standard, but useful
                  enabled:  true
                  oid:      1.3.6.1.2.1.31.1.1.1.1
                  syntax:   octet string
                  optional: true
    - name:      authenticationFailure
      enabled:   true
      hardcoded: true
      oid:       1.3.6.1.6.3.1.1.5.5
```

///

Besides the common `name`, `enabled` and `oid` fields, the `traps` object has the following fields:

* `triggers`: Specifies paths that trigger the trap.
* `context`: Additional paths to fetch data for the trap.
* `data`: Defines variable bindings included in the trap.

## Creating Custom Traps

To define custom traps:

1. Write a YAML Mapping File: Define the trap triggers, contexts, and variable bindings.
2. Implement the Conversion Script: Process trigger events and generate trap data in the `snmp_main` function.
3. Add the mapping file to the list of trap-definitions under `/etc/opt/SR Linux/snmp/snmp_files_config.yaml`

### Input JSON Format

The Python script receives a JSON object containing trap triggers and context data.

```{.json .code-scroll-lg}
{
  "_snmp_info_": {
    "boottime": "2024-11-11T16:42:44Z",
    "datetime": "2024-11-15T21:30:25Z",
    "debug": true,
    "is-cold-boot": false,
    "network-instance": "mgmt",
    "platform-type": "7220 IXR-D2",
    "script": "rfc3418_traps.yaml",
    "sysobjectid": "1.3.6.1.4.1.6527.1.20.22",
    "sysuptime": 36286100,
    "trigger": "/interface[name=ethernet-1/1]",
    "paths": [
      "/interface[name=ethernet-1/1]",
      "/interface[name=ethernet-1/1]/subinterface"
    ]
  },
  "_trap_info_": [
    {
      "name": "linkDown",
      "new-value": "up",
      "old-value": "down",
      "trigger": "/interface/oper-state",
      "xpath": "/interface[name=ethernet-1/1]/oper-state"
    },
    {
      "name": "linkUp",
      "new-value": "up",
      "old-value": "down",
      "trigger": "/interface/oper-state",
      "xpath": "/interface[name=ethernet-1/1]/oper-state"
    }
  ],
  "interface": [
    {
      "name": "ethernet-1/1",
      "admin-state": "enable",
      "forwarding-complex": 0,
      "forwarding-mode": "store-and-forward",
      "ifindex": 16382,
      "last-change": "2024-11-15T21:30:25.701Z",
      "linecard": 1,
      "loopback-mode": "none",
      "mtu": 9232,
      "oper-state": "up",
      "tpid": "srl_nokia-interfaces-vlans:TPID_0X8100",
      "vlan-tagging": false,
      "subinterface": [
        {
          "index": 0,
          "admin-state": "disable",
          "ifindex": 1,
          "ip-mtu": 1500,
          "last-change": "2024-11-15T21:24:47.797Z",
          "name": "ethernet-1/1.0",
          "oper-down-reason": "admin-disabled",
          "oper-state": "down",
          "type": "routed"
        }
      ]
    }
  ]
}
```

### Output JSON Format

The script should return a list of traps.

```{.json .code-scroll-lg}
{
  "traps": [
    {
      "trap": "linkUp",
      "path": "/interface[name=ethernet-1/1]",
      "indexes": {
        "ifIndex": 16382
      },
      "objects": {
        "ifIndex": 16382,
        "ifAdminStatus": 1,
        "ifOperStatus": 1,
        "ifName": "ethernet-1/1"
      }
    }
  ]
}
```

### uPython script

The script entry point is a function called `snmp_main` that takes a JSON string as input and returns a JSON string.

```python
def snmp_main(in_json_str: str) -> str:
```

See the built-in scripts as examples.
The `/opt/srlinux/snmp/scripts/utilities.py` file contains some useful helper functions to perform various checks and common type conversions.

## Directory Structure for Custom Files

Place user-defined files under `/etc/opt/srlinux/snmp`.

Changes to mapping files and scripts are not automatically picked up by the SNMP server,
a restart of the SNMP server is required.

```srl
A:srl1# /tools system app-management application snmp_server-mgmt restart
```

## Debugging and Troubleshooting

Debug files are generated in `/tmp/snmp_debug/$NETWORK_INSTANCE`:

* Input/Output Logs: Check `.json_input`, `.json_output`, `.console` and `.error` files for debugging script execution.
  The `.console` files contain anything printed by the scripts and the `.error` files contain mapping and scripts errors.
* Path Data: Inspect debug outputs for issues in path retrieval.

## Example: gRPCServer MIB

Let's add a custom SNMP MIB to SR Linux at **runtime**, no feature requests, no software upgrades,
let it be a gRPC server SNMP MIB 🤪.

1. Add a new table definition under `/etc/opt/srlinux/snmp/scripts/grpc_mib.yaml`

This MIB has a single index `gRPCServerName` and 6 columns; the gRPC server network instance, its admin and operational states, the number of accepted and rejected RPCs as well as the last time an RPC was accepted.

All these fields can be mapped from leaves that can be found under the xpath `/system/grpc-server/...`

```yaml
###########################################################################
# Description:
#
# Copyright (c) 2024 Nokia
###########################################################################
# yaml-language-server: $schema=../table_definition_schema.json
paths:
    - /system/grpc-server/...
python-script: grpc_mib.py
enabled: true
debug: true
tables:
    - name:    gRPCServerTable
      enabled: true
      oid:     1.3.6.1.4.1.6527.115.114.108.105.110.117.120
      indexes:
            - name:   gRPCServerName
              oid:    1.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.1
              syntax: octet string
      columns:
            - name:   grpcServerNetworkInstance
              oid:    1.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.2
              syntax: octet string
            - name:   grpcServerAdminState
              oid:    1.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.3
              syntax: integer
            - name:   grpcServerOperState
              oid:    1.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.4
              syntax: integer
            - name:   grpcServerAccessRejects
              oid:    1.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.5
              syntax: integer
            - name:   grpcServerAccessAccepts
              oid:    1.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.6
              syntax: integer
            - name:   grpcServerLastAccessAccept
              oid:    1.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.7
              syntax: timeticks
```

2. The YAML file points to a python script called `grpc_mib.py`. It must be placed in the same directory as the `grpc_mib.yaml` file.

The script is fairly simple; grabs the JSON input, set some global SNMP information such as the box boot time (useful for calculating time ticks values).
After that, it iterates over the list of gRPC servers in the input JSON and set each server's columns values (with the correct format) in the prepared output dict.
Finally it returns the output dict as a JSON blob.

```python
#!/usr/bin/python
###########################################################################
# Description:
#
# Copyright (c) 2024 Nokia
###########################################################################

import json

import utilities

SERVERADMINSTATUS_UP   = 1
SERVERADMINSTATUS_DOWN = 2

IFOPERSTATUS_UP        = 1
IFOPERSTATUS_DOWN      = 2

# maps the gNMI admin status value to its corresponding SNMP value
def convertAdminStatus(value: str):
    if value is not None:
        if value == 'enable':
            return SERVERADMINSTATUS_UP
        elif value == 'disable':
            return SERVERADMINSTATUS_DOWN

# maps the gNMI oper status value to its corresponding SNMP value
def convertOperStatus(value: str):
    if value is not None:
        if value == 'up':
            return IFOPERSTATUS_UP
        elif value == 'down':
            return IFOPERSTATUS_DOWN

#
# main routine
#
def snmp_main(in_json_str: str) -> str:
    in_json = json.loads(in_json_str)

    del in_json_str

    # read in general info from the snmp server
    snmp_info = in_json.get('_snmp_info_')
    utilities.process_snmp_info(snmp_info)

    # prepare the output dict
    output = {"tables": {"gRPCServerTable": []}}

    # Iterate over all grpc-server instances
    grpc_servers = in_json.get("system", {}).get("grpc-server", [])
    for server in grpc_servers:
        # Extract required fields
        name = server.get("name", "")
        statistics = server.get("statistics", {})
        access_rejects = statistics.get("access-rejects", 0)
        access_accepts = statistics.get("access-accepts", 0)
        # Grab the last-access-accept timestamp
        ts = utilities.parse_rfc3339_date(statistics.get("last-access-accept", 0))
        # Convert it to timeTicks from boottime
        last_access_accept = utilities.convertUnixTimeStampInTimeticks(ts)

        # Append the object to the output
        output["tables"]["gRPCServerTable"].append({
            "objects": {
                "gRPCServerName": name,
                "grpcServerNetworkInstance": server.get("network-instance", ""),
                "grpcServerAdminState": convertAdminStatus(server.get("admin-state", "")),
                "grpcServerOperState": convertOperStatus(server.get("oper-state")),
                "grpcServerAccessRejects": access_rejects,
                "grpcServerAccessAccepts": access_accepts,
                "grpcServerLastAccessAccept": last_access_accept
            }
        })

    return json.dumps(output)
```

3. Reference the YAML mapping file in the user's `snmp_files_config.yaml` so that the SNMP server picks it up

```shell
cat /etc/opt/srlinux/snmp/snmp_files_config.yaml

table-definitions:
  - scripts/grpc_mib.yaml
```

4. Restart the SNMP server process

```
--{ + running }--[  ]--
A:srl1# /tools system app-management application snmp_server-mgmt restart
/system/app-management/application[name=snmp_server-mgmt]:
    Application 'snmp_server-mgmt' was killed with signal 9

/system/app-management/application[name=snmp_server-mgmt]:
    Application 'snmp_server-mgmt' was restarted
```

5. Test your new MIB

```shell
$ snmpwalk -v2c -c public clab-snmp-srl1 1.3.6.1.4.1.6527.115

iso.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.2.4.109.103.109.116 = STRING: "mgmt"                            # <-- grpcServerNetworkInstance
iso.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.3.4.109.103.109.116 = INTEGER: 1                                # <-- gRPCServerAdminState
iso.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.4.4.109.103.109.116 = INTEGER: 1                                # <-- grpcServerOperState
iso.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.5.4.109.103.109.116 = INTEGER: 0                                # <-- grpcServerAccessRejects
iso.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.6.4.109.103.109.116 = INTEGER: 3                                # <-- grpcServerAccessAccepts
iso.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.7.4.109.103.109.116 = Timeticks: (44659000) 5 days, 4:03:10.00  # <-- grpcServerLastAccessAccept
```

Have a look at `/tmp/snmp_debug` to see the input and output JSON blobs.

There you have it: A user-defined SNMP MIB added to SR Linux at **runtime**, no feature request, no software upgrade needed.
