# Ansible Collection For SR Linux

Ansible collection for SR Linux is identified with `nokia.srlinux` fully qualified collection name and contains the plugins and modules to interface with SR Linux devices.

| Summary               |                                              |
| --------------------- | -------------------------------------------- |
| **Collection name**   | `nokia.srlinux`                              |
| **Galaxy URL**        | [nokia/srlinux][coll-url]                    |
| **Github repository** | [nokia/srlinux-ansible-collection][repo-url] |
| **Python version**    | >=3.6                                        |

Modules contained within this collection fully conform to the idempotency principles of Ansible, as well as provide first-class support for diff and check functionality[^1].

## Modules

Nokia SR Linux collection provides the following modules that work via HttpApi connection plugin:

* [`nokia.srlinux.jsonrpc_get`][jsonrpc-get] - allows to retrieve configuration and state.
* [`nokia.srlinux.jsonrpc_set`][jsonrpc-set] - allows to change configuration.
* [`nokia.srlinux.jsonrpc_cli`][jsonrpc-cli] - allows to execute CLI commands.
* [`nokia.srlinux.jsonrpc_validate`][jsonrpc-validate] - allows to validate provided configuration.

## Installation

The recommended way to [install][galaxy-install] galaxy collections is via the `ansible-galaxy` CLI command that ships with the ansible installation.

=== "Latest version"
    ```bash
    ansible-galaxy collection install nokia.srlinux
    ```
=== "Specific version"
    ```bash
    ansible-galaxy collection install nokia.srlinux:0.1.0 #(1)!
    ```

    1. Available version are listed in [collection's home page][coll-url].

Collection is installed at the collections path. Default location is `~/.ansible/collections/ansible_collections/nokia/slinux`.

## SR Linux configuration

The factory configuration that SR Linux ships with doesn't have JSON-RPC interface enabled. In order to use the modules of this collection, users should enable and [configure the JSON-RPC server](../../tutorials/programmability/json-rpc/basics.md#configuring-json-rpc).

## `ansible_connection`

Ansible supports [a number of connection modes][ansible-conn-modes] to establish connectivity with devices over multiple connection protocols. SSH, HTTP and Local connections are likely the most popular one.

The modules in `nokia.srlinux` collection interface with SR Linux devices over its [JSON-RPC interface][jsonrpc-tutorial], and thus leverage [HttpApi connection plugin][ansible-httpapi-conn-plugin] of Ansible's `netcommon` collection.

To instruct Ansible to use `ansible.netcommon.httpapi` connection plugin, users should set the `ansible_connection` variable to `ansible.netcommon.httpapi`.

There are many ways to set this variable, though most common one is to set in the inventory file:

```ini
[clab]
clab-ansible-srl  ansible_connection=ansible.netcommon.httpapi ;(1)!
```

1. Other variables are omitted

## `ansible_network_os`

With `ansible_network_os` variables users select which Network OS the target host runs. For Nokia SR Linux this variable should be set to `nokia.srlinux.srlinux` value.

Most commonly, this variable is set in the inventory file:

```ini
[clab]
clab-ansible-srl  ansible_network_os=nokia.srlinux.srlinux ;(1)!
```

1. Other variables are omitted

## Authentication

Basic HTTP authentication is used by the modules of this collection. Credentials are provided by the common `ansible_user` and `ansible_password` variables.

## TLS

SR Linux JSON-RPC server which the modules of this connection connect to can operate in two modes:

1. Insecure HTTP mode  
    No TLS certificates required, connection is not encrypted
2. Secure HTTPS mode  
    Requires TLS certificate to be generated and configured.

To instruct Ansible to connect to SR Linux device over https protocol users should set the `ansible_httpapi_use_ssl` variable to `true`. Again, this can be done on different levels, but most often it is part of the inventory file.

When set `ansible_httpapi_use_ssl` is set to `true`, Ansible will try to establish the connection over https using `443` port.

### Certificate validation

By default, when operating over https protocol, Ansible will try to validate the remote host's certificate. To disable certificate verification, set `ansible_httpapi_validate_certs` to `false`.

[coll-url]: https://galaxy.ansible.com/nokia/srlinux/
[repo-url]: https://github.com/nokia/srlinux-ansible-collection
[jsonrpc-get]: jsonrpc_get.md
[jsonrpc-set]: jsonrpc_set.md
[jsonrpc-cli]: jsonrpc_cli.md
[jsonrpc-validate]: jsonrpc_validate.md
[galaxy-install]: TODO
[ansible-conn-modes]: TODO
[jsonrpc-tutorial]: ../../tutorials/programmability/json-rpc/basics.md
[ansible-httpapi-conn-plugin]: TODO

[^1]: See [`jsonrpc_set`][jsonrpc-set] module for details.
