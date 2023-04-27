# `get` Module

Get module is used to retrieve configuration and state from SR Linux devices. Users provide the datastore from which the data is retrieved and the paths to enclosing node or leaf. The module returns the requested data in JSON format.

=== "Example playbook"
    ```yaml
    - name: Get container
    hosts: clab
    gather_facts: false
    tasks:
      - name: Get /system/information container
        nokia.srlinux.get:
          paths:
            - path: /system/information
              datastore: state
              yang_models: srl #(1)!
        register: response

      - debug:
        var: response
    ```

    1. `srl` YANG model is used when unspecified, so in this case this parameter could have been omitted. It is provided for demonstration purposes.
=== "Response"
    ```yaml
    ok: [clab-ansible-srl] => {
        "response": {
            "changed": false,
            "failed": false,
            "failed_when_result": false,
            "jsonrpc_req_id": 65031,
            "jsonrpc_version": "2.0",
            "result": [
                {
                    "current-datetime": "2023-04-26T21:29:47.554Z",
                    "description": "SRLinux-v23.3.1-343-gab924f2e64 7250 IXR-6 Copyright (c) 2000-2020 Nokia. Kernel 5.15.0-67-generic #74-Ubuntu SMP Wed Feb 22 14:14:39 UTC 2023",
                    "last-booted": "2023-04-26T20:14:35.789Z",
                    "version": "v23.3.1-343-gab924f2e64"
                }
            ]
        }
    }
    ```

## Parameters

### paths

The `paths` parameter is a list of dictionaries. Each dictionary contains parameters used to identify the data to be retrieved.

#### path

<small>**required** · type: string</small>

The `path` parameter is a string that identifies the path to the yang node from which to retrieve the data. The path is provided in the XPATH-like notation and is relative to the root of the [datastore](#datastore).

SR Linux users are encouraged to use [YANG Browser](../../yang/browser.md) to explore the YANG model and identify the paths to the data they want to retrieve.

#### datastore

<small>type: string</small>

The `datastore` parameter is a string that identifies the datastore from which to retrieve the data. When omitted, the `running` datastore is used.

The following datastore values are available:

* `running` - the current configuration of the system
* `candidate` - the configuration that is being edited but not yet committed
* `baseline` - the configuration that was used to "fork" candidate from
* `tools` - the datastore used to store operational commands
* `state` - the current state of the system

#### yang_models

<small>type: string</small>

The `yang_models` parameter selects which [YANG model](../../yang/index.md) is used with a specified path. SR Linux Network OS supports the following two values for the `yang_models` parameter:

1. `srl` - SR Linux native YANG model
2. `oc` - Openconfig model

The default value for the `yang_models` parameter is `srl`, and if the parameter is omitted, the SR Linux native YANG model is assumed. Thus, this parameter is used when users want to retrieve data from the device using Openconfig model.

## Return values

Module returns the results in a structured format with Ansible common return values and module specific values.

```json
{
  "changed": false,
  "failed": false,
  "jsonrpc_req_id": 50861,
  "jsonrpc_version": "2.0",
  "result": [
    {
      "current-datetime": "2023-04-27T09:23:07.382Z",
      "version": "v23.3.1-343-gab924f2e64"
    }
  ]
}
```

### changed

<small>type: boolean</small>

For `get` module the `changed` value is always `false`, as retrieval operations never result in changing state of the device.

### failed

<small>type: boolean</small>

The `failed` value indicates if any errors occurred during the execution of the module. The `failed` value is `false` when the module completes successfully, and `true` otherwise. See the [Error handling](#error-handling) section for more details.

### jsonrpc_req_id

<small>type: integer</small>

The `jsonrpc_req_id` value is an random integer that the module uses for the JSON-RPC request body. The value is used to match the request with the response when, for instance, checking the JSON-RPC server logs on the device.

### jsonrpc_version

<small>type: string</small>

The `jsonrpc_version` value is a string that indicates the JSON-RPC version used by the module. The value is always `2.0` and is not user configurable.

### result

<small>type: list of any</small>

The `result` value is a list of returned data. The list order matches the order of the `paths` parameter. Such that the first element of the `result` list contains the data retrieved from the first element of the `paths` list.

The type of the data returned depends on the `path` parameter. For instance, if the `path` parameter points to a leaf, the value of the leaf is returned. If the `path` parameter points to a container, the container is returned as a dictionary. See examples to see the data returned for different `path` parameters.

## Error handling

The `get` module sets the [`failed`](#failed) return value to `true` when any errors occurred during the module execution. The error message is therefore returned in the `msg` field of the return value.

Consider the following output when a wrong path is used by the user of a module:

=== "playbook"

    ```yaml
    - name: Get wrong path
      hosts: clab
      gather_facts: false
      tasks:
        - name: Get wrong path
          nokia.srlinux.get:
            paths:
              - path: /system/informations
                datastore: state
    ```

=== "response"

    ```bash
    fatal: [clab-ansible-srl]: FAILED! => {"changed": false, "jsonrpc_req_id": 11505, "msg": "Path not valid - unknown element 'informations'. Options are [features, trace-options, management, configuration, aaa, authentication, boot, lacp, lldp, mtu, name, dhcp-server, event-handler, mpls, gnmi-server, tls, gribi-server, json-rpc-server, bridge-table, license, dns, ntp, clock, ssh-server, ftp-server, snmp, sflow, load-balancing, banner, information, logging, multicast, network-instance, p4rt-server, maintenance, app-management]"}
    ```

## Examples

## Source code

Get module is implemented in the [`get.py`][get-gh-url] file.

[get-gh-url]: https://github.com/nokia/srlinux-ansible-collection/blob/main/plugins/modules/get.py
