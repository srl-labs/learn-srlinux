---
date: 2023-05-02
tags:
  - sr linux
  - ansible
authors:
  - rdodin
---

# Official Ansible collection for SR Linux

Ever since we released a tutorial that showed how to use Ansible's URI module with SR Linux, we couldn't shake off the feeling that we would need to do more with Ansible. And we did.  
We are happy to announce that we have released an official Ansible collection for SR Linux - [`nokia.srlinux`][collection-doc-link] - that has four modules inside and leverages [JSON-RPC interface](../2022/json-rpc-basics.md).

In this blog post, we would like to share some details about our design decisions and why we think this collection is a great addition to the Ansible ecosystem.

<!-- more -->

## Deficiencies of the URI module

The URI module is a great tool for making REST API calls. It is very flexible, generic and can be used to make any type of HTTP/REST API calls. However, its generic nature can also be seen as a drawback.

### Verbosity

The verbosity that comes with URI module can't be ignored. It requires a lot of wiring to be done before the request is ready. Consider the following example where we want to update `/system/information` container:

```yaml
- name: Configuration
  hosts: all
  connection: local
  gather_facts: no
  tasks:
    - name: Various configuration tasks
      ansible.builtin.uri:
        url: http://{{inventory_hostname}}/jsonrpc
        url_username: admin
        url_password: NokiaSrl1!
        method: POST
        body:
          jsonrpc: "2.0"
          id: 1
          method: set
          params:
            commands:
              - action: update
                path: /system/information
                value:
                  location: the Netherlands
                  contact: Roman Dodin
        body_format: json
```

Parameters like `url`, `url_username`, `url_password`, `method` and `body` are all required and must be specified for every request. This makes the code very verbose and hard to read. Using variables won't help much either, as the parameters still need to be explicitly set.

With a custom module we can hide all the boilerplate code and make the request contain only the intent:

```yaml
- name: Configuration
  hosts: all
  gather_facts: false
  tasks:
    - name: Various configuration tasks
      nokia.srlinux.config:
        update:
          - path: /system/information
            value:
              location: the Netherlands
              contact: Roman Dodin
```

### Error handling

The URI module doesn't provide any error handling besides the HTTP error codes returned by the server. In case the errors are returned by the application and not a server, it becomes the user's problem to check the response body for error messages. This is not a problem if you are making a single request, but if you are making multiple requests, you will need to check the response code for each request. This can be done using `register` and `failed_when` parameters, but it is not convenient.

In a custom module you are in full control of the error handling and can make decisions based on the response body. For example, you can check if the response contains an error message and fail the task if it does with a clean error message.

### Idempotency

A common problem with the URI module is idempotency. The module doesn't provide any means to check if the configuration is already present on the device without writing additional requests as part of the playbook. This means that the user needs to implement the idempotency logic themselves.

In a custom module, you can implement the idempotency logic and make the module idempotent by default. This means that the user doesn't need to worry about idempotency and can focus on the intent.

### Check and Diff

Besides idempotency, the with URI module it is impossible to implement the `check` and `diff` functionality which is table stakes for network automation. Another requirement that warrants a custom module development.

## Design decisions

So, all these fallacies of the URI module led us to the decision to develop a custom module for SR Linux. We wanted to make the module as easy to use as possible, while keeping the generic nature.

### Network resource vs generic module

The first decision we had to make was whether to follow a network resource module principles or stick with a generic module approach.

The [network resource module](https://docs.ansible.com/ansible/latest/network/user_guide/network_resource_modules.html) approach says that developers should create a module for each configuration section. For example, a separate module to configure VLANs, another one to configure BGP, a third one to configure EVPN, and so on.

The generic module philosophy is different. Instead of creating a horde of modules, you create a single module per distinct operation and use the module parameters to specify the intent. For example, a module to configure the network device may be called `config` and a module to retrieve information from it - `get`.  
The `config` and `get` modules will have a parameter that would specify the configuration/state section to work with instead of creating separate modules for each section.

We decided to go with the generic modules as it is significantly easier to maintain and the benefits of the network resource modules are not strong enough when you have a fully modelled NOS at your disposal.

For example, here is how you configure an interface with a generic [`nokia.srlinux.config`][config-module] module and a netres example that does the same:

=== "nokia.srlinux.get"

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
    ```
=== "network resource example"
    And this is how it'd looked like if we opted in for the network resource modules:

    ```yaml
    - name: Add interface
      hosts: clab
      gather_facts: false
      tasks:
        - name: Add interface
          nokia.srlinux.interface:
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
    ```

As you can see, the generic module has only one additional parameter - `path` which specifies the configuration section to work with. The rest of the parameters are the same. The development effort though is significantly lower as you don't need to create a separate module for each configuration section. This also means that any changes to the underlying YANG model that SR Linux might undergo, won't break the modules.

### Check and Diff

Network people crave for the `check` and `diff` functionality. It is almost a must-have for any network automation tool.

Our [`nokia.srlinux.config`][config-module] fully supports both [check](../../../ansible/collection/config.md#check-mode) and [diff](../../../ansible/collection/config.md#diff-mode) modes. To implement these functions we had to enhance our JSON-RPC interface to support the `diff` method.

The newly added `diff` method allows us to send a configuration set to the SR Linux and get back the difference between the current configuration and the configuration set. If the returned diff is empty, it means that the configuration is already present on the device, and therefore the task won't lead to any changes.

The difference is returned in the form of a diff string which can be used by Ansible to display the changes to support the diff mode.

### Idempotency

The same `diff` method of JSON-RPC enabled us to add a first class support for idempotency. When you use the `config` module it will automatically check if the configuration is already present on the device and will skip the task if it is.

This means that your change set won't even be attempted to be applied to the device if it is already present.

### Bulk operations

Because we use a custom JSON-RPC API exposed by SR Linux, we can implement bulk operations. This means that you can [send multiple configuration changes](../../../ansible/collection/config.md#multiple-configuration-operations) in a single request and the device will apply them all in a single transaction.

This is a solid improvement over the untransactional RESTCONF API where you have to send a separate request for each configuration change and implement sophisticated rollback procedures if errors happen midway.

Ivan will [keep us honest](https://twitter.com/ntdvps/status/1649343908361433090) on this one.

### Embedded validation

As part of our idempotency workflow when we check if a diff yields any changes, we also check if the configuration set is valid using the `validate` method of JSON-RPC. This means that you can be sure that the configuration you are trying to apply passes SR Linux validation.

This makes it unnecessary to call for the `validate` method separately and makes the module more user-friendly.

### CLI operations

Besides model-driven based operations exposed by [`config`][config-module] and [`get`][get-module] modules we also provide the [`cli`][cli-module] module.

The `cli` module allows you to execute any CLI command on the device and get the output back. This is useful for operational tasks like getting the output of the `show` commands or calling CLI plugins.

## Examples

To help you get started, we have created a set of examples that you can use as a reference when developing your own playbooks. These examples are outlined in the "Examples" section for each [module][collection-doc-link].

Besides that, we have adapted the original [Ansible tutorial](../../../tutorials/programmability/ansible/using-nokia-srlinux-collection.md) to feature the SR Linux collection.

## Conclusion

We hope that you will find the SR Linux collection useful and will be able to use it to automate your SR Linux devices. The generic nature of the modules should enable 100% coverage of the SR Linux YANG model for both configuration and state retrieval operations.

The `cli` module should help you with operational tasks and the `check` and `diff` modes should make your automation more robust and error-proof.

We are eager to hear from you if you find any functionality missing or if you have any suggestions on how to improve the collection. Please leave comments below or [open an issue](https://github.com/nokia/srlinux-ansible-collection/issues) on GitHub.

[collection-doc-link]: ../../../ansible/collection/index.md
[config-module]: ../../../ansible/collection/config.md
[get-module]: ../../../ansible/collection/get.md
[cli-module]: ../../../ansible/collection/cli.md
