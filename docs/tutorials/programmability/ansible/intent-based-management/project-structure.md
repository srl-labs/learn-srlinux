---
comments: true
---

# Project structure

## The Ansible Inventory

In this project, we use the native file-based Ansible inventory. It lists the hosts that are part of the fabric and groups them in a way that reflects the fabric topology. The inventory file - [`ansible-inventory.yml`](https://github.com/srl-labs/intent-based-ansible-lab/blob/main/inv/ansible-inventory.yml) - is located in the [`inv`](https://github.com/srl-labs/intent-based-ansible-lab/tree/main/inv) directory; `host_vars` and `group_vars` directories next to it contain host- and group-specific variables.

```bash
inv
├── ansible-inventory.yml # the inventory file
├── group_vars
│   └── srl.yml  # group-specific variables for the srl group
└── host_vars
    ├── clab-4l2s-l1.yml # host-specific variables for the clab-4l2s-l1 host
    ├── clab-4l2s-l2.yml
    ├── clab-4l2s-l3.yml
    ├── clab-4l2s-l4.yml
    ├── clab-4l2s-s1.yaml
    └── clab-4l2s-s2.yml
```

Ansible is instructed to use this inventory file by setting `inventory = inv` in the [`ansible.cfg`](https://github.com/srl-labs/intent-based-ansible-lab/blob/main/ansible.cfg#L4) configuration file.

The `ansible-inventory.yml` defines four groups:

- `srl` - for all SR Linux nodes
- `spine` - for the spine nodes
- `leaf` - for the leaf nodes.
- `hosts` - for emulated hosts.

The [`host_vars`](https://github.com/srl-labs/intent-based-ansible-lab/tree/main/inv/host_vars) directory contains a file for each host that defines host-specific variables. The [`group_vars`](https://github.com/srl-labs/intent-based-ansible-lab/tree/main/inv/group_vars) directory contains a single file for the `srl` group to define Ansible-specific variables that are required for the JSON-RPC connection-plugin as well as some system-level configuration data.

## The Ansible Playbook

The Ansible playbook [`cf_fabric.yml`](https://github.com/srl-labs/intent-based-ansible-lab/blob/main/cf_fabric.yml) is the main entry point for the project. It contains a single play that applies a sequence of roles to all nodes in the `leaf` and `spine` groups:

```yaml title="<code>cf_fabric.yml</code>"
--8<-- "https://raw.githubusercontent.com/srl-labs/intent-based-ansible-lab/main/cf_fabric.yml"
```

The playbook is structured in 3 sections:

1. the `hosts` variable at play-level defines the hosts that are part of the fabric. In this case, all hosts in the `leaf` and `spine` groups. Group definition and membership is defined in the inventory file.
2. the `vars` variable defines variables that are used by the roles. In this case, the `purge` variable is set to `yes` to remove resources from the nodes that are not defined in the intent. The `purgeable` variable defines the resource types that are purged from the nodes when missing from the intent. In this case, these resources are: interfaces, sub-interfaces and network instances.
3. the `roles` variable defines the roles that are applied to the hosts in the `leaf` and `spine` groups. The roles are applied in the order they are defined in the playbook. The roles are grouped in 4 sections: `INIT`, `INFRA`, `SERVICES` and `CONFIG`.
    - **INIT**: This section initializes some extra global variables or _Ansible facts_ that are used by other roles. These facts include:
        - the current 'running config' of the device
        - the SR Linux software version
        - the LLDP neighborship states
    - **INFRA**: This section configures the infrastructural network resources needed for services to operate. It configures the inter-switch interfaces, base routing, policies and the default instance
    - **SERVICES**: This section configures the services on the nodes. It configures the L2VPN and L3VPN services based on a high-level abstraction defined in each role's variables
    - **CONFIG**: This section applies configuration to the nodes. It is always executed, even if no changes are made to the configuration. This is to ensure that the configuration on the node is always in sync with the intent.

The `common/init` role checks if the `ENV` environment variable is set. If it's missing, the playbook will fail. The value of the `ENV` variable is used to select the correct role variables that represent the intent. This is to support multiple environments, like 'test' and 'prod' environments, for which intents may be different. In this project, only the `test` environment is defined.

Roles also have _tags_ associated with them to run a subset of the roles in the playbook. For example, to only run the `infra` roles, you can use the following command:

```bash
ENV=test ansible-playbook cf_fabric.yml --tags infra
```

!!!note
    To leverage the _pruning_ capability of the playbook, all roles must be executed to achieve a full intent. If tags are specified for a partial run, no purging will be performed by the playbook.

## Role structure

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

### INFRA roles

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

The `tasks/main.yml` file defines the tasks that are executed by the role. The `templates` folder contains jinja templates per supported platform; these templates are used by the role when executing tasks. Let's look at the `infra/interface` role as an example:

```yaml title="<code>roles/infra/interface/tasks/main.yml</code>"
--8<-- "https://raw.githubusercontent.com/srl-labs/intent-based-ansible-lab/main/roles/infra/interface/tasks/main.yml"
```

The `infra/interface` role loads the host-specific intent by calling another role - `utils/load_intent`. This role takes the group- and host-level intents from the `vars/${ENV}` folder - in our case `ENV=test` -  and merges them into a single role-specific intent (`my_intent`). The `my_intent` variable is then merged with the global per-device `intent` variable that may have been already partially populated by other roles.

Other infra roles follow the same approach.

### SERVICES roles

Two service roles are defined:

- **l2vpn**: manages intent for _fabric-wide_ L2VPN services. These are a set of mac-vrf instances on a subset of the nodes in the fabric with associated interfaces and policies
- **l3vpn**: manages intent for _fabric-wide_ L3VPN services. These are a set of ip-vrf instances on a subset of the nodes in the fabric and are associated with mac-vrf instances

For these roles, we decided to take the abstraction to a new level. Below is an example how a L2VPN is defined:

  ```yaml title="<code>roles/services/l2vpn/vars/test/l2vpn.yml</code>"
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

```yaml title="<code>roles/services/l3vpn/vars/test/l3vpn.yml</code>"
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

### COMMON and UTILS roles

Once the nodal intent has been constructed by the INFRA and SERVICES roles, the playbook calls the `common/configure` role as the last task. This role will take the nodal intent and construct the final configuration for the node. It calls roles in the `utils` folder to construct the configuration for the various resources (interfaces, network-instances, policies, etc) and thus generates the variables `update` and `replace` that are passed as arguments to the `nokia.srlinux.config` module.

It also generates a `delete` variable containing a list of configuration paths to delete when the play variable `purge=true` and when no tags are specified with the `ansible-playbook` command that would result in a partial nodal intent. It uses the node for configuration state (running configuration) that was retrieved by the `common/init` role and compares this against the nodal intent to generate the `delete` variable.

Following diagram gives an overview how the low-level device intent is constructed from the various roles:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/intent-based-ansible-lab/main/img/ansible-srl-intent.drawio.svg"}'></div>
  <figcaption>Transforming high-level intent to device configuration</figcaption>
</figure>

The abstraction level defined in the roles eventually transforms to the low-level device configs that is then applied to the node. Essentially, the role designers have to decide how much abstraction they want to provide to the user of the role. The more abstraction, the easier it is to use the role, but the less flexibility the user has to configure the node. Network automation engineers then can adapt the provided roles to their needs by changing the abstraction level of the roles.

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
