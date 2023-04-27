---
comments: true
---

# `config` Module

Config module provides flexible and performant way to configure SR Linux devices using model-driven HTTP-based JSON-RPC interface.

The generic architecture of a module allows configuration changes across all SR Linux configuration datastore without limitation.

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
                "jsonrpc_req_id": 51729,
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

The module allows users to perform the `update`, `replace` and `delete` operations against SR Linux devices. Moreover, a combination of these operations may be provided to the module enabling rich configuration transactions.

### Idempotency

Idempotency principles are fully honored by the module. When users execute a module with configuration operations the module first calls the `diff` operation to check if the intended configuration set leads to changes on the SR Linux device.

The `diff` operation takes all `update`, `replace` and `delete` values and apply them to the newly opened candidate configuration. Then it calls `validate` function to ensure that the change set passes internal validations and then calls `diff` function of SR Linux to identify if these changes produce any diff output.

The output of that `diff` operation is then returned to the `config` module. An empty return indicates that the configuration set does not lead to any changes and thus the `config` module reports that task is unchanged.

A non empty diff output would mean that the configuration set leads to changes and therefore will be sent[^1] to the device to be applied.  

### Transactionality and ordering

The generic nature of the module and its ability to contain multiple configuration operations allows its user to create configuration transactions which include a number of `update`, `delete` and `replace` operations.

In the example below, the module is stuffed with multiple updates, replaces and deletes. It is important to understand how SR Linux processes such requests.

Config module uses JSON-RPC interface of SR Linux, and in particular, the [`Set` method](../../tutorials/programmability/json-rpc/basics.md#set). Upon receiving the Set method, SR Linux opens a private named candidate configuration and applies the operations in the order of:

1. deletes
2. replaces
3. updates

Note, that the operations are not committed independently, they are applied strictly together in the all-or-nothing fashion. This means, that when we say that the operations are applied in that order, we mean that changes get applied to the candidate configuration in that order. No commit happens yet.

If no errors occurred during changes of the candidate configuration an implicit commit is invoked to apply all the changes in a single transaction. If commit fails, then configuration is automatically reverted and the error is returned to the caller.  
Such functionality provides users with the means to reliably apply multiple changes in a single transaction, without worrying that the devices might be left in a partially configured state.

## Name alias

The `nokia.srlinux.config` module has a name alias to align with the historical naming scheme for config modules: `nokia.srlinux.srl_config`. Users can use any of the names.

## Parameters

[^1]: Effectively, configuration is sent twice to the device. First to check if a diff is non-empty and if not, second time to actually apply the configuration set. Note, that in this case the diff happens on SR Linux box, and not calculated locally.
