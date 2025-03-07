---
tags:
  - ansible
---

# Ansible Collection For SR Linux

Ansible collection for SR Linux is identified with `nokia.srlinux` fully qualified collection name and contains the plugins and modules to interface with SR Linux devices.

| Summary                         |                                              |
| ------------------------------- | -------------------------------------------- |
| **Collection name**             | `nokia.srlinux`                              |
| **Galaxy URL**                  | [nokia/srlinux][coll-url]                    |
| **Ansible Automation Platform** | [nokia/srlinux][aap-coll-url]                |
| **Github repository**           | [nokia/srlinux-ansible-collection][repo-url] |
| **SR Linux version**            | >=23.3.1[^1]                                 |
| **Python version**              | >=3.10                                       |

Modules contained within this collection fully conform to the idempotence principles of Ansible, as well as provide first-class support for diff and check functionality[^2].

!!!tip "Tutorial"
    Besides examples provided for each module of this collection, checkout [Ansible with SR Linux tutorial](../../tutorials/programmability/ansible/using-nokia-srlinux-collection.md) to see how to use this collection in practice.

## Modules

Nokia SR Linux collection provides the following modules that work via HttpApi connection plugin and therefore rely on SR Linux's JSON-RPC server:

* [`nokia.srlinux.get`][get] - retrieve configuration and state.
* [`nokia.srlinux.config`][config] - configure SR Linux devices via model driven interface.
* [`nokia.srlinux.cli`][cli] - execute CLI commands.
* [`nokia.srlinux.validate`][validate] - validate provided configuration.

Architecturally the modules provide a generic way to retrieve data from and configure SR Linux devices in a model-driven way[^3]. Because SR Linux is a fully-modelled NOS, users should leverage the [YANG Browser](../../yang/browser.md) to navigate the datastores and understand the data model.

Quick examples of how to use the modules. For more information on each module options and return values, please refer to the module's documentation page.

=== "get"
    Retrieve configuration and state from SR Linux devices.

    ```yaml
    - name: Get system information
    hosts: clab
    gather_facts: false
    tasks:
      - name: Get /system/information container
        nokia.srlinux.get:
          paths:
            - path: /system/information
                datastore: state
    ```

=== "config"
    Configure SR Linux devices.

    ```yaml
    - name: Set leaves
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
    ```
=== "cli"
    Execute CLI commands on SR Linux devices.

    ```yaml
    - name: Execute "show version" CLI command
      hosts: clab
      gather_facts: false
      tasks:
        - name: Execute "show version" CLI command
          nokia.srlinux.cli:
            commands:
              - show version
    ```
=== "validate"
    Validate intended configuration.

    ```yaml
    - name: Validate
      hosts: clab
      gather_facts: false
      tasks:
        - name: Validate a valid change set
          nokia.srlinux.validate:
            update:
              - path: /system/information
                value:
                  location: Some location
                  contact: Some contact
    ```

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

### Container image

To simplify the usage of the collection, we provide a container image that contains the collection and all its dependencies. To accommodate for the different Ansible versions, we provide multiple images based on the underlying `ansible-core` and the python version. The full list of available images and their tags can be found in the [Github container registry](https://github.com/orgs/nokia/packages?repo_name=srlinux-ansible-collection).

The easiest way to use the image is to create an alias for the `ansible-playbook` command.

```bash
alias ansible-playbook="docker run --rm -it \
  -v $(pwd):/ansible \
  -v ~/.ssh:/root/.ssh \
  -v /etc/hosts:/etc/hosts \
  ghcr.io/nokia/srlinux-ansible-collection/2.15.5/py3.11:v0.3.0 ansible-playbook $@"
```

???tip "How to test this container?"
    Let's demonstrate how to use this container image given the alias above.

    First, we deploy a simple SR Linux node using containerlab:

    ```bash
    curl -sL srlinux.dev/clab-srl | containerlab deploy -c -t -
    ```

    Once the lab is deployed, let's create a simple `test.yml` playbook that retrieves the SR Linux version:

    ```bash
    cat <<EOF > test.yml
    - name: Example playbook
      hosts: all
      tasks:
        - name: Get version
          nokia.srlinux.get:
            paths:
              - path: /system/information/version
                datastore: state
          register: output

        - ansible.builtin.debug:
            msg: 'SR Linux version {{output.result[0]}}'
    EOF
    ```

    Finally, let's run the playbook specifying the SR Linux container name `srl` as a single inventory host, the connection plugin to use, and the credentials:

    ```bash
    ansible-playbook -i srl, \
      -c ansible.netcommon.httpapi -e "ansible_network_os=nokia.srlinux.srlinux" \
      -e "ansible_user=admin" -e "ansible_password=NokiaSrl1!" \
      test.yml
    ```

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

By default, when operating over https protocol, Ansible will try to validate the remote host's certificate. If the node's certificate is signed with CA that is not in the trust chain of the ansible controller, then the certificate validation will fail. There are two ways to make TLS-based connectivity work:

1. Add `ansible_httpapi_ca_path` variable pointing to the CA certificate that signed the node's certificate.
2. Disable certificate verification with setting `ansible_httpapi_validate_certs` to `false`.

### TLS 1.3 support and cipher suites

In the recent Python versions (>=3.10) default [security settings for TLS](https://bugs.python.org/issue43998) have been hardened. More specifically the cipher suites have been restricted to the ones that are considered secure.

SR Linux started to ramp up TLS 1.3 support starting with release 23.10.1; users of older SR Linux releases would need to explicitly set the `ansible_httpapi_ciphers` variable to the cipher suite that is supported, for example `ECDHE-RSA-AES256-SHA`.

## Example `hosts` file

With the above configuration options in mind, the following `hosts` file demonstrates their usage to connect to the SR Linux device:

```ini
[clab]
clab-ansible-srl ansible_connection=ansible.netcommon.httpapi ansible_user=admin ansible_password=NokiaSrl1! ansible_network_os=nokia.srlinux.srlinux ansible_httpapi_ciphers=ECDHE-RSA-AES256-SHA
```

## Lab

To demonstrate the usage of the modules in this collection, we will use a very simple containerlab topology to deploy a single SR Linux node:

```yaml
name: ansible

topology:
  nodes:
    srl:
      kind: nokia_srlinux
      image: ghcr.io/nokia/srlinux:23.10.1
```

Save the file as `ansible.clab.yml` and deploy the lab with `containerlab deploy -t ansible.clab.yml`.

Create the `hosts` file as shown in the previous section and you're ready to tryout the modules of this collection.

[coll-url]: https://galaxy.ansible.com/nokia/srlinux/
[repo-url]: https://github.com/nokia/srlinux-ansible-collection
[get]: get.md
[config]: config.md
[cli]: cli.md
[validate]: validate.md
[galaxy-install]: https://galaxy.ansible.com/docs/using/installing.html
[ansible-conn-modes]: https://docs.ansible.com/ansible/latest/plugins/connection.html
[jsonrpc-tutorial]: ../../tutorials/programmability/json-rpc/basics.md
[ansible-httpapi-conn-plugin]: https://docs.ansible.com/ansible/latest/plugins/httpapi.html
[aap-coll-url]: https://console.redhat.com/ansible/automation-hub/repo/published/nokia/srlinux/

[^1]: `nokia.srlinux` collection requires SR Linux 23.3.1 or later.
[^2]: See [`config`][config] module for details.
[^3]: The modules purposefully don't follow network resource modules pattern, as we wanted to provide a generic way to access the whole configuration and state datastores of the device.
