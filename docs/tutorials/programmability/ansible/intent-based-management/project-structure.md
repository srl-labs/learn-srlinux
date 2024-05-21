---
comments: true
---

# Project structure

## The Ansible Inventory

In this project, we use the native file-based Ansible inventory. It lists the hosts that are part of the fabric and groups them in a way that reflects the fabric topology. The inventory file - [`ansible-inventory.yml`](https://github.com/srl-labs/intent-based-ansible-lab/blob/main/inv/ansible-inventory.yml) - is located in the [`inv`](https://github.com/srl-labs/intent-based-ansible-lab/tree/main/inv) directory; `group_vars`contains connectivity parameters for specific device groups, like `srl` for SR Linux.

```bash
├── ansible-inventory.yml
└── group_vars
    └── srl.yml
```

Ansible is instructed to use this inventory file by setting `inventory = inv` in the [`ansible.cfg`](https://github.com/srl-labs/intent-based-ansible-lab/blob/main/ansible.cfg#L4) configuration file.

The `ansible-inventory.yml` defines four groups:

- `srl` - for all SR Linux nodes
- `spine` - for the spine nodes
- `leaf` - for the leaf nodes.
- `hosts` - for emulated hosts.

## Intents

Intents describe desired state of the fabric via structured data in YAML files. The files are stored in an intent directory that is specified as an _extra-var_ option to the `ansible-playbook` command, e.g. `ansible-playbook -e intent_dir=`_absolute path to the intent dir_

There are 2 types of intents:

### Level-1 intents

Level-1 intents are _infrastructure-level_ intents and describe per-device configuration following an abstracted device-model. Each top-level resource has a custom data model that is close to the SR Linux data model but different. This _device abstraction layer_ allows to support multiple NOS types (like SROS) and also to shield device-model changes across releases from the defined intent.

The data model for these intents are defined per level-1 resource (e.g. `network_instance`, `interface`, `system`, ...) and are defined in json-schema format in directory `playbooks/roles/infra/criteria`.

Level-1 intents can be defined at host- and group-level (as defined in the Ansible inventory). Host-level intent files need to start with `host_infra`, e.g. `host_infra.yml` and group-level intent files have to start with `group_infra`.
An example of a group-level infra intent is:

```yaml title="<code>group_infra.yml</code> (partial)"
leaf:
  interfaces:
    ethernet-1/{1..4,10,49..50}:
      admin_state: enable
    ethernet-1/{1..4,10}:
      vlan_tagging: yes
    ethernet-1/{49..50}:
    irb1:
    system0:
      admin_state: enable
...
```

`leaf` references a group in the Ansible inventory and this applies to all nodes in that group. Intent files support ranges as shown in above example.

Node-level intents follow the same device model and may have overlapping definitions with the group-level intents. Host-level intents always take precedence over group-level intents.

### Level-2 intents

Level-2 intents are intents at a higher abstraction layer and describe _fabric-wide intents_, such as fabric intents that describe high-level underlay parameters and service intents such as bridge-domains (l2vpn) and inter-subnet routing (l3vpn) and multi-homing intents (lags and ethernet-segments).

  The data model for each level-2 intent type are defined in the respective roles that transform level-2 intent into level-1 intent:

- FABRIC intent schema is defined in [`playbooks/roles/fabric/criteria/fabric_intent.json`](https://github.com/srl-labs/intent-based-ansible-lab/blob/dev/playbooks/roles/fabric/criteria/fabric_intent.json). Intent file must have `fabric` in its name
- L2VPN intent schema in [`playbooks/roles/l2vpn/criteria/l2vpn.json`](https://github.com/srl-labs/intent-based-ansible-lab/blob/dev/playbooks/roles/l2vpn/criteria/l2vpn.json). Intent files must start with `l2vpn`, e.g. `l2vpn_acme.yml`
- L3VPN intent schema in [`playbooks/roles/l3vpn/criteria/l3vpn.json`](https://github.com/srl-labs/intent-based-ansible-lab/blob/dev/playbooks/roles/l3vpn/criteria/l3vpn.json). Intent files must start with `l3vpn`
- Multi-homing schema in [`playbooks/roles/mh_access/criteria/mh_access.json`](https://github.com/srl-labs/intent-based-ansible-lab/blob/dev/playbooks/roles/mh_access/criteria/mh_access.json). Intent files must start with `mh_access`
  
We'll discuss these in more detail later in this tutorial when we configure the fabric.

## The Ansible Playbook

The Ansible playbook [`cf_fabric.yml`](https://github.com/srl-labs/intent-based-ansible-lab/blob/dev/playbooks/cf_fabric.yml) is the main entry point for the project. It contains a single play that applies a sequence of roles to all nodes in the `leaf` and `spine` groups:

```yaml title="<code>cf_fabric.yml</code>"
--8<-- "https://raw.githubusercontent.com/srl-labs/intent-based-ansible-lab/dev/playbooks/cf_fabric.yml"
```

The playbook is structured in 3 sections:

1. the `hosts` variable at play-level defines the hosts that are part of the fabric. In this case, all hosts in the `leaf` and `spine` groups. Group definition and membership is defined in the inventory file.
2. the `roles` variable defines the roles that are applied to the hosts defined in the `hosts` section. The roles are applied in the order they are defined in the playbook. The roles are grouped in 4 sections: `INIT`, `INFRA`, `SERVICES` and `CONFIG-PUSH`.
    - **INIT**: This section initializes some extra global variables or _Ansible facts_ that are used by other roles. These facts include:
        - the current 'running config' of the device
        - the SR Linux software version
        - the LLDP neighborship states
    - **INFRA**: This section has 2 roles:
        - `fabric`: this role generates level-1 intents based on a fabric intent defined in the intent directory. If there is no fabric intent file present, this role will have no effect (skipped)
        - `infra`: this role validates and merges group- and host infra intents to form a level-1 per-device infra intent.
    - **SERVICES**: This section validates the level-2 intents (`services` role) and each of the roles in the rest of the this section transforms the level-2 intent into a per-device level-1 intent.
    - **CONFIG PUSH**: This section applies configuration to the nodes. This is where the level-1 intent is transformed into actual device configuration. It also has the capability to _prune_ resources that exist on the device but have no matching intent. This requires the `.role.purge` to be set to `true`. The list of purgeable resources is also configurable via `.role.purgeable`.

Following diagram gives an overview how the low-level device intent is constructed from the various roles:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/intent-based-ansible-lab/main/img/ansible-srl-intent.drawio.svg"}'></div>
  <figcaption>Transforming high-level intent to device configuration</figcaption>
</figure>

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
