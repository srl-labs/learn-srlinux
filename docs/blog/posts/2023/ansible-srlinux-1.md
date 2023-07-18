---
date: 2023-07-06
tags:
  - srlinux
  - ansible
  - netdevops
  - netops
  - iac
authors:
  - wdesmedt
---

# Managing an SR Linux fabric with Ansible

## Introduction

Ansible is today the _lingua franca_ for network engineers to automate the configuration of network devices. Due to its simplicity and low barrier to entry, it is a popular choice for network automation that provides for maintainable and reusable automation code within network teams.

Our intention with this post is to provide a practical example how you can use Ansible to manage configuration of an SR Linux fabric by leveraging the official [Ansible collection for SR Linux][collection-doc-link]. It is not an 'off-the-shelf' solution, but rather a demonstration of the capabilities of the Ansible collection and hopefully a source of inspiration for your own automation projects.

<!-- more -->

The approach we discuss here only partially covers the SR Linux configuration or data model. Only resources required to establish and maintain a functional fabric are covered. The solution could be extended to cover other aspects of the configuration or data model by employing similar techniques but this is left as an exercise for the reader.

The intent or desired state of the fabric in this solution is abstracting the device-specific implementation. The abstraction level is always a trade-off between usability of the automation and feature coverage of the managed infrastructure: the higher the abstraction, the more user-friendly it becomes, but at the expense of feature coverage. The right abstraction level depends on your specific use cases and requirements.

## Setting up your environment

### Prerequisites

- To fully appreciate this project, you should have a basic understanding of SR Linux and its network constructs to understand what this project does. Things like _mac-vrfs_, _network instances_, _irb_'s, _sub-interfaces_, etc. should be familiar to you. If not, we recommend you first read the [SR Linux documentation](https://documentation.nokia.com/srlinux/).

- Make sure you are on a machine with Ansible installed. The Ansible version should be 2.9 or higher. We recommend you run Ansible from a Python virtual environment, for example:

  ```bash
    python3 -m venv .venv
    source .venv/bin/activate
    pip install ansible
  ```

- Ensure you have the latest version of [Containerlab](https://containerlab.srlinux.dev/) installed and are meeting the [requirements](https://containerlab.srlinux.dev/install/) to run it.

- We recommend you install the [fcli](https://github.com/srl-labs/nornir-srl) tool to interact with the SR Linux nodes from the command line. It generates fabric-wide reports to verify things like configured services, interfaces, routes, etc. It is not required to run the project, but it's useful to verify the state of the fabric after running the playbook and is used throughout this post to illustrate the effect of the Ansible playbook.

### Installing the Ansible collection

Install the SR Linux Ansible collection from [Ansible Galaxy](https://galaxy.ansible.com/) with the following command:

```bash
ansible-galaxy collection install nokia.srlinux
```

### Clone the project repository

The entire project is contained in the [ansible-srl-demo][ansible-srl-demo] repository. Following command will clone the repository to the current directory on your machine (in folder ansible-srl-demo):

  ```bash
  git clone https://github.com/wdesmedt/ansible-srl-demo.git
  cd ansible-srl-demo
  ```

The following sections assume you are in the `ansible-srl-demo` directory.

### Setting up your SR Linux lab environment

You need an SR Linux test topology to run the Ansible playbook and roles against. We will use [Containerlab](https://containerlab.srlinux.dev/) to create a lab environment with 6 SR Linux nodes: 4 leaf-nodes and 2 spine-nodes:

```bash
sudo containerlab deploy -t 4l2s.clab.yml -c
```

This will create a lab environment with 6 SR Linux nodes and a set of linux containers to act as hosts:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/wdesmedt/ansible-srl-demo/main/img/ansible-srl-topo.drawio.svg"}'></div>
  <figcaption> Fabric topology</figcaption>
</figure>

Also, the `/etc/hosts` file on the host machine will be updated with the IP addresses of the SR Linux nodes. This will allow us to connect to the nodes with Ansible, that has a matching inventory file inside the `inv` directory.

Verify that all containers are up and running:

```bash
sudo containerlab inspect -t 4l2s.clab.yml
```

## Project structure

### The Ansible Inventory

In this project, we use the native file-based Ansible inventory. It lists the hosts that are part of the fabric and groups them in a way that reflects the fabric topology. The inventory file is located in the `inv` directory and contains next to the inventory file `ansible-inventory.yml` also `host_vars` and `group_vars` directories that contain host- and group-specific variables.

```bash
inv
├── ansible-inventory.yml # => the inventory file
├── group_vars
│   └── srl.yml  # => group-specific variables for the srl group
└── host_vars
    ├── clab-4l2s-l1.yml # => host-specific variables for the clab-4l2s-l1 host
    ├── clab-4l2s-l2.yml
    ├── clab-4l2s-l3.yml
    ├── clab-4l2s-l4.yml
    ├── clab-4l2s-s1.yaml
    └── clab-4l2s-s2.yml
```

Ansible is instructed to use this inventory file by setting `inventory = inv` in the `ansible.cfg` configuration file.

The `ansible-inventory.yml` defines 3 groups:

- 'srl' for all SR Linux nodes
- 'spine' for the spine nodes
- 'leaf' for the leaf nodes.
  
  The `host_vars` directory contains a file for each host that defines host-specific variables. The `group_vars` directory contains a single file for the `srl` group to define Ansible-specific variables that are required for the JSON-RPC connection-plugin as well as some system-level configuration data.

### The Ansible Playbook

The Ansible playbook `cf_fabric.yml` is the main entry point for the project. It contains a single play that applies a sequence of roles to all nodes in the `leaf` and `spine` groups:

```yaml title="cf_fabric.yml"
- name: Configure fabric
  gather_facts: no
  hosts: 
   - leaf
   - spine
  vars:
    purge: yes # purge resources from device not in intent
    purgeable:
      - interface
      - subinterface
      - network-instance
  roles:
## INIT ##
  - { role: common/init, tags: [always] }
## INFRA ##
  - { role: infra/system, tags: [infra, system]}
  - { role: infra/interface, tags: [infra, interface] }
  - { role: infra/policy, tags: [infra, policy] }
  - { role: infra/networkinstance, tags: [infra,]}
## SERVICES ##
  - { role: services/l2vpn, tags: [services, l2vpn ]}
  - { role: services/l3vpn, tags: [services, l3vpn ]}
## CONFIG ##
  - { role: common/configure, tags: [always]}
```

The playbook is structured in 3 sections:

- the `hosts` variable at play-level defines the hosts that are part of the fabric. In this case, all hosts in the `leaf` and `spine` groups. Group definition and membership is defined in the inventory file.
- the `vars` variable at play-level defines variables that are used by the roles. In this case, the `purge` variable is set to `yes` to remove resources from the nodes that are not defined in the intent. The `purgeable` variable defines the resource types that are purged from the nodes when missing from the intent. In this case, these resources are: interfaces, sub-interfaces and network instances.
- the `roles` variable at play-level defines the roles that are applied to the hosts in the `leaf` and `spine` groups. The roles are applied in the order they are defined in the playbook. The roles are grouped in 4 sections: `INIT`, `INFRA`, `SERVICES` and `CONFIG`.

  - **INIT**: This section initializes some extra global variables or _Ansible facts_ that are used by other roles. These facts include:
    - the current 'running config' of the device
    - the software version of SRLinux
    - the LLDP neighborship states
  - **INFRA**: This section configures the infrastructural network resources needed for services to operate. It configures the inter-switch interfaces, base routing, policies and the default instance
  - **SERVICES**: This section configures the services on the nodes. It configures the L2VPN and L3VPN services, based on a high-level abstraction defined in each role's variables
  - **CONFIG**: This section applies configuration to the nodes. It is always executed, even if no changes are made to the configuration. This is to ensure that the configuration on the node is always in sync with the intent.

The `common/init` role checks if the `ENV` environment variable is set. If it's missing, the playbook will fail. The value of the `ENV` variable is used to select the correct role variables that represent the intent. This is to support multiple environments, like 'test' and 'prod' environments, for which intents may be different. In this project, only the `test` environment is defined.

Roles also have _tags_ associated with them to run a subset of the roles in the playbook. For example, to only run the `infra` roles, you can use the following command:

```bash
ENV=test ansible-playbook cf_fabric.yml --tags infra
```

!!!note
    To leverage the _pruning_ capability of the playbook, all roles must be executed to achieve a full intent. If tags are specified for a partial run, no purging will be performed by the playbook.

### Role structure

This project provides a set of Ansible roles to manage the resources on SR Linux nodes. The roles are organized in a directory structure that reflects the configuration section of the nodes it manages.

The roles are grouped in the following directories:

```bash
roles
├── common
│   ├── configure
│   └── init
├── infra
│   ├── interface
│   ├── networkinstance
│   ├── policy
│   └── system
├── services
│   ├── l2vpn
│   └── l3vpn
└── utils
    ├── interface
    ├── load_intent
    ├── network-instance
    └── policy
```

The `infra` and `services` roles operate on the configuration of the underlay of the fabric and the services that run on it respectively. Each of the roles in these directories contributes to an global intent for the SR Linux node.

#### INFRA roles

Following INFRA roles are defined:

- `interface`: manages intent for interfaces in the underlay configuration
- `networkinstance`: manages intent for the 'default' network-instance
- `policy`: manages intent for routing policies in the underlay configuration
- `system`: manages system-wide configuration of the node

The generic structure of the `infra` roles is as follows:

```bash
├── tasks
│   └── main.yml
├── templates
└── vars
    ├── prod
    └── test
        └── xxx.yml  # the intent
```

The `tasks/main.yml` file defines the tasks that are executed by the role. The `templates` folder contains a folder per platform - in this case, only SR Linux is supported and is optional. Let's look at the `infra/interface` role as an example:

```yaml title="roles/infra/interface/tasks/main.yml"
- set_fact:
    my_intent: {}

- name: "Load vars for ENV:{{ env }}"
  include_vars:
    dir: "{{ lookup('env', 'ENV') }}" # Load vars from files in 'dir'

- name: "{{ ansible_role_name}}: Load Intent for /interfaces" 
  ansible.builtin.include_role:
    name: utils/load_intent

- set_fact:
    intent: "{{ intent | default({}) | combine(my_intent, recursive=true) }}"
```

The `infra/interface` role loads the host-specific intent by calling another role, the `utils/load_intent` role. This role takes the group- and host-level intents from the `vars/${ENV}` folder - in our case `ENV=test` -  and merges them into a single role-specific intent (`my_intent`). The `my_intent` variable is then merged with the global per-device   `intent` variable that may have been already partially populated by other roles.

Other infra roles follow the same approach.

#### SERVICES roles

Two service roles are defined:

- **l2vpn**: manages intent for _fabric-wide_ L2VPN services. These are a set of mac-vrf instances on a subset of the nodes in the fabric with associated interfaces and policies
- **l3vpn**: manages intent for _fabric-wide_ L3VPN services. These are a set of ip-vrf instances on a subset of the nodes in the fabric and are associated with mac-vrf instances

For these roles, we decided to take the abstraction to a new level. Below is an example how a L2VPN is defined:

  ```yaml title="roles/services/l2vpn/vars/test/l2vpn.yml"
  l2vpn:                    # root of l2vpn intent, mapping of mac-vrf instances, with key=mac-vrf name 
    macvrf-200:             # name of the mac-vrf instance
      id: 200               # id of the mac-vrf instance: used for vlan-id and route-targets
      type: mac-vrf
      description: MACVRF1
      interface_list:       # a mapping with key=node-name and value=list of interfaces
        clab-4l2s-l1:       # node on which the mac-vrf instance is configured
        - ethernet-1/1.200  # interface that will be associated with the mac-vrf instance
        clab-4l2s-l2:
        - ethernet-1/1.200
      export_rt: 100:200  # export route-target for EVPN address-family
      import_rt: 100:200  # import route-target for EVPN address-family
      vlan: 200           # vlan-id for the mac-vrf instance. 
                          # all sub-interfaces on all participating nodes will be configured with this vlan-id
  ```

The _l2vpn_ role will transform this _fabric-wide_ intent into a node-specific intent per resource (network-instance, subinterface, tunnel-interface) and will merge this with the global node intent.

The _l3vpn_ role follows a similar approach but depends on the _l2vpn_ role to define the intent for the mac-vrf instances. If not, the playbook will fail. The _l3vpn_ role knows if an ip-vrf instance applies to the node based of the mac-vrf definitions associated with the ip-vrf. The mac-vrf definition in the L2VPN intent includes the node association.

An example of a L3VPN intent is shown below:

```yaml title="roles/services/l3vpn/vars/test/l3vpn.yml"
l3vpn:                      # root of l3vpn intent, mapping of ip-vrf instances, with key=ip-vrf name
  ipvrf-2001:               # name of the ip-vrf instance
    id: 2001                # id of the ip-vrf instance: used for route-targets
    type: ip-vrf
    description: IPVRF1
    snet_list:              # a list of (macvrf, gw) pairs. The macvrf must be present in the l2vpn intent  
      - macvrf: macvrf-300  # the macvrf instance to associate with the ip-vrf instance
        gw: 10.1.1.254/24   # the gateway address for the subnet
      - macvrf: macvrf-301
        gw: 10.1.2.254/24
    export_rt: 100:2001     # export route-target for EVPN address-family (route-type: 5)
    import_rt: 100:2001     # import route-target for EVPN address-family (route-type: 5)
```

#### COMMON and UTILS roles

Once the nodal intent has been constructed by the INFRA and SERVICES roles, the playbook calls the `common/configure` role as the last task. This role will take the nodal intent and construct the final configuration for the node. It calls roles in the `utils` folder to construct the configuration for the various resources (interfaces, network-instances, policies, etc) and thus generates the variables `update` and `replace` that are passed as arguments to the `nokia.srlinux.config` module.

It also generates a `delete` variable containing a list of configuration paths to delete when the play variable `purge=true` and when no tags are specified with the `ansible-playbook` command that would result in a partial nodal intent. It uses the node for configuration state (running configuration) that was retrieved by the `common/init` role and compares this against the nodal intent to generate the `delete` variable.

Following diagram gives an overview how the low-level device intent is constructed from the various roles:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/wdesmedt/ansible-srl-demo/main/img/ansible-srl-intent.drawio.svg"}'></div>
  <figcaption>Transforming high-level intent to device configuration</figcaption>
</figure>

## Configuring the fabric

### Startup configuration

The initial configuration of the fabric nodes after setting up your environment, only contains the required statements to allow management connections to the nodes (SSH, gNMI, JSON-RPC). No further configuration is applied to the nodes.

If you have installed the [fcli](https://github.com/srl-labs/nornir-srl) tool, you can verify the initial state of the fabric with the following command that lists all the network-instances active on the fabric nodes. Alternatively, you can log into the nodes and verify the configuration manually. Only a single network instance `mgmt` should be present on each node.

=== "LLDP neighbors"
    ```bash
    ❯ fcli -i fabric=yes lldp-nbrs -f interface="eth*"
                                  LLDP Neighbors
                            Fields:{'interface': 'eth*'}
                            Inventory:{'fabric': 'yes'}
    +---------------------------------------------------------------------------+
    | Node         | interface     | Nbr-System | Nbr-port      | Nbr-port-desc |
    |--------------+---------------+------------+---------------+---------------|
    | clab-4l2s-l1 | ethernet-1/10 | tor12      | ethernet-1/49 |               |
    |              | ethernet-1/48 | s2         | ethernet-1/1  |               |
    |              | ethernet-1/49 | s1         | ethernet-1/1  |               |
    |--------------+---------------+------------+---------------+---------------|
    | clab-4l2s-l2 | ethernet-1/10 | tor12      | ethernet-1/48 |               |
    |              | ethernet-1/48 | s2         | ethernet-1/2  |               |
    |              | ethernet-1/49 | s1         | ethernet-1/2  |               |
    |--------------+---------------+------------+---------------+---------------|
    | clab-4l2s-l3 | ethernet-1/10 | tor34      | ethernet-1/49 |               |
    |              | ethernet-1/48 | s2         | ethernet-1/3  |               |
    |              | ethernet-1/49 | s1         | ethernet-1/3  |               |
    |--------------+---------------+------------+---------------+---------------|
    | clab-4l2s-l4 | ethernet-1/10 | tor34      | ethernet-1/48 |               |
    |              | ethernet-1/48 | s2         | ethernet-1/4  |               |
    |              | ethernet-1/49 | s1         | ethernet-1/4  |               |
    |--------------+---------------+------------+---------------+---------------|
    | clab-4l2s-s1 | ethernet-1/1  | l1         | ethernet-1/49 |               |
    |              | ethernet-1/2  | l2         | ethernet-1/49 |               |
    |              | ethernet-1/3  | l3         | ethernet-1/49 |               |
    |              | ethernet-1/4  | l4         | ethernet-1/49 |               |
    |--------------+---------------+------------+---------------+---------------|
    | clab-4l2s-s2 | ethernet-1/1  | l1         | ethernet-1/48 |               |
    |              | ethernet-1/2  | l2         | ethernet-1/48 |               |
    |              | ethernet-1/3  | l3         | ethernet-1/48 |               |
    |              | ethernet-1/4  | l4         | ethernet-1/48 |               |
    +---------------------------------------------------------------------------+
    ```
=== "Network instances and interfaces"
    ```bash
    ❯ fcli -i fabric=yes nwi-itfs

                                            Network-Instance Interfaces
                                        Inventory:{'fabric': 'yes'}
    +----------------------------------------------------------------------------------------------------------+
    | Node         | ni   | oper | type   | router-id | Subitf  | if-oper | ipv4                 | mtu  | vlan |
    |--------------+------+------+--------+-----------+---------+---------+----------------------+------+------|
    | clab-4l2s-l1 | mgmt | up   | ip-vrf |           | mgmt0.0 | up      | ['172.20.21.11/24']  | 1500 |      |
    |--------------+------+------+--------+-----------+---------+---------+----------------------+------+------|
    | clab-4l2s-l2 | mgmt | up   | ip-vrf |           | mgmt0.0 | up      | ['172.20.21.12/24']  | 1500 |      |
    |--------------+------+------+--------+-----------+---------+---------+----------------------+------+------|
    | clab-4l2s-l3 | mgmt | up   | ip-vrf |           | mgmt0.0 | up      | ['172.20.21.13/24']  | 1500 |      |
    |--------------+------+------+--------+-----------+---------+---------+----------------------+------+------|
    | clab-4l2s-l4 | mgmt | up   | ip-vrf |           | mgmt0.0 | up      | ['172.20.21.14/24']  | 1500 |      |
    |--------------+------+------+--------+-----------+---------+---------+----------------------+------+------|
    | clab-4l2s-s1 | mgmt | up   | ip-vrf |           | mgmt0.0 | up      | ['172.20.21.101/24'] | 1500 |      |
    |--------------+------+------+--------+-----------+---------+---------+----------------------+------+------|
    | clab-4l2s-s2 | mgmt | up   | ip-vrf |           | mgmt0.0 | up      | ['172.20.21.102/24'] | 1500 |      |
    +----------------------------------------------------------------------------------------------------------+
    ```

### Configuring the underlay

To configure the underlay of the fabric - the configuration of interfaces and routing to make overlay services possible - we apply the `infra` roles to all nodes in the `leaf` and `spine` groups. The `infra` roles are identified by the `infra` tag in the `cf_fabric.yml` playbook. The following command configures the underlay with the intent defined in the `roles/infra/*/vars/` files:

```bash
ENV=test ansible-playbook --tags infra cf_fabric.yml
```

This will use the underlay intent stored in `roles/infra/*/vars/` that comes with to project to configure the underlay of the fabric. The `ENV` variable is used to select the correct variable folder from the infra roles.

If you have the `fcli` tool installed, you can verify the configuration of the underlay with the following command that lists all the network-instances active on the fabric nodes. Alternatively, you can log into the nodes and verify the configuration manually. The `infra` roles should have configured the interfaces and routing on the nodes.

=== "Network-instances and interfaces"
    ```bash
    $ fcli -i fabric=yes nwi-itfs
                                                          Network-Instance Interfaces
                                                      Inventory:{'fabric': 'yes'}
    +------------------------------------------------------------------------------------------------------------------------------+
    | Node         | ni      | oper | type    | router-id       | Subitf          | if-oper | ipv4                   | mtu  | vlan |
    |--------------+---------+------+---------+-----------------+-----------------+---------+------------------------+------+------|
    | clab-4l2s-l1 | default | up   | default | 192.168.255.1   | ethernet-1/48.0 | up      | ['192.168.1.1/31']     | 1500 |      |
    |              |         |      |         |                 | ethernet-1/49.0 | up      | ['192.168.0.1/31']     | 1500 |      |
    |              |         |      |         |                 | system0.0       | up      | ['192.168.255.1/32']   |      |      |
    |              | mgmt    | up   | ip-vrf  |                 | mgmt0.0         | up      | ['172.20.21.11/24']    | 1500 |      |
    |--------------+---------+------+---------+-----------------+-----------------+---------+------------------------+------+------|
    | clab-4l2s-l2 | default | up   | default | 192.168.255.2   | ethernet-1/48.0 | up      | ['192.168.1.3/31']     | 1500 |      |
    |              |         |      |         |                 | ethernet-1/49.0 | up      | ['192.168.0.3/31']     | 1500 |      |
    |              |         |      |         |                 | system0.0       | up      | ['192.168.255.2/32']   |      |      |
    |              | mgmt    | up   | ip-vrf  |                 | mgmt0.0         | up      | ['172.20.21.12/24']    | 1500 |      |
    |--------------+---------+------+---------+-----------------+-----------------+---------+------------------------+------+------|
    | clab-4l2s-l3 | default | up   | default | 192.168.255.3   | ethernet-1/48.0 | up      | ['192.168.1.5/31']     | 1500 |      |
    |              |         |      |         |                 | ethernet-1/49.0 | up      | ['192.168.0.5/31']     | 1500 |      |
    |              |         |      |         |                 | system0.0       | up      | ['192.168.255.3/32']   |      |      |
    |              | mgmt    | up   | ip-vrf  |                 | mgmt0.0         | up      | ['172.20.21.13/24']    | 1500 |      |
    |--------------+---------+------+---------+-----------------+-----------------+---------+------------------------+------+------|
    | clab-4l2s-l4 | default | up   | default | 192.168.255.4   | ethernet-1/48.0 | up      | ['192.168.1.7/31']     | 1500 |      |
    |              |         |      |         |                 | ethernet-1/49.0 | up      | ['192.168.0.7/31']     | 1500 |      |
    |              |         |      |         |                 | system0.0       | up      | ['192.168.255.4/32']   |      |      |
    |              | mgmt    | up   | ip-vrf  |                 | mgmt0.0         | up      | ['172.20.21.14/24']    | 1500 |      |
    |--------------+---------+------+---------+-----------------+-----------------+---------+------------------------+------+------|
    | clab-4l2s-s1 | default | up   | default | 192.168.255.101 | ethernet-1/1.0  | up      | ['192.168.0.0/31']     | 1500 |      |
    |              |         |      |         |                 | ethernet-1/2.0  | up      | ['192.168.0.2/31']     | 1500 |      |
    |              |         |      |         |                 | ethernet-1/3.0  | up      | ['192.168.0.4/31']     | 1500 |      |
    |              |         |      |         |                 | ethernet-1/4.0  | up      | ['192.168.0.6/31']     | 1500 |      |
    |              |         |      |         |                 | system0.0       | up      | ['192.168.255.101/32'] |      |      |
    |              | mgmt    | up   | ip-vrf  |                 | mgmt0.0         | up      | ['172.20.21.101/24']   | 1500 |      |
    |--------------+---------+------+---------+-----------------+-----------------+---------+------------------------+------+------|
    | clab-4l2s-s2 | default | up   | default | 192.168.255.102 | ethernet-1/1.0  | up      | ['192.168.1.0/31']     | 1500 |      |
    |              |         |      |         |                 | ethernet-1/2.0  | up      | ['192.168.1.2/31']     | 1500 |      |
    |              |         |      |         |                 | ethernet-1/3.0  | up      | ['192.168.1.4/31']     | 1500 |      |
    |              |         |      |         |                 | ethernet-1/4.0  | up      | ['192.168.1.6/31']     | 1500 |      |
    |              |         |      |         |                 | system0.0       | up      | ['192.168.255.102/32'] |      |      |
    |              | mgmt    | up   | ip-vrf  |                 | mgmt0.0         | up      | ['172.20.21.102/24']   | 1500 |      |
    +------------------------------------------------------------------------------------------------------------------------------+
    ```
=== "BGP peers"
    ```bash
    ❯ fcli -i fabric=yes bgp-peers -b ascii
                                                                     BGP Peers
                                                            Inventory:{'fabric': 'yes'}
    +-------------------------------------------------------------------------------------------------------------------------------------------------+
    |              |          |                 | AFI/SAFI  | AFI/SAFI  |                |         |               |          |         |             |
    |              |          |                 | EVPN      | IPv4-UC   |                |         |               |          |         |             |
    | Node         | NetwInst | 1_peer          | Rx/Act/Tx | Rx/Act/Tx | export_policy  | group   | import_policy | local_as | peer_as | state       |
    |--------------+----------+-----------------+-----------+-----------+----------------+---------+---------------+----------+---------+-------------|
    | clab-4l2s-l1 | default  | 192.168.0.0     | disabled  | 8/7/2     | lo-and-servers | spines  | pass-all      | 65001    | 65100   | established |
    |              |          | 192.168.1.0     | disabled  | 8/4/5     | lo-and-servers | spines  | pass-all      | 65001    | 65100   | established |
    |              |          | 192.168.255.101 | 0/0/0     | disabled  | pass-evpn      | overlay | pass-evpn     | 100      | 100     | established |
    |              |          | 192.168.255.102 | 0/0/0     | disabled  | pass-evpn      | overlay | pass-evpn     | 100      | 100     | established |
    |--------------+----------+-----------------+-----------+-----------+----------------+---------+---------------+----------+---------+-------------|
    | clab-4l2s-l2 | default  | 192.168.0.2     | disabled  | 8/7/2     | lo-and-servers | spines  | pass-all      | 65002    | 65100   | established |
    |              |          | 192.168.1.2     | disabled  | 8/4/5     | lo-and-servers | spines  | pass-all      | 65002    | 65100   | established |
    |              |          | 192.168.255.101 | 0/0/0     | disabled  | pass-evpn      | overlay | pass-evpn     | 100      | 100     | established |
    |              |          | 192.168.255.102 | 0/0/0     | disabled  | pass-evpn      | overlay | pass-evpn     | 100      | 100     | established |
    |--------------+----------+-----------------+-----------+-----------+----------------+---------+---------------+----------+---------+-------------|
    | clab-4l2s-l3 | default  | 192.168.0.4     | disabled  | 8/7/2     | lo-and-servers | spines  | pass-all      | 65003    | 65100   | established |
    |              |          | 192.168.1.4     | disabled  | 8/4/5     | lo-and-servers | spines  | pass-all      | 65003    | 65100   | established |
    |              |          | 192.168.255.101 | 0/0/0     | disabled  | pass-evpn      | overlay | pass-evpn     | 100      | 100     | established |
    |              |          | 192.168.255.102 | 0/0/0     | disabled  | pass-evpn      | overlay | pass-evpn     | 100      | 100     | established |
    |--------------+----------+-----------------+-----------+-----------+----------------+---------+---------------+----------+---------+-------------|
    | clab-4l2s-l4 | default  | 192.168.0.6     | disabled  | 8/7/2     | lo-and-servers | spines  | pass-all      | 65004    | 65100   | established |
    |              |          | 192.168.1.6     | disabled  | 8/4/5     | lo-and-servers | spines  | pass-all      | 65004    | 65100   | established |
    |              |          | 192.168.255.101 | 0/0/0     | disabled  | pass-evpn      | overlay | pass-evpn     | 100      | 100     | established |
    |              |          | 192.168.255.102 | 0/0/0     | disabled  | pass-evpn      | overlay | pass-evpn     | 100      | 100     | established |
    |--------------+----------+-----------------+-----------+-----------+----------------+---------+---------------+----------+---------+-------------|
    | clab-4l2s-s1 | default  | 192.168.0.1     | disabled  | 2/1/8     | pass-all       | leafs   | pass-all      | 65100    | 65001   | established |
    |              |          | 192.168.0.3     | disabled  | 2/1/8     | pass-all       | leafs   | pass-all      | 65100    | 65002   | established |
    |              |          | 192.168.0.5     | disabled  | 2/1/8     | pass-all       | leafs   | pass-all      | 65100    | 65003   | established |
    |              |          | 192.168.0.7     | disabled  | 2/1/8     | pass-all       | leafs   | pass-all      | 65100    | 65004   | established |
    |              |          | 192.168.255.1   | 0/0/0     | disabled  | pass-evpn      | overlay | pass-evpn     | 100      | 100     | established |
    |              |          | 192.168.255.2   | 0/0/0     | disabled  | pass-evpn      | overlay | pass-evpn     | 100      | 100     | established |
    |              |          | 192.168.255.3   | 0/0/0     | disabled  | pass-evpn      | overlay | pass-evpn     | 100      | 100     | established |
    |              |          | 192.168.255.4   | 0/0/0     | disabled  | pass-evpn      | overlay | pass-evpn     | 100      | 100     | established |
    |--------------+----------+-----------------+-----------+-----------+----------------+---------+---------------+----------+---------+-------------|
    | clab-4l2s-s2 | default  | 192.168.1.1     | disabled  | 5/1/8     | pass-all       | leafs   | pass-all      | 65100    | 65001   | established |
    |              |          | 192.168.1.3     | disabled  | 5/1/8     | pass-all       | leafs   | pass-all      | 65100    | 65002   | established |
    |              |          | 192.168.1.5     | disabled  | 5/1/8     | pass-all       | leafs   | pass-all      | 65100    | 65003   | established |
    |              |          | 192.168.1.7     | disabled  | 5/1/8     | pass-all       | leafs   | pass-all      | 65100    | 65004   | established |
    |              |          | 192.168.255.1   | 0/0/0     | disabled  | pass-evpn      | overlay | pass-evpn     | 100      | 100     | established |
    |              |          | 192.168.255.2   | 0/0/0     | disabled  | pass-evpn      | overlay | pass-evpn     | 100      | 100     | established |
    |              |          | 192.168.255.3   | 0/0/0     | disabled  | pass-evpn      | overlay | pass-evpn     | 100      | 100     | established |
    |              |          | 192.168.255.4   | 0/0/0     | disabled  | pass-evpn      | overlay | pass-evpn     | 100      | 100     | established |
    +-------------------------------------------------------------------------------------------------------------------------------------------------+
    ```

From the BGP Peers output, you can see that we use eBGP for underlay routing (ASNs 65001-65004 for the leafs and ASN 65100 for the spines) and that the iBGP mesh for the overlay (ASN 100) is established through route-reflector (RR) functionality on the spines.

### Configuring services

#### Adding and modifying services

Adding and modifying services follow the same process. It takes a full **declarative** approach in how you want to configure your services. Adding services means adding configuration data to the service-specific intent files (vars files). Modifying services just involves changing the same source intent files to reflect the desired state. At no time do you need to be concerned with how existing device configuration is handled after a service change. The playbook will take care of that for you.

Let's start by **adding** a l2vpn service on 2 leafs with interface `ethernet-1/1` on each leaf as downlink or access interface. Only untagged traffic is mapped into the l2vpn. This corresponds with the initial intent that comes with the project:

```yaml title="roles/services/l2vpn/vars/test/l2vpn.yml"
l2vpn:
  macvrf-200:
    id: 200
    type: mac-vrf
    description: MACVRF200
    interface_list:
      clab-4l2s-l1:
      - ethernet-1/1.0
      clab-4l2s-l2:
      - ethernet-1/1.0
    export_rt: 100:200
    import_rt: 100:200
    vlan: untagged
```

To apply this service to the fabric, we first run the playbook in _dry-run_ mode to see what changes will be applied:

```bash
  ENV=test ansible-playbook --tags services --check --diff cf_fabric.yml
```

This will show the difference between intent and device configuration and show what configuration would be applied to the devices. We'll show the `diff` output of a single device, as the output is similar for other devices, to illustrate the transformation from 10 lines of intent to a detailed low-level device intent:

```bash
...
TASK [common/configure : Update resources on clab-4l2s-l1] ************************************************
ok: [clab-4l2s-l3]
ok: [clab-4l2s-s1]
ok: [clab-4l2s-s2]
ok: [clab-4l2s-l4]
      interface ethernet-1/1 {
+         subinterface 0 {
+             type bridged
+             admin-state enable
+             vlan {
+                 encap {
+                     untagged {
+                     }
+                 }
+             }
+         }
      }
+     network-instance macvrf-200 {
+         type mac-vrf
+         admin-state enable
+         description MACVRF200
+         interface ethernet-1/1.0 {
+         }
+         vxlan-interface vxlan1.200 {
+         }
+         protocols {
+             bgp-evpn {
+                 bgp-instance 1 {
+                     admin-state enable
+                     vxlan-interface vxlan1.200
+                     evi 200
+                     ecmp 4
+                 }
+             }
+             bgp-vpn {
+                 bgp-instance 1 {
+                     route-target {
+                         export-rt target:100:200
+                         import-rt target:100:200
+                     }
+                 }
+             }
+         }
+     }
+     tunnel-interface vxlan1 {
+         vxlan-interface 200 {
+             type bridged
+             ingress {
+                 vni 200
+             }
+         }
+     }
changed: [clab-4l2s-l1]
...
PLAY RECAP ************************************************************************************************
clab-4l2s-l1               : ok=16   changed=1    unreachable=0    failed=0    skipped=9    rescued=0    ignored=0   
clab-4l2s-l2               : ok=16   changed=1    unreachable=0    failed=0    skipped=9    rescued=0    ignored=0   
clab-4l2s-l3               : ok=11   changed=0    unreachable=0    failed=0    skipped=12   rescued=0    ignored=0   
clab-4l2s-l4               : ok=11   changed=0    unreachable=0    failed=0    skipped=12   rescued=0    ignored=0   
clab-4l2s-s1               : ok=11   changed=0    unreachable=0    failed=0    skipped=12   rescued=0    ignored=0   
clab-4l2s-s2               : ok=11   changed=0    unreachable=0    failed=0    skipped=12   rescued=0    ignored=0   
```

To apply the configuration to the devices, we run the playbook without the `--check` option:

```bash
  ENV=test ansible-playbook --tags services cf_fabric.yml
```

To verify the _idempotence_ of the playbook, you can run this command multiple times without any changes being applied to the devices.

With `fcli` we can verify that the service is configured correctly:

=== "Network Instances"
    ```
    ❯ fcli -i fabric=yes nwi-itfs -f ni="macvrf*"
                                          Network-Instance Interfaces
                                            Fields:{'ni': 'macvrf*'}
                                          Inventory:{'fabric': 'yes'}
    +--------------------------------------------------------------------------------------------------------+
    | Node         | ni         | oper | type    | router-id | Subitf         | if-oper | ipv4 | mtu  | vlan |
    |--------------+------------+------+---------+-----------+----------------+---------+------+------+------|
    | clab-4l2s-l1 | macvrf-200 | up   | mac-vrf |           | ethernet-1/1.0 | up      |      | 9232 |      |
    |--------------+------------+------+---------+-----------+----------------+---------+------+------+------|
    | clab-4l2s-l2 | macvrf-200 | up   | mac-vrf |           | ethernet-1/1.0 | up      |      | 9232 |      |
    +--------------------------------------------------------------------------------------------------------+
    ```
=== "MAC table of `macvrf-200`"
    ```
    ❯ fcli -i fabric=yes mac-table -f Netw-Inst=macvrf-200
                                                        MAC Table
                                            Fields:{'Netw-Inst': 'macvrf-200'}
                                              Inventory:{'fabric': 'yes'}
    +----------------------------------------------------------------------------------------------------------------+
    | Node         | Netw-Inst  | Address           | Dest                                                  | Type   |
    |--------------+------------+-------------------+-------------------------------------------------------+--------|
    | clab-4l2s-l1 | macvrf-200 | AA:C1:AB:7B:E7:EF | ethernet-1/1.0                                        | learnt |
    |              |            | AA:C1:AB:B2:42:95 | vxlan-interface:vxlan1.200 vtep:192.168.255.2 vni:200 | evpn   |
    |--------------+------------+-------------------+-------------------------------------------------------+--------|
    | clab-4l2s-l2 | macvrf-200 | AA:C1:AB:7B:E7:EF | vxlan-interface:vxlan1.200 vtep:192.168.255.1 vni:200 | evpn   |
    |              |            | AA:C1:AB:B2:42:95 | ethernet-1/1.0                                        | learnt |
    +----------------------------------------------------------------------------------------------------------------+
    ```

In the topology, we have linux containers connected to these interfaces: `cl10` and `cl20` are connected to `clab-4l2s-l1` and `clab-4l2s-l2`respectively. We can verify that the containers can reach each other:

=== "Server `cl10`"
    ```
        ❯ docker exec -it clab-4l2s-cl10 ip addr show dev eth1
        1229: eth1@if1228: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9500 qdisc noqueue state UP group default
        link/ether aa:c1:ab:7b:e7:ef brd ff:ff:ff:ff:ff:ff link-netnsid 1
        inet 10.0.0.1/24 scope global eth1
          valid_lft forever preferred_lft forever
        inet6 fe80::a8c1:abff:fe7b:e7ef/64 scope link
          valid_lft forever preferred_lft forever

        ❯ docker exec -it clab-4l2s-cl10 ping -c3 10.0.0.2
        PING 10.0.0.2 (10.0.0.2) 56(84) bytes of data.
        64 bytes from 10.0.0.2: icmp_seq=1 ttl=64 time=1.06 ms
        64 bytes from 10.0.0.2: icmp_seq=2 ttl=64 time=1.18 ms
        64 bytes from 10.0.0.2: icmp_seq=3 ttl=64 time=0.553 ms        
    ```
=== "Server `cl20`"
    ```
    ❯ docker exec -it clab-4l2s-cl20 ip addr sh dev eth1
    1249: eth1@if1248: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9500 qdisc noqueue state UP group default
    link/ether aa:c1:ab:b2:42:95 brd ff:ff:ff:ff:ff:ff link-netnsid 1
    inet 10.0.0.2/24 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a8c1:abff:feb2:4295/64 scope link
       valid_lft forever preferred_lft forever
    ❯ docker exec -it clab-4l2s-cl20 ping -c3 10.0.0.1
    PING 10.0.0.1 (10.0.0.1) 56(84) bytes of data.
    64 bytes from 10.0.0.1: icmp_seq=1 ttl=64 time=1.03 ms
    64 bytes from 10.0.0.1: icmp_seq=2 ttl=64 time=1.15 ms
    64 bytes from 10.0.0.1: icmp_seq=3 ttl=64 time=0.986 ms

    --- 10.0.0.1 ping statistics ---
    3 packets transmitted, 3 received, 0% packet loss, time 2002ms
    rtt min/avg/max/mdev = 0.986/1.054/1.146/0.067 ms
    ```      

In a next step we **update** the service to include the 2 other leafs with the following intent:

```yaml
l2vpn:
  macvrf-200:
    id: 200
    type: mac-vrf
    description: MACVRF200
    interface_list:
      clab-4l2s-l1:
      - ethernet-1/1.0
      clab-4l2s-l2:
      - ethernet-1/1.0
      clab-4l2s-l3:      #new
      - ethernet-1/1.0
      clab-4l2s-l4:      #new
      - ethernet-1/1.0
    export_rt: 100:200
    import_rt: 100:200
    vlan: untagged
```

Run the playbook again as before, and we can see that the service is now configured on all 4 leafs:

```bash
❯ fcli -i fabric=yes nwi-itfs -f ni="macvrf*" -b ascii
                                       Network-Instance Interfaces                                        
                                         Fields:{'ni': 'macvrf*'}                                         
                                       Inventory:{'fabric': 'yes'}                                        
+--------------------------------------------------------------------------------------------------------+
| Node         | ni         | oper | type    | router-id | Subitf         | if-oper | ipv4 | mtu  | vlan |
|--------------+------------+------+---------+-----------+----------------+---------+------+------+------|
| clab-4l2s-l1 | macvrf-200 | up   | mac-vrf |           | ethernet-1/1.0 | up      |      | 9232 |      |
|--------------+------------+------+---------+-----------+----------------+---------+------+------+------|
| clab-4l2s-l2 | macvrf-200 | up   | mac-vrf |           | ethernet-1/1.0 | up      |      | 9232 |      |
|--------------+------------+------+---------+-----------+----------------+---------+------+------+------|
| clab-4l2s-l3 | macvrf-200 | up   | mac-vrf |           | ethernet-1/1.0 | up      |      | 9232 |      |
|--------------+------------+------+---------+-----------+----------------+---------+------+------+------|
| clab-4l2s-l4 | macvrf-200 | up   | mac-vrf |           | ethernet-1/1.0 | up      |      | 9232 |      |
+--------------------------------------------------------------------------------------------------------+
```

To further illustrate the _declarative_ nature of the intents, you could change the `vlan` field to e.g. 10. This will break connectivty between the connected servers but it will yield a correct configuration on the leafs.

!!!note
    When an update to a service intent results in low-level resources (subinteface, network-instance, tunnel-interface, ...) being replaced (e.g. change subinterface ethernet-1/1.0 to ethernet-1/1.1), running a partial playbook with `--tags services` may fail model validation by SR Linux because the old interface is not deleted, resulting in 2 sub-interfaces on same parent interface with same encapsulation.

    We therefore recommend to run the full playbook (no tags or `--tags all`) when updating a service intent.

Next, we add a new l2vpn instance `macvrf-201` so that th l2vpn intent looks like this:

```yaml title="roles/services/l2vpn/vars/test/l2vpn.yaml"
l2vpn:
  macvrf-200:
#    _state: deleted
    id: 200
    type: mac-vrf
    description: MACVRF200
    interface_list:
      clab-4l2s-l1:
      - ethernet-1/1.0
      clab-4l2s-l2:
      - ethernet-1/1.0
      clab-4l2s-l3:
      - ethernet-1/1.0
      clab-4l2s-l4:
      - ethernet-1/1.0
    export_rt: 100:200
    import_rt: 100:200
    vlan: untagged
  macvrf-201:
    id: 201
    type: mac-vrf
    description: MACVRF201
    interface_list:
      clab-4l2s-l1:
      - ethernet-1/2.20
      clab-4l2s-l2:
      - ethernet-1/2.20
    export_rt: 100:201
    import_rt: 100:201
    vlan: 20
```

!!!note
    You can also split the `l2vpn` intents in multiple files inside the role's `vars` directory. Ansible will load variables from all files in aplhabetical order. This is useful if you want to split the configuration in multiple files for better readability, e.g. a file per service instance.

Run the playbook again and verify that the new service instance is configured on the leafs.

#### Deleting services

There are 2 ways to delete a service:

- implicitly by removing it from the intent. We call this _pruning_ or _purging_ resources
- explicitly by setting the `_state` field to `deleted`

In the first case, resources are removed from the device configuration if they are not present in the infra and services intents. The playbook uses the running configuration of the device to determine what resources to remove. This means that if you manually add resources to the device configuration, they will be removed when you run the playbook. This approach is suited for network teams that take a _hands-off_ approach to the device configuration and only use the playbook to configure the network.

Pruning is controlled via the `purge` and `purgeable` variables in the `cf_fabric.yml`:
  
```yaml title="cf_fabric.yml (partial)"
- name: Configure fabric
  gather_facts: no
  hosts: 
  - leaf
  - spine
  vars:
    purge: yes # purge resources from device not in intent
    purgeable: # list of resources to purge
      - interface
      - subinterface
      - network-instance
```

!!! note
    In order for pruning to work, you must run a full play, i.e. don't specify tags with `ansible-playbook` (like `--tags services`) that limit the scope of the play. Pruning is disabled if there is a partial run via tags since it results in an incomplete intent.

You can try out pruning by commenting out or removing e.g. the `macvrf-200` service in the `l2vpn` intent amd run the playbook as follows:

```bash
ENV=test ansible-playbook --diff cf_fabric.yml
```

Check the status with `fcli` or on the Linux containers attached to that service.

With explicit deletion, you set the `_state` field of a resource or service to `deleted` in the intent. This will remove the service (or resource) from the device configuration. This approach is suited for cases where only parts of the configuration are managed by the playbook. The playbook will only touch resources that are present in the intent and will only delete resources if through explicit tagging.

!!! note
    Use of the initial `_` in a field name is a convention to indicate that the field is not part of the intent but is _metadata_ used by the playbook to control the behaviour of the playbook.

To try this out, make sure macvrf-200 is present in the `l2vpn` intent and run the playbook to ensure that the service is configured on the leafs. Now remove the service explicitly by adding the `_state` field as follows:

```yaml title="roles/services/l2vpn/vars/test/l2vpn.yaml"
l2vpn:
  macvrf-200:
    _state: deleted # <--
    id: 200
    type: mac-vrf
    description: MACVRF200
    interface_list:
      clab-4l2s-l1:
      - ethernet-1/1.1
      clab-4l2s-l2:
      - ethernet-1/1.1
      clab-4l2s-l3:
      - ethernet-1/1.0
      clab-4l2s-l4:
      - ethernet-1/1.0
    export_rt: 100:200
    import_rt: 100:200
    vlan: untagged
```

Run the playbook again and verify that the service is removed from the leafs. In this case, you can do a partial run only for the services. It is not required to run a full play since the deletion is not based on intent deviation from the device configuration.

During next runs services or resources tagged for deletion remain in the intent but serve little purpose after the deletion has occurred. You may decide to keep it in the intent for _documentation_ purposes or remove it from the intent after the deletion has occurred.

#### L3VPN services

So far we only have discussed configuring L2VPN services. The same approach applies for adding, updating and pruning L3VPN services. We discuss L3VPNs at this later stage due to the dependency on L2VPNs. As you will see from the L3VPN intent below, the intent data contains references to macvrfs. As macvrfs are managed through L2VPN intents only, any reference to mac-vrfs in L3VPN intents must have its counterpart in L2VPN intents.

A L3VPN service is an abstract L3 construct that is composed of a set of subnets. A subnet is composed of a mac-vrf instance and a gateway IP address. An IP-prefix is assigned to each subnet by means of the gateway IP address. The L3VPN service acts a IP gateway for nodes connected to the subnet. Multiple subnets can be assigned to the same L3VPN service and it will perform inter-subnet routing to provide connectivity between nodes in the associated submets.

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/wdesmedt/ansible-srl-demo/main/img/ansible-srl-l3vpn.drawio.svg"}'></div>
  <figcaption>L3VPN Service</figcaption>
</figure>

The mac-vrf referenced in the subnet (`snet_list`) links to a mac-vrf instance associated with a L2VPN intent in `roles/services/l2vpn/vars/` directory. The mac-vrf instance must be defined in the L2VPN intent before it can be referenced in the L3VPN intent. This is where the physical attachments of the subnet are defined by means of interfaces and VLAN encapsulation.

At the device-level, a L3VPN service is composed of an ip-vrf instance on all the partipating nodes:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/wdesmedt/ansible-srl-demo/main/img/ansible-srl-l3vpn-lo.drawio.svg"}'></div>
  <figcaption>Device-level L3VPN Service</figcaption>
</figure>

On each of the participating nodes, 1 or more mac-vrfs are instantiated, 1 for each subnet on the node, and associated with the local ip-vrf instance by means of an _irb_ interface. Each mac-vrf gets an unique _irb_ sub-interface that is also added to the ip-vrf instance. The _irb_ sub-interface is assigned the gateway IP address of the subnet. The physical attachments are defined in the assoicated L2VPN intent (linked to L3VPN by means of macvrf name) and correspond to ethernet sub-interfaces that have encapsulation as defined by the `vlan` parameter of the L2VPN intent.

Below is an example of an L3VPN intent:

```yaml
l3vpn:
  ipvrf-2001:
    id: 2001
    type: ip-vrf
    description: IPVRF1
    snet_list:
      - macvrf: macvrf-300
        gw: 10.1.1.254/24
      - macvrf: macvrf-301
        gw: 10.1.2.254/24
    export_rt: 100:2001
    import_rt: 100:2001
```

Both `macvrf-300` and `macvrf-301` are not defined in the current L2VPN intent. Running the playbook will will not create the L3VPN service due to missing definitions of the macvrfs of the `snet_list` in the L2VPN intent.

Let's fix this by adding the missing macvrfs to the L2VPN intent:

```yaml
l2vpn:
  macvrf-300:
    id: 300
    type: mac-vrf
    description: MACVRF300
    interface_list:
      clab-4l2s-l1:
      - ethernet-1/1.300
      clab-4l2s-l2:
      - ethernet-1/1.300
    export_rt: 100:300
    import_rt: 100:300
    vlan: 300
  macvrf-301:
    id: 301
    type: mac-vrf
    description: MACVRF301
    interface_list:
      clab-4l2s-l3:
      - ethernet-1/1.301
      clab-4l2s-l4:
      - ethernet-1/1.301
    export_rt: 100:301
    import_rt: 100:301
    vlan: 301
```

Now run the playbook again and verify that the L3VPN service is configured on the leafs.

- Servers `cl10`, `cl20`, `cl30` and `cl40` have a vlan-interface (`eth1.300` and `eth1.301`) configured with an IP address in the subnet associated with the L3VPN service. You can verify connectivty by connecting to each container. For `cl10`:

    ```bash
    docker exec -it cl10 bash
    $ ping 10.1.1.2 # cl20
    $ ping 10.1.2.1 # cl30
    $ ping 10.1.2.2 # cl40
    ```

- with `fcli`:

    ```bash
    ❯ fcli -i fabric=yes nwi-itfs -f ni="ipvrf*"
                                              Network-Instance Interfaces                                           
                                                Fields:{'ni': 'ipvrf*'}                                             
                                              Inventory:{'fabric': 'yes'}                                           
    +--------------------------------------------------------------------------------------------------------------+
    | Node         | ni         | oper | type   | router-id | Subitf   | if-oper | ipv4              | mtu  | vlan |
    |--------------+------------+------+--------+-----------+----------+---------+-------------------+------+------|
    | clab-4l2s-l1 | ipvrf-2001 | up   | ip-vrf |           | irb1.300 | up      | ['10.1.1.254/24'] | 1500 |      |
    |--------------+------------+------+--------+-----------+----------+---------+-------------------+------+------|
    | clab-4l2s-l2 | ipvrf-2001 | up   | ip-vrf |           | irb1.300 | up      | ['10.1.1.254/24'] | 1500 |      |
    |--------------+------------+------+--------+-----------+----------+---------+-------------------+------+------|
    | clab-4l2s-l3 | ipvrf-2001 | up   | ip-vrf |           | irb1.301 | up      | ['10.1.2.254/24'] | 1500 |      |
    |--------------+------------+------+--------+-----------+----------+---------+-------------------+------+------|
    | clab-4l2s-l4 | ipvrf-2001 | up   | ip-vrf |           | irb1.301 | up      | ['10.1.2.254/24'] | 1500 |      |
    +--------------------------------------------------------------------------------------------------------------+
    ```

## Closing remarks

In this project, we took the approach to translate intents or desired-state from the variables associated with each role. These variables contain structured data and follow a model that is interpreted by the role's template to generate input for the `config` module. Only one role, the `common/configure` role, uses the `nokia.srlinux.config` module directly and is run as a last step in the play. The other roles only generate the low-level intent, i.e. the input to the `config` module, from the higher-level intent stored in the role's variables and in the inventory.

The reasons for this approach are:

- avoid _dependencies_ between resources and _sequencing_ issues. Since SR Linux is a model-driven NOS, dependencies of resources, as described in the Yang modules are enforced by SR Linux. Pushing config snippets rather than complete configs will be more error-prone to model constraints, e.g. pushing configuration that adds sub-interfaces to a network instance that are not created beforehand, will result in a configuration error. By grouping all configuration statements together and call the config module only once, we avoid these issues. SR Linux will take care of the sequencing and apply changes in a single transaction.
- support for _resource pruning_. By building a full intent for managed resources, we know exactly the desired state the fabric should be in. Using the SR Linux node as configuration state store, we can compare the desired state with the actual configuration state of the node and prune any resources that are not part of the desired state. There is no need to flag such resources for deletion which is the typical approach with Ansible NetRes modules for other NOS's.
- support for _network audit_. The same playbook that is used to apply the desired state can be used to audit the network. By comparing the full desired state with the actual configuration state of the node, we can detect any drift and report it to the user. This is achieved by running the playbook in _dry-run_ or _check_ mode.
- keeping role-specific intent with the role itself, in the associated variables, results in separation of concerns and makes the playbook more readable and maintainable. It's like functions in a generic programming language: the role is the function and the variables are the arguments.
- device-level single transaction. The `config` module is called only once per device and results in a single transaction per device - _all or nothing_. This is important to keep the device configuration consistent. If the playbook would call the `config` module multiple times, e.g. once per role, and some of the roles would fail, this would leave the device in an inconsistent state with only partial config applied. 

This is a 'low-code' approach to network automation using only Jinja2 templating and the Ansible domain-specific language. It does require some basic development and troubleshooting skills as playbook errors will happen and debugging will be required. For example, when adding new capabilities to roles/templates, when SR Linux model changes happen across software releases, .... These events may break template rendering inside the roles.

*Network-wide transactions* could be implemented with _Git_. You `git commit` your changes (intents/roles) to a Git repository after any change to intents or roles. If some issues occur during the playbook run, e.g. some nodes fail in the playbook resulting in a partial fabric-wide deployment or changes appear to be permanently service-affecting, you can revert back to a previous commit with e.g. `git revert` and run the playbook again from a known good state (intent/roles).

Transformation from high-level intent to per-device low-level configuration is a one-way street. There is no way to go back from the low-level configuration to the high-level intent. This means that it is not possible to _reconcile_ changes in the network that were not driven by intent. For this to happen, a manual step is required to update the intent with the new state of the network.

Finally, we would appreciate your feedback on this project. Please open an issue in the [GitHub repository][ansible-srl-demo] if you have any questions or remarks.

[collection-doc-link]: ../../../ansible/collection/index.md
[ansible-srl-demo]: https://github.com/wdesmedt/ansible-srl-demo

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
