---
comments: true
---

# Customizing SNMP MIBs for Gets and Traps in SR Linux

SR Linux version 24.10.1 introduces a customizable SNMP framework allowing you to define your own SNMP management information bases (MIBs) for gets and traps. This same framework powers [SR Linux's built-in MIBs and traps](https://documentation.nokia.com/srlinux/24-10/books/system-mgmt/snmp.html), offering flexibility that customizes SNMP MIBs to the specific requirements for your network.

The framework defines:

* Mapping files (YAML): To define MIB tables and object identifiers (OIDs).
* Conversion scripts ([uPython](https://micropython.org/)): To process data from the management server via gNMI and convert it for SNMP.

## SR Linux Built-In MIBs for Gets

Built-in MIB mappings are defined in the configuration file available on the SR Linux's file system:

```{.bash .no-select}
cat /opt/srlinux/snmp/snmp_files_config.yaml
```

<div class="embed-result">
```{.yaml .no-copy .no-select}
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

A simple list of supported OIDs for monitoring is in `/etc/opt/srlinux/snmp/numbers.txt`, and a detailed list with script information is in `/etc/opt/srlinux/snmp/exportedOids` when an `/ system snmp access-group` is configured. These files are created at runtime when the SNMP server is started.

### Table Definitions

The table definition YAML file describes the framework components used to define a particular MIB table. Take the `if_mib.yaml` file for example, it maps interface-related data to standard MIB tables such as `ifTable`, `ifXTable`, and `ifStackTable`.

You can list the contents of this file with `cat /opt/srlinux/snmp/scripts/if_mib.yaml` and it is below for reference:

/// details | `if_mib.yaml` Definition File
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
* `python-script`: References the Python script used for data conversion.
* `tables`: Lists MIB tables, their structure, and their OIDs.
* `scalars`: Defines scalar OIDs.

You can see the list of MIB table definitions in the `tables` list, where each table has the following structure:

* `name`: Specifies the name of the SNMP table. This is used for identification and reference in the SNMP configuration.
* `enabled`: Defines whether the table is active (true) or inactive (false).
* `oid`: The base OID for the table. All rows and columns in the table are extensions of this base OID.
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

You can create custom MIB definitions following these steps:

1. Define the mapping file: Specify paths, tables, scalars, and their structure in YAML.
2. Write the conversion script: Implement a `snmp_main` function in Python that processes the input JSON and generates SNMP objects.
3. Add the mapping file to the list of table definitions to `/etc/opt/srlinux/snmp/snmp_files_config.yaml`.

/// admonition | Location of Built-in and Custom SNMP Framework Files
    type: subtle-note
The user-defined MIB definitions and files with the associated scripts are stored in `/etc/opt/srlinux/snmp` directory, while the built-in MIB definitions are stored in `/opt/srlinux/snmp` directory.
///

### Input JSON Format

The SNMP framework is powered by the underlying SR Linux's gNMI infrastructure. The `paths` you define in the table mapping file will retrieve the data that the conversion script will use to create the SNMP MIB tables.

Note that the `paths` you define in the mapping file are non-recursive; this means that the returned data will be limited to the immediate children of the path you specify. To recursively retrieve data from a path, add `...` to the end of the path, e.g. `/interface/ethernet/...`.

The Python script receives data in JSON format, including global SNMP information and the gNMI query results. Here is an example of a payload the `if_mib.py` script receives.

```{.json .code-scroll-lg}
{
  "_snmp_info_": {
    "boottime": "2024-11-11T16:42:44Z",
    "datetime": "2024-11-15T19:23:29Z",
    "debug": false,
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

The script outputs JSON containing tables and scalars.

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

### Python Script

The script entry point is a function called `snmp_main` that takes a JSON string as input and returns a JSON string.

```python
def snmp_main(in_json_str: str) -> str:
```

Refer to the built-in scripts as examples. The `/opt/srlinux/snmp/scripts/utilities.py` script contains some useful helper functions to perform various checks and common type conversions.

## SR Linux Built-In Traps

Traps are defined with mapping files that look similar to the MIB files, but include additional parameters for triggers and variable bindings. As you have seen in the beginning of this document, the traps mapping files are listed in the global `/opt/srlinux/snmp/snmp_files_config.yaml`.

A list of OIDs available for traps is in `/etc/opt/srlinux/snmp/installedTraps` when a `trap-group` is configured. This file is created at runtime when the SNMP server is started.

### Trap Definitions

The trap definition YAML file has exactly the same top level elements as the table definition file but instead of `tables` the file contains `traps` top-level list. Here is the contents of the `/opt/srlinux/snmp/scripts/rfc3418_traps.yaml` mapping file that defines the traps as per RFC 3418:

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

1. Define the mapping file: Define the trap triggers, contexts, and variable bindings in YAML.
2. Write the conversion script: Implement trigger events and generate trap data in the `snmp_main` function.
3. Add the mapping file to the list of trap definitions to `/etc/opt/srlinux/snmp/snmp_files_config.yaml`.

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

The script returns a list of traps.

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

### Python Script

The script entry point is a function called `snmp_main` that takes a JSON string as input and returns a JSON string.

```python
def snmp_main(in_json_str: str) -> str:
```

Refer to the built-in scripts as examples.  The `/opt/srlinux/snmp/scripts/utilities.py` script contains some useful helper functions to perform various checks and common type conversions.

## Directory Structure for Custom Files

Place user-defined files in `/etc/opt/srlinux/snmp`.

Changes to mapping files and scripts are not automatically read by the SNMP server, a restart of the SNMP server is required.

```srl
--{ running }--[  ]--
A:srl1# /tools system app-management application snmp_server-mgmt restart
```

## Debugging and Troubleshooting

Debug files are generated in `/tmp/snmp_debug/$NETWORK_INSTANCE` when `debug: true` is set in the YAML configuration file.

* For MIBs: check `/etc/opt/srlinux/snmp/exportedOids` for your OIDs and make sure an `/ system snmp access-group` is configured.
* For traps: check `/etc/opt/srlinux/snmp/installedTraps` for your traps and make sure a `/ system snmp trap-group` is configured.
* Input/output logs: Check `.json_input`, `.json_output`, `.console` and `.error` files for debugging script execution.  The `.console` files contain output printed by the scripts and the `.error` files contain mapping and scripts errors.
* Path data: Inspect debug outputs for issues in path retrieval.

## Examples

### gRPCServer MIB

Let's add a custom SNMP MIB to SR Linux at **runtime**, no feature requests, no software upgrades, by creating a gRPC server SNMP MIB 🤪.

#### Table Definition

Add a new table definition to `/etc/opt/srlinux/snmp/scripts/grpc_mib.yaml`.

This MIB has a single index `gRPCServerName` and 6 columns; the gRPC server network instance, its admin and operational states, the number of accepted and rejected RPCs and the last time an RPC was accepted.

All of these fields can be mapped from leafs that are found under the XPath `/system/grpc-server/...`

```{.yaml .code-scroll-lg}
--8<-- "https://raw.githubusercontent.com/srl-labs/srl-snmp-framework-lab/refs/heads/main/grpc_mib.yaml"
```

#### Python Script

The YAML file references a Python script called `grpc_mib.py`. It must be placed in the same directory as the `grpc_mib.yaml` file.

The script is fairly simple; it grabs the JSON input and sets some global SNMP information such as the system boot time (useful for calculating time ticks values).  After that, it iterates over the list of gRPC servers in the input JSON and set each server's columns values (with the correct format) in the prepared output dict.  Finally it returns the output dict as a JSON blob.

```{.python .code-scroll-lg}
--8<-- "https://raw.githubusercontent.com/srl-labs/srl-snmp-framework-lab/refs/heads/main/grpc_mib.py"
```

#### Custom MIBs File

Reference the YAML mapping file in the your `snmp_files_config.yaml` so that the SNMP server loads it.

```{.bash .no-select}
cat /etc/opt/srlinux/snmp/snmp_files_config.yaml
```

<div class="embed-result">
```{.yaml .no-copy .no-select}
table-definitions:
  - scripts/grpc_mib.yaml
```
</div>

#### SNMP Server Restart

Restart the SNMP server process for it to load the new custom MIB definitions.

```srl
--{ running }--[  ]--
A:srl1# /tools system app-management application snmp_server-mgmt restart
/system/app-management/application[name=snmp_server-mgmt]:
    Application 'snmp_server-mgmt' was killed with signal 9

/system/app-management/application[name=snmp_server-mgmt]:
    Application 'snmp_server-mgmt' was restarted
```

#### Test Your New MIB

You can test your new MIB using tools like `snmpwalk`.

```{.bash .no-select}
snmpwalk -v 2c -c public snmp-srl 1.3.6.1.4.1.6527.115 #(1)!
```

1. If you do not have `snmpwalk` CLI installed, you can use the docker container and setup a handy alias:

    ```{.bash .no-select}
    alias snmpwalk='sudo docker run --network clab \
    -i ghcr.io/hellt/net-snmp-tools:5.9.4-r0 \
    snmpwalk -O n'
    ```

<div class="embed-result">
```{.text .no-select .no-copy}
iso.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.2.4.109.103.109.116 = STRING: "mgmt"                            # <-- grpcServerNetworkInstance
iso.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.3.4.109.103.109.116 = INTEGER: 1                                # <-- gRPCServerAdminState
iso.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.4.4.109.103.109.116 = INTEGER: 1                                # <-- grpcServerOperState
iso.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.5.4.109.103.109.116 = INTEGER: 0                                # <-- grpcServerAccessRejects
iso.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.6.4.109.103.109.116 = INTEGER: 3                                # <-- grpcServerAccessAccepts
iso.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.7.4.109.103.109.116 = Timeticks: (44659000) 5 days, 4:03:10.00  # <-- grpcServerLastAccessAccept
```
</div>

Have a look at `/tmp/snmp_debug` to see the input and output JSON blobs when `debug: true` is set in the YAML configuration file.

There you have it: a user-defined SNMP MIB added to SR Linux at **runtime**, no feature request, no software upgrade needed.

### gRPCServer Traps

Similar to the SNMP MIB, let's add custom SNMP traps to SR Linux at **runtime**, no feature requests, no software upgrades, by creating a gRPC server SNMP trap 🤪. Traps are independant from MIBs and do not need a corresponding MIB that is used for SNMP gets.

#### Trap Definitions

Add a new trap definitions to `/etc/opt/srlinux/snmp/scripts/grpc_traps.yaml`.

Two traps are defined:

* gRPCServerDown: sent when a gRPC server goes down.
* gRPCServerUp: sent when a gRPC server comes up, including at startup.

Both of these traps are triggered from the `/system/grpc-server/oper-state` XPath.

```{.yaml .code-scroll-lg}
python-script: grpc_traps.py
enabled: true
debug: false
traps:
    - name:    gRPCServerDown
      enabled: true
      oid:     1.3.6.1.4.1.6527.115.114.108.105.110.117.122
      triggers:
          - /system/grpc-server/oper-state
      data:
          - objects: # this object is a scalar, does not use an index
                - name: gRPCServerName
                  oid:  1.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.1
                  syntax: octet string
    - name:    gRPCServerUp
      enabled: true
      startup: true
      oid:     1.3.6.1.4.1.6527.115.114.108.105.110.117.123
      triggers:
          - /system/grpc-server/oper-state
      data:
          - objects: # this object is a scalar, does not use an index
                - name: gRPCServerName
                  oid:  1.3.6.1.4.1.6527.115.114.108.105.110.117.120.1.1
                  syntax: octet string
```

#### Python Script

The YAML file references a Python script called `grpc_traps.py`. It must be placed in the same directory as the `grpc_mib.yaml` file.

The script is fairly simple; it grabs the JSON input and looks for the gRPC server name to add as a variable binding. You can add additional variable bindings to traps that are relevant if you want, but in this case we only need one for the server name. Finally it returns the output dict as a JSON blob.

```{.python .code-scroll-lg}
###########################################################################
# Description:
#
# Copyright (c) 2025 Nokia
###########################################################################

import json
from collections import OrderedDict

import utilities

# list of traps that will be echoed back to the
traps_list_db: list = []

IFOPERSTATUS_UP             = 1
IFOPERSTATUS_DOWN           = 2
IFOPERSTATUS_TESTING        = 3
IFOPERSTATUS_UNKNOWN        = 4

def convertOperStatus(value: str) -> int:
    if value is not None:
        if value == 'up':
            return IFOPERSTATUS_UP
        elif value == 'down' or value == 'testing' : # RFC2863 section 3.1.15
            return IFOPERSTATUS_DOWN
    return IFOPERSTATUS_UNKNOWN


def store_value_in_json(json_obj:dict, name:str, value) -> None:
    if value is not None:
        json_obj[name] = value


def gRPCServerUpgRPCServerDownTrap(system: list, trap: dict) -> None:
    trap_name = trap.get('name')
    if trap_name is not None:
        row = OrderedDict()
        objects = OrderedDict()

        objects["gRPCServerName"] = system["grpc-server"][0]["name"]

        row['trap'] = trap_name
        row['indexes'] = OrderedDict()  # no indexes to report
        row['objects'] = objects
        traps_list_db.append(row)


#
# main routine
#
def snmp_main(in_json_str: str) -> str:
    global traps_list_db

    in_json = json.loads(in_json_str)

    del in_json_str

    # read in general info from the snmp server
    snmp_info = in_json.get('_snmp_info_')
    utilities.process_snmp_info(snmp_info)

    # read in info about the traps that will be triggered in this request (depending on the trigger)
    trap_info = in_json.get('_trap_info_')

    # read in context data
    system = in_json.get('system', [])

    del in_json

    for trap in trap_info:
        name = trap['name']
        trigger = trap['trigger']
        #print(f'do trap {name} for {trigger}')

        if utilities.is_simulated_trap():
            if name == 'gRPCServerDown':
                gRPCServerUpgRPCServerDownTrap(system, trap)
            elif name == 'gRPCServerUp':
                gRPCServerUpgRPCServerDownTrap(system, trap)
            else:
                raise ValueError(f'Unknown trap {name} with trigger {trigger}')

        else:
            if name == 'gRPCServerDown':
                gRPCServerUpgRPCServerDownTrap(system, trap)
            elif name == 'gRPCServerUp':
                gRPCServerUpgRPCServerDownTrap(system, trap)
            else:
                raise ValueError(f'Unknown trap {name} with trigger {trigger}')

    response:dict = {}

    response['traps'] = traps_list_db

    del system, traps_list_db

    return json.dumps(response)

```

#### Custom Traps File

Reference the YAML mapping file in the your `snmp_files_config.yaml` so that the SNMP server loads it.

```{.bash .no-select}
cat /etc/opt/srlinux/snmp/snmp_files_config.yaml
```

<div class="embed-result">
```{.yaml .no-copy .no-select}
trap-definitions:
  - scripts/grpc_traps.yaml
```
</div>

#### SNMP Server Restart

Restart the SNMP server process for it to load the new custom traps.

```srl
--{ running }--[  ]--
A:srl1# /tools system app-management application snmp_server-mgmt restart
/system/app-management/application[name=snmp_server-mgmt]:
    Application 'snmp_server-mgmt' was killed with signal 9

/system/app-management/application[name=snmp_server-mgmt]:
    Application 'snmp_server-mgmt' was restarted
```

#### Test Your New Traps

Test your new traps by sending them from SR Linux.

```srl
--{ running }--[  ]--
A:srl1# /tools system snmp trap gRPCServerDown force trigger "/system/grpc-server[name=mgmt]/oper-state"
/:
    Trap gRPCServerDown was sent

--{ running }--[  ]--
A:srl1# /tools system snmp trap gRPCServerUp force trigger "/system/grpc-server[name=mgmt]/oper-state"
/:
    Trap gRPCServerUp was sent
```

You can see the traps being received on a Unix host using tools like `snmptrapd`.

```bash
# snmptrapd -f -Lo
NET-SNMP version 5.9.1
2025-01-22 16:29:49 srlinux.example.com [UDP: [192.168.0.12]:54880->[192.168.0.10]:162]:
DISMAN-EVENT-MIB::sysUpTimeInstance = Timeticks: (540800) 1:30:08.00 # <-- sysUpTime
SNMPv2-MIB::snmpTrapOID.0 = OID: SNMPv2-SMI::enterprises.6527.115.114.108.105.110.117.122 # <-- gRPCServerDown
SNMPv2-SMI::enterprises.6527.115.114.108.105.110.117.120.1.1.0 = STRING: "mgmt" # <-- gRPCServerName
2025-01-22 16:29:56 srlinux.example.com [UDP: [192.168.0.12]:54880->[192.168.0.10]:162]:
DISMAN-EVENT-MIB::sysUpTimeInstance = Timeticks: (541500) 1:30:15.00 # <-- sysUpTime
SNMPv2-MIB::snmpTrapOID.0 = OID: SNMPv2-SMI::enterprises.6527.115.114.108.105.110.117.123 # <-- gRPCServerUp
SNMPv2-SMI::enterprises.6527.115.114.108.105.110.117.120.1.1.0 = STRING: "mgmt" # <-- gRPCServerName
```

Have a look at `/tmp/snmp_debug` to see the input and output JSON blobs when `debug: true` is set in the YAML configuration file.

#### Input JSON Blob

```{.bash .no-select}
cat /tmp/snmp_debug/mgmt/grpc_traps.json_input
```

<div class="embed-result">
```{.json .code-scroll-lg .no-copy}
// comments will be removed before sending to the python-script
{
        "_snmp_info_":  {
                "boottime":     "2025-01-22T19:59:41Z",
                "datetime":     "2025-01-22T21:29:56Z",
                "debug":        true,
                "is-cold-boot": false,
                "is-forced-trap":       true,
                "is-simulated-trap":    true,
                "network-instance":     "mgmt",
                "platform-type":        "7220 IXR-D2L",
                "script":       "grpc_traps.yaml",
                "sysobjectid":  "1.3.6.1.4.1.6527.1.20.26",
                "sysuptime":    541500,
                "trigger":      "/system/grpc-server[name=mgmt]/oper-state",
                "paths":        ["/system/grpc-server[name=mgmt]/oper-state"]
        },
        "_trap_info_":  [{
                        "name": "gRPCServerUp",
                        "current-value":        "up",
                        "simulated-value":      "up",
                        "startup":      true,
                        "trigger":      "/system/grpc-server/oper-state",
                        "xpath":        "/system/grpc-server[name=mgmt]/oper-state"
                }],
        "system":       {
                "grpc-server":  [{
                                // Path:        "/system/grpc-server[name=mgmt]"
                                "name": "mgmt",
                                "oper-state":   "up"
                        }]
        }
}
```
</div>

#### Output JSON Blob

```{.bash .no-select}
cat /tmp/snmp_debug/mgmt/grpc_traps.json_output
```

<div class="embed-result">
```{.json .no-copy .no-select}
{
        "traps":        [{
                        "trap": "gRPCServerUp",
                        "indexes":      {
                        },
                        "objects":      {
                                "gRPCServerName":       "mgmt"
                        }
                }]
}
```
</div>

There you have it: user-defined SNMP traps added to SR Linux at **runtime**, no feature request, no software upgrade needed.

## MIB and Trap Lab Example

We created [a lab](https://github.com/srl-labs/srl-snmp-framework-lab) that implements this custom gRPC server MIB and traps that you can deploy locally or in Codespaces to try it out.

## Conclusion

The SR Linux customizable SNMP framework allows you to define your own SNMP MIBs for gets and traps that customize SNMP functionalities to your specific requirements at **runtime**, no feature request, no software upgrade needed.
