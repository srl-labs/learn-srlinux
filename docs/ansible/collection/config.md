---
comments: true
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

## Config operations

The module provides an `update`, `replace`` and `delete` operations against SR Linux devices. Moreover, a combination of these operations can be handled by the module enabling rich configuration transactions.

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
    ok: [clab-ansible-srl] => {
        "get_response": {
            "changed": false,
            "failed": false,
            "failed_when_result": false,
            "jsonrpc_req_id": "2023-04-29 12:19:13:180761",
            "jsonrpc_version": "2.0",
            "result": [
                "Some location",
                [
                    "request",
                    "common"
                ],
                {}
            ]
        }
    }
    ```

Config module uses JSON-RPC interface of SR Linux, and in particular, its [`Set` method](../../tutorials/programmability/json-rpc/basics.md#set). Upon receiving the Set method, SR Linux opens a private named candidate configuration and applies the operations in the  following order:

1. updates
2. replaces
3. deletes

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

### datastore

<small>type: string</small>

The `datastore` parameter is a string that represents the name of the datastore that needs to be used for the configuration operations. The default value is `candidate`.

The only other `datastore` value available is `tools`, which allows users to invoke operational commands via the `tools` datastore. See [the following example](#operational-commands-via-tools-datastore) for more details.

### save-when

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

## Examples

### operational commands via `tools` datastore

SR Linux models operational commands as configuration elements in the `tools` datastore. This allows users to invoke operational commands via the `nokia.srlinux.config` module. For example, the following task clears the interface statistics:

```yaml
- name: Clear interface statistics
  nokia.srlinux.config:
    datastore: tools
    update:
      - path: /interface[name=mgmt0]/statistics/clear
    datastore: tools
```

[ansible-check-diff]: https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_checkmode.html

[^1]: Effectively, configuration is sent twice to the device. First to check if a diff is non-empty and if not, second time to actually apply the configuration set. Note, that in this case the diff happens on SR Linux box, and not calculated locally.
[^2]: The diff returned is the same as the one returned by the `diff` CLI command.
