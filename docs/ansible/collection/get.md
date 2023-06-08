---
comments: true
title: Get Module
---

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

<small>choice: **`srl`**, `oc`</small>

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

The `failed` value indicates if any errors occurred during the execution of the module. The `failed` value is `false` when the module completes successfully and `true` otherwise. See the [Error handling](#error-handling) section for more details.

### jsonrpc_req_id

<small>type: string</small>

The `jsonrpc_req_id` value is a string identifier that the module uses for the JSON-RPC request. The value is used to match the request with the response when, for instance, checking the JSON-RPC server logs on the device.  
Its value is set to current UTC time.

### jsonrpc_version

<small>type: string</small>

The `jsonrpc_version` value is a string that indicates the JSON-RPC version used by the module. The value is always `2.0` and is not user configurable.

### result

<small>type: list of any</small>

The `result` value is a list of returned data. The list order matches the order of the `paths` parameter. Such that the first element of the `result` list contains the data retrieved from the first element of the `paths` list.

The type of the data returned depends on the `path` parameter. For instance, if the `path` parameter points to a leaf, the value of the leaf is returned. If the `path` parameter points to a container, the container is returned as a dictionary. See examples to see the data returned for different `path` parameters.

## Error handling

The `get` module sets the [`failed`](#failed) return value to `true` when errors occur during the module execution. The error message is returned in the `msg` field of the return value.

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

### Single path

The most simple example of using the `get` module is to retrieve a single path which may point to any YANG node of a chosen datastore.

Consider the example below, where we retrieve the system information from the state datastore providing a path to a YANG container using the `/system/information` path.

=== "Task"

    ```yaml
    - name: Get /system/information container
      nokia.srlinux.get:
        paths:
          - path: /system/information
            datastore: state
      register: get_response
    ```
=== "Response"

    ```json
    ok: [clab-ansible-srl] => {
        "get_response": {
            "changed": false,
            "failed": false,
            "failed_when_result": false,
            "jsonrpc_req_id": 6062,
            "jsonrpc_version": "2.0",
            "result": [
                {
                    "current-datetime": "2023-04-26T21:23:10.364Z",
                    "description": "SRLinux-v23.3.1-343-gab924f2e64 7250 IXR-6 Copyright (c) 2000-2020 Nokia. Kernel 5.15.0-1036-azure #43-Ubuntu SMP Wed Mar 29 16:11:05 UTC 2023",
                    "last-booted": "2023-04-26T21:22:29.603Z",
                    "version": "v23.3.1-343-gab924f2e64"
                }
            ]
        }
    }
    ```

As explained in the [`result`](#result) parameter documentation, the result value contains a list of objects one per requested path. Since we requested the module to retrieve the value of a single path `/system/information` which points to a YANG container element, the result list contains only a single element with the object containing the state parameters.

Accessing the values of a response object is done using dotted notation. For example, to access the description value of the returned object registered in the `get_response` variable we can use:

```
get_response.result[0].description
```

### Multiple paths

The `get` module allows users to retrieve data from multiple paths, datastores and even YANG models, thus providing great flexibility and efficiency.

In the following example we retrieve infromation from three paths and different datastores:

=== "Task"

    ```yaml
      name: Get multiple paths
      nokia.srlinux.get:
        paths:
          - path: /system/information
            datastore: state
          - path: /system/information/version
            datastore: state
          - path: /system/json-rpc-server
            datastore: running
    ```
=== "Response"

    ```yaml
    ok: [clab-ansible-srl] => {
        "response": {
            "changed": false,
            "failed": false,
            "jsonrpc_req_id": 23437,
            "jsonrpc_version": "2.0",
            "result": [
                {
                    "current-datetime": "2023-04-27T10:56:36.670Z",
                    "description": "SRLinux-v23.3.1-343-gab924f2e64 7250 IXR-6 Copyright (c) 2000-2020 Nokia. Kernel 5.15.0-67-generic #74-Ubuntu SMP Wed Feb 22 14:14:39 UTC 2023",
                    "last-booted": "2023-04-26T20:14:35.789Z",
                    "version": "v23.3.1-343-gab924f2e64"
                },
                "v23.3.1-343-gab924f2e64",
                {
                    "admin-state": "enable",
                    "network-instance": [
                        {
                            "http": {
                                "admin-state": "enable"
                            },
                            "https": {
                                "admin-state": "enable",
                                "tls-profile": "clab-profile"
                            },
                            "name": "mgmt"
                        }
                    ]
                }
            ]
        }
    }
    ```

When requesting multiple paths, the returned `result` list contains as many elements as many paths have been requested. In this example the three elements form the `result` list.

Note, how the second requested path `/system/information/version` pointed to a YANG leaf, and therefore the 2nd element of the `result` list is just a string of the requested leaf.

The 1st and 3rd elements are json objects, because the paths pointed to a container element. As in the "single path" example, users can access the returned data using the dotted notation.

??? "Multiple paths with mixing YANG models"
    It is possible to retrieve data from multiple paths using different YANG models. This is achieved by setting the [`yang_models`](#yang_models) parameter on a per-path level.

    ```yaml
    - name: Get multiple paths
      nokia.srlinux.get:
        paths:
          - path: /system/state/hostname
            datastore: state
            yang_models: oc
          - path: /system/information/description
            datastore: state
            yang_models: srl
          - path: /system/json-rpc-server
            datastore: running
            yang_models: srl
    ```

### Openconfig

To retrieve data using Openconfig model leverage the [`yang_models`](#yang_models) parameter which is set on a per-path level:

=== "Task"
This task requests `/system/state/hostname` using Openconfig model and `/system/information` using SR Linux native datastore. Note, that OC and SR Linux models are mixed in the paths, the SR Linux `srl` model needs to be set explicitly.

```yaml
- name: Get /system/information container
  nokia.srlinux.get:
    paths:
      - path: /system/state/hostname
        yang_models: oc
        datastore: state
      - path: /system/information
        yang_models: srl
        datastore: state
  register: response
```

=== "Response"
Because Openconfig paths pointed to a YANG leaf, the first element in the `result` list is a string value of the hostname. The 2nd element is an object retrieved using SR Linux YANG model.

```json
ok: [clab-ansible-srl] => {
    "response": {
        "changed": false,
        "failed": false,
        "failed_when_result": false,
        "jsonrpc_req_id": 32499,
        "jsonrpc_version": "2.0",
        "result": [
            "srl",
            {
                "current-datetime": "2023-04-26T21:23:46.376Z",
                "description": "SRLinux-v23.3.1-343-gab924f2e64 7250 IXR-6 Copyright (c) 2000-2020 Nokia. Kernel 5.15.0-1036-azure #43-Ubuntu SMP Wed Mar 29 16:11:05 UTC 2023",
                "last-booted": "2023-04-26T21:22:29.603Z",
                "version": "v23.3.1-343-gab924f2e64"
            }
        ]
    }
}
```

## Source code

Get module is implemented in the [`get.py`][get-gh-url] file.

[get-gh-url]: https://github.com/nokia/srlinux-ansible-collection/blob/main/plugins/modules/get.py
