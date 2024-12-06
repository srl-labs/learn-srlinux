---
comments: true
title: Config Module
---

# `config` Module

Config module provides a flexible and performant way to configure SR Linux devices using a model-driven HTTP-based JSON-RPC interface.

The generic architecture of a module allows configuration changes across the entire SR Linux configuration datastore.

=== "Example playbook"

    ```yaml
    - name: Set system information
      hosts: clab
      gather_facts: false
      tasks:
        - name: Set system information with values
          nokia.srlinux.config:
            update:
              - path: /system/information
                value:
                  location: Some location
                  contact: Some contact
          register: set_response
    ```

=== "Response"

    ```json
    ok: [clab-ansible-srl] => {
        "set_response": {
            "changed": true,
            "diff": {
                "jsonrpc_req_id": "2023-04-28 18:50:19:695364",
                "jsonrpc_version": "2.0",
                "result": [
                    "      system {\n          information {\n+             contact \"Some contact\"\n+             location \"Some location\"\n          }\n      }\n"
                ]
            },
            "failed": false,
            "jsonrpc_req_id": 3038,
            "saved": false
        }
    }
    ```

`path` and `value` parameters take values based on [SR Linux YANG models](../../yang/index.md), enabling fully model-driven configuration operations.

## Config operations

The module provides an `update`, `replace` and `delete` operations against SR Linux devices. Moreover, a combination of these operations can be handled by the module enabling rich configuration transactions.

### Idempotency

Idempotency principles are fully honored by the module. When users execute a module with configuration operations, the module runs the `diff` operation to check if the intended configuration set leads to any changes.

The `diff` operation takes `update`, `replace` and `delete` values and applies them to the newly opened candidate configuration. First, the `validate` function ensures that the provided changeset passes internal validation and then `diff` function is called to identify if these changes produce any diff output.

The output of the `diff` operation is then returned to the `config` module. An empty return indicates that the configuration set does not lead to any changes; thus, the `config` module reports that task as unchanged.

A non-empty diff output would mean that the configuration set leads to changes, and therefore the configuration set will be sent[^1] to the device to be applied.

### Transactions and ordering

The generic nature of the module and its ability to contain multiple configuration operations allows its user to create configuration transactions which include a number of `update`, `delete` and `replace` operations.

In the example below, the module is stuffed with multiple updates, replaces and deletes. It is important to understand how SR Linux processes such requests.

=== "`config` with multiple operations"

    ```yaml
    - name: Set multiple paths
      hosts: clab
      gather_facts: false
      tasks:
        - name: Set with multiple operations
          nokia.srlinux.config:
            update:
              - path: /system/information/location #(1)!
                value: Some location
            replace:
              - path: /system/gnmi-server/trace-options #(1)!
                value:
                  - request
                  - common
            delete:
              - path: /system/json-rpc-server/network-instance[name=mgmt]/https
          register: set_response
    ```

    1. When a path points to a leaf, the value is provided as string or integer.
    2. When a path points to a list (aka leaf-list in YANG), the value is provided as a list of scalar values.
=== "Response"

    ```json
    {
        "set_response": {
            "changed": true,
            "diff": {
                "jsonrpc_req_id": "2023-05-01 08:37:10:798782",
                "jsonrpc_version": "2.0",
                "result": [
                    "      system {\n          gnmi-server {\n-             trace-options [\n-                 response\n-             ]\n          }\n          json-rpc-server {\n              network-instance mgmt {\n-                 https {\n-                     admin-state enable\n-                     tls-profile clab-profile\n-                 }\n              }\n          }\n          information {\n+             location \"Some location\"\n          }\n      }\n"
                ]
            },
            "failed": false,
            "jsonrpc_req_id": "2023-05-01 08:37:11:009871",
            "saved": false
        }
    }
    ```

Config module uses JSON-RPC interface of SR Linux, and in particular, its [`Set` method](../../tutorials/programmability/json-rpc/basics.md#set). Upon receiving the Set method, SR Linux opens a private named candidate configuration and applies the operations in the  following order:

1. deletes
2. replaces
3. updates

Note, that the operations that are part of the module's task are not committed independently, they are applied strictly together in the "all or nothing" fashion. When we say that the operations are applied in that order, we mean that changes get applied to the candidate configuration in that order. No commit happens just yet.

If no errors occur during changes of the candidate configuration, an implicit commit is invoked to apply all the changes in a single transaction. If the commit fails, the configuration is automatically reverted, and the error is returned to the caller.  
Such functionality provides users with the means to reliably apply multiple changes in a single transaction, without worrying that the devices might be left in a partially configured state.

### Check mode

The module fully supports [Ansible's check mode][ansible-check-diff]. When the module is executed in the check mode, the `diff` operation indicates whether the task leads to a change in the device's state.

!!!note
    No changes are applied to the device when running with `check` mode. It is a safe way to understand if the intended configuration set leads to any changes.

As per Ansible's documentation, the `check` mode can be enabled on a per-playbook or per-task basis. The following example shows how to enable the `check` mode for the task and the result of the playbook execution.

=== "Playbook"
    The below playbook tests if the intended update operation leads to any changes in the device's state. The device doesn't have the location and contact set, so the diff output indicates that the task leads to a change.

    ```yaml
    - name: Set leaves with check mode
      hosts: clab
      gather_facts: false
      tasks:
        - name: Test check mode
          nokia.srlinux.config:
            update:
              - path: /system/information
                value:
                  location: Some location
                  contact: Some contact
          check_mode: true
          register: set_response
    ```

=== "Response"
    The response object contains the `diff` output that indicates that the task leads to a change and therefore `changed` is set to `true`. Remember that the `check` mode doesn't apply any changes to the device.

    ```json
    {
        "set_response": {
            "changed": true,
            "diff": {
                "prepared": "      system {\n          information {\n+             contact \"Some contact\"\n+             location \"Some location\"\n          }\n      }\n"
            },
            "failed": false,
            "failed_when_result": false,
            "saved": false
        }
    }
    ```

### Diff mode

The module supports the `diff` mode that allows users to display the diff output. This mode can be used both with the `check` mode and without it. When used with `check` mode the diff output is displayed but no changes are applied to the device. When used without `check` mode, the diff output is displayed and the changes are applied to the device.

The diff is calculated by the SR Linux device and thus is an accurate representation of the changes that will be applied to the device[^2].

=== "Playbook"
    In this playbook the `diff` and `check` modes are both enabled. The task should output the diff of the operation and indicate that the task leads to a change.

    ```yaml
    - name: Test check mode with diff
      nokia.srlinux.config:
        update:
          - path: /system/information
            value:
              location: Some location
              contact: Some contact
      check_mode: true
      diff: true
      register: set_response
    ```
=== "Output"
    As a result, the output contains the diff of the operation and indicates that the task leads to a change.

    ```diff
    TASK [Test check mode with diff] ***********************************************
          system {
              information {
    +             contact "Some contact"
    +             location "Some location"
              }
          }
    changed: [clab-ansible-srl]
    ```
=== "Response"
     The response object contains the `diff` output that indicates that the task leads to a change and therefore `changed` is set to `true`. Remember that the `check` mode doesn't allow the intended changes to be applied.

    ```json
    "set_response": {
      "changed": true,
      "diff": {
          "prepared": "      system {\n          information {\n+             contact \"Some contact\"\n+             location \"Some location\"\n          }\n      }\n"
      },
      "failed": false,
      "failed_when_result": false,
      "saved": false
    }
    ```

## Name alias

The `nokia.srlinux.config` module has a name alias to align with the historical naming scheme for config modules: `nokia.srlinux.srl_config`. Users can use any of the names.

## Parameters

### update

The `update` parameter is a list of update operations that are applied to the candidate configuration in the order they are provided. Each update operation is a dictionary with the `path` and `value` keys.

#### path

<small>**required** · type: string</small>

The `path` parameter is a string that represents a path to the configuration element that needs to be updated. The path is provided in the XPATH-like notation and is relative to the root of the candidate datastore.

SR Linux users are encouraged to use [YANG Browser](../../yang/browser.md) to explore the YANG model and identify the paths to the data they want to retrieve.

#### value

<small>type: any</small>

The `value` parameter is a value that needs to be user for the provided operations. The value type is determined by the type of the configuration element that is being targeted by the path.

| Path YANG type | Value type          |
| -------------- | ------------------- |
| leaf           | string/integer/bool |
| leaf-list      | list                |
| list           | dictionary          |

Check the examples below to see how the value is provided for each of the types.

### replace

The `replace` parameter is a list of replace operations that are applied to the candidate configuration in the order they are provided. Each replace operation is a dictionary with the `path` and `value` keys.

Path and value parameters are the same as for the `update` parameter with the only difference that the `value` parameter is required for the `replace` operation.

### delete

The `delete` parameter is a list of delete operations that are applied to the candidate configuration in the order they are provided. Each delete operation is a dictionary with the `path` key and no `value`.

#### path

<small>**required** · type: string</small>

The `path` parameter is a string that represents a path to the configuration element that needs to be deleted. The path is provided in the XPATH-like notation and is relative to the root of the candidate datastore. No value is provided, since delete operation does not require any.

### confirm_timeout

<small>added in: v0.3.0 · min. SR Linux version: v23.3.2</small>

Prior to SR Linux version 23.3.2 users could have set the global commit confirm timeout by setting the value of the `commit-confirmed-timeout` leaf under `json-rpc-server` stanza:

```srl
--{ + running }--[  ]--
A:srl# enter candidate  

--{ + candidate shared default }--[  ]--
A:srl# /system json-rpc-server commit-confirmed-timeout 10
```

This setting would have applied to all configuration changes made through JSON-RPC interface and would require a commit confirmation to be issued before the timer expires.

Starting from SR Linux version 23.3.2 and nokia/srlinux collection v0.3.0, users can set the commit confirm timeout on a per-task basis by setting the `confirm_timeout` parameter. The `confirm_timeout` parameter is an integer that represents the number of seconds the commit confirm operation should wait for the user to confirm the commit.

Check out the [following example](#commit-confirmation) for a workflow demonstrating the use of the `confirm_timeout` parameter.

### datastore

<small>type: string</small>

The `datastore` parameter is a string that represents the name of the datastore that needs to be used for the configuration operations. The default value is `candidate`.

The only other `datastore` value available is `tools`, which allows users to invoke operational commands via the `tools` datastore. See [the following example](#operational-commands-via-tools-datastore) for more details.

### save_when

<small>choice: `always`, **`never`**, `changed`</small>

The `save_when` parameter allows users to choose when the candidate configuration should be saved to the startup configuration (aka persisted) upon successful commit. The default value is `never`.

By setting the `save_when` to `always`, users can ensure that the candidate configuration is always saved to the startup configuration upon successful commit. And by setting the `save_when` to `changed`, users can ensure that the candidate configuration is saved to the startup configuration only when the candidate configuration is changed upon successful commit.

The `save_when` has no effect when the `check` mode is enabled.

### yang_models

<small>choice: **`srl`**, `oc`</small>

The `yang_models` parameter allows users to choose which YANG models should be used for the configuration operations. The default value is `srl`. See [Get](get.md#yang_models) module docs for more details.

## Return values

The module returns the results in a structured format which contains both standard Ansible fields and SR Linux specific fields.

```json
{
    "set_response": {
        "changed": true,
        "diff": {
            "jsonrpc_req_id": "2023-04-29 13:02:42:777835",
            "jsonrpc_version": "2.0",
            "result": [
                "      system {\n          gnmi-server {\n-             trace-options [\n-                 response\n-             ]\n          }\n          json-rpc-server {\n              network-instance mgmt {\n-                 https {\n-                     admin-state enable\n-                     tls-profile clab-profile\n-                 }\n              }\n          }\n          information {\n+             location \"Some location\"\n          }\n      }\n"
            ]
        },
        "failed": false,
        "jsonrpc_req_id": "2023-04-29 13:02:42:985777",
        "saved": false
    }
}
```

### changed

<small>type: boolean</small>

The `changed` value indicates if the module has made any changes to the state of a device.

When the module is executed without the `check` mode, the `changed` value is `true` if the module has made any changes to the state of a device. Otherwise, the `changed` value is `false`.

When the module is executed with the `check` mode, the `changed` parameter can also become `true` or `false`, but in any case, the changes will not be committed to the device.

### failed

<small>type: boolean</small>

The `failed` value indicates if any errors occurred during the execution of the module. The `failed` value is `false` when the module completes successfully and `true` otherwise. See the [Error handling](#error-handling) section for more details.

### jsonrpc_req_id

<small>type: string</small>

See [Get](get.md#jsonrpc_req_id) module.

### jsonrpc_version

<small>type: string</small>

See [Get](get.md#jsonrpc_version) module.

### diff

<small>type: dictionary</small>

The `diff` value contains the response of a diff operation that was executed against the device.

As explained in the [idempotency](#idempotency) section, the diff operation is always called to identify if the change is required. The result of that diff RPC is saved in the `diff` response parameter and contains the full response body object.

### saved

<small>type: boolean</small>

The `saved` value indicates if the candidate configuration was saved to the startup configuration upon successful commit. The `saved` value is `true` when the candidate configuration was saved to the startup configuration and `false` otherwise.

## Error handling

The `config` module sets the [`failed`](#failed) return value to `true` when errors occur during the module execution. The error message is returned in the `msg` field of the return value.

Consider the following output when a wrong path is value is used in the `update` operation:

=== "playbook"

    ```yaml
    - name: Set wrong value
      hosts: clab
      gather_facts: false
      tasks:
        - name: Set system information with wrong value
          nokia.srlinux.config:
            update:
              - path: /system/information
                value:
                  wrong: Some location
          register: set_response
    ```

=== "response"
    The response will have `failed=true` and the `msg` will contain the error message as reported by SR Linux:

    ```bash
    fatal: [clab-ansible-srl]: FAILED! => {"changed": false, "id": "2023-05-01 08:42:59:116073", "method": "diff", "msg": "Schema '/system/information' has no local leaf with the name 'wrong'. Options are [contact, location, protobuf-metadata]: Parse error on line 1: {\"wrong\": \"Some location\"}\nInput:\n'{\"wrong\": \"Some location\"}'"}
    ```

## Examples

### adding an interface

Let's see step by step how to use the `config` module to add the `ethernet-1/1` interface to a device.

First, we need to identify the path to the interface configuration and the values that can be set on that path. One way to do that is to leverage YANG Browser's [Tree viewer](../../yang/browser.md#tree-browser) and visually inspect the YANG model. The following screenshot shows the YANG Browser's [Tree viewer for SR Linux 23.3.1](https://yang.srlinux.dev/releases/v23.3.1/tree) release with `interfaces` model opened:

![if1](https://gitlab.com/rdodin/pics/-/wikis/uploads/631943f74a2e9ba1e0a1035adf8f3168/image.png){: .img-shadow}

As we can see, the interfaces are nested under the `/interface[name=*]` list. This answers the first question: the path to the interface configuration is `/interface[name=ethernet-1/1]`.

Using the same UI we can see which values can be set on the interface. The following screenshot shows the `interface` model with `subinterface` list expanded:

???tip "screenshot"
    ![if2](https://gitlab.com/rdodin/pics/-/wikis/uploads/c2deb1b94f2686479de4d2eab412c0bb/image.png){: .img-shadow}

Now we know that the `description` leaf can be set on the interface, and we configure IPv4/6 addresses with subinterfaces. With that info, we can construct the following playbook:

```yaml
- name: Add interface
  hosts: clab
  gather_facts: false
  tasks:
    - name: Add interface
      nokia.srlinux.config:
        update:
          - path: /interface[name=ethernet-1/1]
            value:
              admin-state: enable
              description: "interface description set with Ansible"
              subinterface:
                - index: 0
                  admin-state: enable
                  description: "subinterface description set with Ansible"
                  ipv4:
                    admin-state: enable
                    address:
                      - ip-prefix: 192.168.0.100/24

      register: set_response

    - debug:
        var: set_response
```

When constructing the payload we follow a simple rule:

* a list in the YANG model is represented as a list in the payload
* a container in the YANG model is represented as a dictionary in the payload

For example, the `subinterface` list is represented as a list in the payload, and the `ipv4` container is represented as a dictionary in the payload.

### multiple configuration operations

The following example shows how to use the `config` module to perform multiple configuration operations in a single task. Note, that you can have multiple `update`, `replace`, and `delete` operations in a single task:

=== "Playbook"

    ```yaml
    - name: Set multiple paths
      hosts: clab
      gather_facts: false
      tasks:
        - name: Set with multiple operations
          nokia.srlinux.config:
            update:
              - path: /system/information/location
                value: Some location
            replace:
              - path: /system/gnmi-server/trace-options
                value:
                  - request
                  - common
            delete:
              - path: /system/json-rpc-server/network-instance[name=mgmt]/https
          register: set_response
    ```

=== "Response"

    ```json
    {
        "set_response": {
            "changed": true,
            "diff": {
                "jsonrpc_req_id": "2023-05-01 08:46:38:419093",
                "jsonrpc_version": "2.0",
                "result": [
                    "      system {\n          gnmi-server {\n-             trace-options [\n-                 response\n-             ]\n          }\n          json-rpc-server {\n              network-instance mgmt {\n-                 https {\n-                     admin-state enable\n-                     tls-profile clab-profile\n-                 }\n              }\n          }\n          information {\n+             location \"Some location\"\n          }\n      }\n"
                ]
            },
            "failed": false,
            "jsonrpc_req_id": "2023-05-01 08:46:38:617927",
            "saved": false
        }
    }
    ```

### operational commands via `tools` datastore

SR Linux models operational commands as configuration elements in the `tools` datastore. This allows users to invoke operational commands via the `nokia.srlinux.config` module. For example, the following task clears the interface statistics:

```yaml
- name: Clear interface statistics
  nokia.srlinux.config:
    datastore: tools
    update:
      - path: /interface[name=mgmt0]/statistics/clear
```

### openconfig

The `config` module supports OpenConfig models. As with `get` module, the `yang_models` parameter must be set to `oc`. Note, that for the `config` module, the `yang_models` parameter is set on a per-task basis.

```yaml
- name: Set OC leaf
  hosts: clab
  gather_facts: false
  tasks:
    - name: Set openconfig leaf
      nokia.srlinux.config:
        update:
          - path: /system/config
            value:
              motd-banner: "hey ansible"
        yang_models: oc
      register: set_response

    - debug:
        var: set_response
```

### Commit confirmation

The `config` module supports per-task [commit confirmation](#confirm_timeout). The following example shows how to set the commit confirmation timeout and confirm the changes in the allowed time:

```yaml
- name: Confirm timeout
  hosts: clab
  gather_facts: false
  tasks:
    - name: Add interface description with confirm timeout
      nokia.srlinux.config:
        update:
          - path: /interface[name=mgmt0]/description
            value: "this description would be gone without commit confirm"
        # after 4 seconds commit is reverted if not confirmed
        confirm_timeout: 4

    - name: Confirm the commit
      nokia.srlinux.config:
        datastore: tools
        update:
          - path: /system/configuration/confirmed-accept

    - ansible.builtin.pause:
        prompt: "Waiting 4 seconds to ensure commit is successfully confirmed"
        seconds: 4

    - name: Ensure leaf has been set
      nokia.srlinux.get:
        paths:
          - path: /interface[name=mgmt0]/description
            datastore: state
      failed_when: get_response.result[0] != "this description would be gone without commit confirm"
```

## Source code

Config module is implemented in the [`config.py`][config-gh-url] file.

[ansible-check-diff]: https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_checkmode.html
[config-gh-url]: https://github.com/nokia/srlinux-ansible-collection/blob/main/plugins/modules/config.py

[^1]: Effectively, the configuration is sent twice to the device. First, to check if a diff is non-empty, and if not, second time to apply the configuration set. In this case, the diff happens on SR Linux box and is not calculated locally.
[^2]: The diff returned is the same as the one returned by the `diff` CLI command.
