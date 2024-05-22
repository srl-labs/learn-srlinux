---
comments: true
---

# Configuring the fabric

## Startup configuration

The initial configuration of the fabric nodes after setting up your environment, only contains the required statements to allow management connections to the nodes (SSH, gNMI, JSON-RPC). No further configuration is applied to the nodes.

If you have installed the [fcli](https://github.com/srl-labs/nornir-srl) tool, you can verify the initial state of the fabric with the following command that lists all the network-instances active on the fabric nodes. Alternatively, you can log into the nodes and verify the configuration manually. Only a single network instance `mgmt` should be present on each node.

=== "LLDP neighbors"
    ```bash
    ❯ fcli lldp
                               LLDP Neighbors
    +----------------------------------------------------------------------------+
    | Node         | interface     | Nbr-System | Nbr-port      | Nbr-port-desc  |
    |--------------+---------------+------------+---------------+----------------|
    | clab-4l2s-l1 | ethernet-1/49 | s2         | ethernet-1/1  | no description |
    |              | ethernet-1/50 | s1         | ethernet-1/1  | no description |
    |--------------+---------------+------------+---------------+----------------|
    | clab-4l2s-l2 | ethernet-1/49 | s2         | ethernet-1/2  | no description |
    |              | ethernet-1/50 | s1         | ethernet-1/2  | no description |
    |--------------+---------------+------------+---------------+----------------|
    | clab-4l2s-l3 | ethernet-1/49 | s2         | ethernet-1/3  | no description |
    |              | ethernet-1/50 | s1         | ethernet-1/3  | no description |
    |--------------+---------------+------------+---------------+----------------|
    | clab-4l2s-l4 | ethernet-1/49 | s2         | ethernet-1/4  | no description |
    |              | ethernet-1/50 | s1         | ethernet-1/4  | no description |
    |--------------+---------------+------------+---------------+----------------|
    | clab-4l2s-s1 | ethernet-1/1  | l1         | ethernet-1/50 | no description |
    |              | ethernet-1/2  | l2         | ethernet-1/50 | no description |
    |              | ethernet-1/3  | l3         | ethernet-1/50 | no description |
    |              | ethernet-1/4  | l4         | ethernet-1/50 | no description |
    |--------------+---------------+------------+---------------+----------------|
    | clab-4l2s-s2 | ethernet-1/1  | l1         | ethernet-1/49 | no description |
    |              | ethernet-1/2  | l2         | ethernet-1/49 | no description |
    |              | ethernet-1/3  | l3         | ethernet-1/49 | no description |
    |              | ethernet-1/4  | l4         | ethernet-1/49 | no description |
    +----------------------------------------------------------------------------+
    ```
=== "Network instances and interfaces"
    ```bash
    ❯ fcli ni
                                               Network Instances and interfaces                                            
    +---------------------------------------------------------------------------------------------------------------------+
    | Node         | NI   | oper | type   | router-id | Subitf  | assoc-ni | if-oper | ipv4                 | mtu  | vlan |
    |--------------+------+------+--------+-----------+---------+----------+---------+----------------------+------+------|
    | clab-4l2s-l1 | mgmt | up   | ip-vrf |           | mgmt0.0 |          | up      | ['172.20.21.11/24']  | 1500 |      |
    |--------------+------+------+--------+-----------+---------+----------+---------+----------------------+------+------|
    | clab-4l2s-l2 | mgmt | up   | ip-vrf |           | mgmt0.0 |          | up      | ['172.20.21.12/24']  | 1500 |      |
    |--------------+------+------+--------+-----------+---------+----------+---------+----------------------+------+------|
    | clab-4l2s-l3 | mgmt | up   | ip-vrf |           | mgmt0.0 |          | up      | ['172.20.21.13/24']  | 1500 |      |
    |--------------+------+------+--------+-----------+---------+----------+---------+----------------------+------+------|
    | clab-4l2s-l4 | mgmt | up   | ip-vrf |           | mgmt0.0 |          | up      | ['172.20.21.14/24']  | 1500 |      |
    |--------------+------+------+--------+-----------+---------+----------+---------+----------------------+------+------|
    | clab-4l2s-s1 | mgmt | up   | ip-vrf |           | mgmt0.0 |          | up      | ['172.20.21.101/24'] | 1500 |      |
    |--------------+------+------+--------+-----------+---------+----------+---------+----------------------+------+------|
    | clab-4l2s-s2 | mgmt | up   | ip-vrf |           | mgmt0.0 |          | up      | ['172.20.21.102/24'] | 1500 |      |
    +---------------------------------------------------------------------------------------------------------------------+
    ```

## Configuring the underlay

To configure the underlay of the fabric - the configuration of interfaces and routing to make overlay services possible - we apply the `infra` intent to all nodes in the `leaf` and `spine` nodes.
We can use the level-2 Fabric Intent or we can use level-1 Infra Intent files to configure the underlay.

### Using Fabric Intent

Let's start with a _Fabric Intent_. This is the easiest to use, as it only requires a limited number of parameters. The `fabric` role, which is the only role that uses Python to transform high-level intents (fabric intent) into per-device level-1 infra intents. Other roles are based on Jinja templates.

The `intent_examples` directory contains a set of prepared intents. Following fabric intent is in `intent_examples/infra/underlay_with_fabric_intent`:

```yaml title="<code>fabric_intent.yml</code>"
fabric:
  underlay_routing:
    bgp:
      bgp-unnumbered: false
      asn: 64601-65500

  # IP range for loopback interfaces
  loopback: 192.168.255.0/24

  # IP range for point-to-point links. Can also be specified as a list of CIDRs.
  # p2p:
  #   - 100.64.0.0/17
  #   - 100.64.128.0/24
  p2p: 100.64.0.0/16

  # AS number for overlay network
  overlay_asn: 65501

  # Configuration for Route Reflectors (RR)
  rr:
    # Location for RRs could be 'spine', 'external', 'borderleaf', 'superspine'
    location: 'spine'
    # List of neighbor IPs for Route Reflectors in case of 'external'
    # neighbor_list:
    #   - 1.1.1.1
    #   - 2.2.2.2

  # Spine specific configuration, defines which ports can be used for ISLs
  spine:
    clab-4l2s-s[1-2]:
      isl-ports: ethernet-1/[1-128] # in case of 7220IXR-H2

  # Physical cabling layout between network devices
  fabric_cabling:
    - endpoints: ["clab-4l2s-l1:e1-50", "clab-4l2s-s1:e1-1"]
    - endpoints: ["clab-4l2s-l1:e1-49", "clab-4l2s-s2:e1-1"]
    - endpoints: ["clab-4l2s-l2:e1-50", "clab-4l2s-s1:e1-2"]
    - endpoints: ["clab-4l2s-l2:e1-49", "clab-4l2s-s2:e1-2"]
    - endpoints: ["clab-4l2s-l3:e1-50", "clab-4l2s-s1:e1-3"]
    - endpoints: ["clab-4l2s-l3:e1-49", "clab-4l2s-s2:e1-3"]
    - endpoints: ["clab-4l2s-l4:e1-50", "clab-4l2s-s1:e1-4"]
    - endpoints: ["clab-4l2s-l4:e1-49", "clab-4l2s-s2:e1-4"]

  # Override settings for specific devices
  # Overrides can be 'asn', 'loopback' or 'id'
  overrides:
    clab-4l2s-s1:
      asn: 65100
      loopback: 192.168.255.101
    clab-4l2s-s2:
      asn: 65100
      loopback: 192.168.255.102
    clab-4l2s-l1:
      asn: 65001
      loopback: 192.168.255.1
    clab-4l2s-l2:
      asn: 65002
      loopback: 192.168.255.2
    lab-4l2s-l3:
      asn: 65003
      loopback: 192.168.255.3
    clab-4l2s-l4:
      asn: 65004
      loopback: 192.168.255.4

# Sizing and capacity planning for the network fabric
# Must include all properties here
# Warning: changing any value here might lead to re-distribution of ASNs, loopback- and/or ISL-addresses!
sizing:
  max_pod: 2                  # Type: number, minimum: 0
  max_dcgw: 2                 # Type: number, minimum: 0
  max_superspine: 2           # Type: number, minimum: 0
  max_spine_in_pod: 4         # Type: number, minimum: 0, recommended minimum: 4
  max_borderleaf_in_pod: 2    # Type: number, minimum: 0
  max_leaf_in_pod: 12         # Type: number, minimum: 0, recommended minimum: 12
  max_isl_per_spine: 128      # Type: number, minimum: 0, recommended minimum: 128
  max_isl_per_dcgw: 4         # Type: number, minimum: 0
```

!!!note
    As explained before, the schema of the fabric intent is defined in `playbooks/roles/fabric/criteria/fabric_intent.json`.

The Fabric Intent role assumes an IBGP mesh for overlay services (EVPN routes). Underlay routing is either EBGP, as in this example, or OSPF. It provides the capability to specify `overrides`. This is optional and when absent, the `fabric` role will provide values automatically.

Copy the files in `intent_examples/infra/underlay_with_fabric_intent` into the `intent` folder and run the `cf_fabric` playbook as follows:

```bash
cp intent_examples/infra/underlay_with_fabric_intent/* intent
ansible-playbook -i inv -e intent_dir=${PWD}/intent --diff playbooks/cf_fabric.yml
```

This will deploy the underlay configuration to all the nodes of the fabric. Let's check the fabric status with `fcli`:

=== "BGP Peers"
    ```bash
    ❯ fcli bgp-peers
                                                                          BGP Peers
                                                              Inventory filter:{'fabric': 'yes'}
    +------------------------------------------------------------------------------------------------------------------------------------------------------------+
    |              |         |                 | AF: EVPN  | AF: IPv4  | AF: IPv6  |                |         |               |          |         |             |
    | Node         | NI      | 1_peer          | Rx/Act/Tx | Rx/Act/Tx | Rx/Act/Tx | export_policy  | group   | import_policy | local_as | peer_as | state       |
    |--------------+---------+-----------------+-----------+-----------+-----------+----------------+---------+---------------+----------+---------+-------------|
    | clab-4l2s-l1 | default | 100.64.0.16     | disabled  | 8/7/2     | disabled  | lo-and-servers | spines  | pass-all      | 65001    | 65100   | established |
    |              |         | 100.64.1.16     | disabled  | 8/7/5     | disabled  | lo-and-servers | spines  | pass-all      | 65001    | 65100   | established |
    |              |         | 192.168.255.101 | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.102 | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |--------------+---------+-----------------+-----------+-----------+-----------+----------------+---------+---------------+----------+---------+-------------|
    | clab-4l2s-l2 | default | 100.64.0.18     | disabled  | 8/7/2     | disabled  | lo-and-servers | spines  | pass-all      | 65002    | 65100   | established |
    |              |         | 100.64.1.18     | disabled  | 8/7/5     | disabled  | lo-and-servers | spines  | pass-all      | 65002    | 65100   | established |
    |              |         | 192.168.255.101 | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.102 | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |--------------+---------+-----------------+-----------+-----------+-----------+----------------+---------+---------------+----------+---------+-------------|
    | clab-4l2s-l3 | default | 100.64.0.20     | disabled  | 8/7/2     | disabled  | lo-and-servers | spines  | pass-all      | 64609    | 65100   | established |
    |              |         | 100.64.1.20     | disabled  | 8/7/5     | disabled  | lo-and-servers | spines  | pass-all      | 64609    | 65100   | established |
    |              |         | 192.168.255.101 | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.102 | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |--------------+---------+-----------------+-----------+-----------+-----------+----------------+---------+---------------+----------+---------+-------------|
    | clab-4l2s-l4 | default | 100.64.0.22     | disabled  | 8/7/2     | disabled  | lo-and-servers | spines  | pass-all      | 65004    | 65100   | established |
    |              |         | 100.64.1.22     | disabled  | 8/7/5     | disabled  | lo-and-servers | spines  | pass-all      | 65004    | 65100   | established |
    |              |         | 192.168.255.101 | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.102 | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |--------------+---------+-----------------+-----------+-----------+-----------+----------------+---------+---------------+----------+---------+-------------|
    | clab-4l2s-s1 | default | 100.64.0.17     | disabled  | 2/1/8     | disabled  | pass-all       | leafs   | pass-all      | 65100    | 65001   | established |
    |              |         | 100.64.0.19     | disabled  | 2/1/8     | disabled  | pass-all       | leafs   | pass-all      | 65100    | 65002   | established |
    |              |         | 100.64.0.21     | disabled  | 2/1/8     | disabled  | pass-all       | leafs   | pass-all      | 65100    | 64609   | established |
    |              |         | 100.64.0.23     | disabled  | 2/1/8     | disabled  | pass-all       | leafs   | pass-all      | 65100    | 65004   | established |
    |              |         | 192.168.255.1   | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.2   | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.4   | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.12  | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |--------------+---------+-----------------+-----------+-----------+-----------+----------------+---------+---------------+----------+---------+-------------|
    | clab-4l2s-s2 | default | 100.64.1.17     | disabled  | 5/1/8     | disabled  | pass-all       | leafs   | pass-all      | 65100    | 65001   | established |
    |              |         | 100.64.1.19     | disabled  | 5/1/8     | disabled  | pass-all       | leafs   | pass-all      | 65100    | 65002   | established |
    |              |         | 100.64.1.21     | disabled  | 5/1/8     | disabled  | pass-all       | leafs   | pass-all      | 65100    | 64609   | established |
    |              |         | 100.64.1.23     | disabled  | 5/1/8     | disabled  | pass-all       | leafs   | pass-all      | 65100    | 65004   | established |
    |              |         | 192.168.255.1   | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.2   | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.4   | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.12  | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    +------------------------------------------------------------------------------------------------------------------------------------------------------------+
    ```
=== "Network instances and interfaces"
    ```bash
    ❯ fcli ni
                                                     Network Instances and interfaces
                                                    Inventory filter:{'fabric': 'yes'}
    +-----------------------------------------------------------------------------------------------------------------------------------------+
    | Node         | NI      | oper | type    | router-id       | Subitf          | assoc-ni | if-oper | ipv4                   | mtu  | vlan |
    |--------------+---------+------+---------+-----------------+-----------------+----------+---------+------------------------+------+------|
    | clab-4l2s-l1 | default | up   | default | 192.168.255.1   | ethernet-1/49.0 |          | up      | ['100.64.1.17/31']     | 9214 |      |
    |              |         |      |         |                 | ethernet-1/50.0 |          | up      | ['100.64.0.17/31']     | 9214 |      |
    |              |         |      |         |                 | system0.0       |          | up      | ['192.168.255.1/32']   |      |      |
    |              | mgmt    | up   | ip-vrf  |                 | mgmt0.0         |          | up      | ['172.20.21.11/24']    | 1500 |      |
    |--------------+---------+------+---------+-----------------+-----------------+----------+---------+------------------------+------+------|
    | clab-4l2s-l2 | default | up   | default | 192.168.255.2   | ethernet-1/49.0 |          | up      | ['100.64.1.19/31']     | 9214 |      |
    |              |         |      |         |                 | ethernet-1/50.0 |          | up      | ['100.64.0.19/31']     | 9214 |      |
    |              |         |      |         |                 | system0.0       |          | up      | ['192.168.255.2/32']   |      |      |
    |              | mgmt    | up   | ip-vrf  |                 | mgmt0.0         |          | up      | ['172.20.21.12/24']    | 1500 |      |
    |--------------+---------+------+---------+-----------------+-----------------+----------+---------+------------------------+------+------|
    | clab-4l2s-l3 | default | up   | default | 192.168.255.12  | ethernet-1/49.0 |          | up      | ['100.64.1.21/31']     | 9214 |      |
    |              |         |      |         |                 | ethernet-1/50.0 |          | up      | ['100.64.0.21/31']     | 9214 |      |
    |              |         |      |         |                 | system0.0       |          | up      | ['192.168.255.12/32']  |      |      |
    |              | mgmt    | up   | ip-vrf  |                 | mgmt0.0         |          | up      | ['172.20.21.13/24']    | 1500 |      |
    |--------------+---------+------+---------+-----------------+-----------------+----------+---------+------------------------+------+------|
    | clab-4l2s-l4 | default | up   | default | 192.168.255.4   | ethernet-1/49.0 |          | up      | ['100.64.1.23/31']     | 9214 |      |
    |              |         |      |         |                 | ethernet-1/50.0 |          | up      | ['100.64.0.23/31']     | 9214 |      |
    |              |         |      |         |                 | system0.0       |          | up      | ['192.168.255.4/32']   |      |      |
    |              | mgmt    | up   | ip-vrf  |                 | mgmt0.0         |          | up      | ['172.20.21.14/24']    | 1500 |      |
    |--------------+---------+------+---------+-----------------+-----------------+----------+---------+------------------------+------+------|
    | clab-4l2s-s1 | default | up   | default | 192.168.255.101 | ethernet-1/1.0  |          | up      | ['100.64.0.16/31']     | 9214 |      |
    |              |         |      |         |                 | ethernet-1/2.0  |          | up      | ['100.64.0.18/31']     | 9214 |      |
    |              |         |      |         |                 | ethernet-1/3.0  |          | up      | ['100.64.0.20/31']     | 9214 |      |
    |              |         |      |         |                 | ethernet-1/4.0  |          | up      | ['100.64.0.22/31']     | 9214 |      |
    |              |         |      |         |                 | system0.0       |          | up      | ['192.168.255.101/32'] |      |      |
    |              | mgmt    | up   | ip-vrf  |                 | mgmt0.0         |          | up      | ['172.20.21.101/24']   | 1500 |      |
    |--------------+---------+------+---------+-----------------+-----------------+----------+---------+------------------------+------+------|
    | clab-4l2s-s2 | default | up   | default | 192.168.255.102 | ethernet-1/1.0  |          | up      | ['100.64.1.16/31']     | 9214 |      |
    |              |         |      |         |                 | ethernet-1/2.0  |          | up      | ['100.64.1.18/31']     | 9214 |      |
    |              |         |      |         |                 | ethernet-1/3.0  |          | up      | ['100.64.1.20/31']     | 9214 |      |
    |              |         |      |         |                 | ethernet-1/4.0  |          | up      | ['100.64.1.22/31']     | 9214 |      |
    |              |         |      |         |                 | system0.0       |          | up      | ['192.168.255.102/32'] |      |      |
    |              | mgmt    | up   | ip-vrf  |                 | mgmt0.0         |          | up      | ['172.20.21.102/24']   | 1500 |      |
    +-----------------------------------------------------------------------------------------------------------------------------------------+
    ```

!!!note
    Since we're using BGP in the underlay to provide connectivity for IBGP/EVPN in the overlay, not all BGP sessions will establish immediately. First the underlay EBGP sessions must be established and exchange loopback address information before the IBGP sessions can establish.

!!!note
    Notice that the IBGP sessions exchange no routes. This is expected as we didn't configure overlay services or Ethernet Segments yet that would trigger announcement of EVPN routes.

Alternatively, we could opt to use _BGP unnumbered_ inter-switch links (dynamic BGP-peers using IPv6 LLA addresses). It suffices to change the `.fabric.underlay_routing.bgp.bgp-unnumbered` from `false` to `true`, remove the `.fabric.p2p` parameter as inter-switch link addresses are no longer needed, and run the playbook again. Since intents are declarative, there is no need to worry about the previous configuration. Run the playbook again as before and check the fabric status.

=== "BGP peers with BGP unnumbered peers"
    ```bash
    ❯ fcli bgp-peers
                                                                                    BGP Peers                                                                                      
    +----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
    |              |         |                                       | AF: EVPN  | AF: IPv4  | AF: IPv6  |                |         |               |          |         |             |
    | Node         | NI      | 1_peer                                | Rx/Act/Tx | Rx/Act/Tx | Rx/Act/Tx | export_policy  | group   | import_policy | local_as | peer_as | state       |
    |--------------+---------+---------------------------------------+-----------+-----------+-----------+----------------+---------+---------------+----------+---------+-------------|
    | clab-4l2s-l1 | default | 192.168.255.101                       | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.102                       | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | fe80::1871:cff:feff:1%ethernet-1/50.0 | disabled  | 4/4/2     | disabled  | lo-and-servers | spines  | pass-all      | 65001    | 65100   | established |
    |              |         | fe80::18aa:dff:feff:1%ethernet-1/49.0 | disabled  | 4/4/5     | disabled  | lo-and-servers | spines  | pass-all      | 65001    | 65100   | established |
    |--------------+---------+---------------------------------------+-----------+-----------+-----------+----------------+---------+---------------+----------+---------+-------------|
    | clab-4l2s-l2 | default | 192.168.255.101                       | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.102                       | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | fe80::1871:cff:feff:2%ethernet-1/50.0 | disabled  | 4/4/2     | disabled  | lo-and-servers | spines  | pass-all      | 65002    | 65100   | established |
    |              |         | fe80::18aa:dff:feff:2%ethernet-1/49.0 | disabled  | 4/4/5     | disabled  | lo-and-servers | spines  | pass-all      | 65002    | 65100   | established |
    |--------------+---------+---------------------------------------+-----------+-----------+-----------+----------------+---------+---------------+----------+---------+-------------|
    | clab-4l2s-l3 | default | 192.168.255.101                       | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.102                       | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | fe80::1871:cff:feff:3%ethernet-1/50.0 | disabled  | 4/4/2     | disabled  | lo-and-servers | spines  | pass-all      | 64609    | 65100   | established |
    |              |         | fe80::18aa:dff:feff:3%ethernet-1/49.0 | disabled  | 4/4/5     | disabled  | lo-and-servers | spines  | pass-all      | 64609    | 65100   | established |
    |--------------+---------+---------------------------------------+-----------+-----------+-----------+----------------+---------+---------------+----------+---------+-------------|
    | clab-4l2s-l4 | default | 192.168.255.101                       | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.102                       | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | fe80::1871:cff:feff:4%ethernet-1/50.0 | disabled  | 4/4/2     | disabled  | lo-and-servers | spines  | pass-all      | 65004    | 65100   | established |
    |              |         | fe80::18aa:dff:feff:4%ethernet-1/49.0 | disabled  | 4/4/5     | disabled  | lo-and-servers | spines  | pass-all      | 65004    | 65100   | established |
    |--------------+---------+---------------------------------------+-----------+-----------+-----------+----------------+---------+---------------+----------+---------+-------------|
    | clab-4l2s-s1 | default | 192.168.255.1                         | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.2                         | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.4                         | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.12                        | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | fe80::184a:9ff:feff:32%ethernet-1/2.0 | disabled  | 2/1/4     | disabled  | pass-all       | leafs   | pass-all      | 65100    | 65002   | established |
    |              |         | fe80::18ab:bff:feff:32%ethernet-1/4.0 | disabled  | 2/1/4     | disabled  | pass-all       | leafs   | pass-all      | 65100    | 65004   | established |
    |              |         | fe80::18ce:8ff:feff:32%ethernet-1/1.0 | disabled  | 2/1/4     | disabled  | pass-all       | leafs   | pass-all      | 65100    | 65001   | established |
    |              |         | fe80::18e3:aff:feff:32%ethernet-1/3.0 | disabled  | 2/1/4     | disabled  | pass-all       | leafs   | pass-all      | 65100    | 64609   | established |
    |--------------+---------+---------------------------------------+-----------+-----------+-----------+----------------+---------+---------------+----------+---------+-------------|
    | clab-4l2s-s2 | default | 192.168.255.1                         | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.2                         | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.4                         | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | 192.168.255.12                        | 0/0/0     | disabled  | disabled  | pass-evpn      | overlay | pass-evpn     | 65501    | 65501   | established |
    |              |         | fe80::184a:9ff:feff:31%ethernet-1/2.0 | disabled  | 5/1/4     | disabled  | pass-all       | leafs   | pass-all      | 65100    | 65002   | established |
    |              |         | fe80::18ab:bff:feff:31%ethernet-1/4.0 | disabled  | 5/1/4     | disabled  | pass-all       | leafs   | pass-all      | 65100    | 65004   | established |
    |              |         | fe80::18ce:8ff:feff:31%ethernet-1/1.0 | disabled  | 5/1/4     | disabled  | pass-all       | leafs   | pass-all      | 65100    | 65001   | established |
    |              |         | fe80::18e3:aff:feff:31%ethernet-1/3.0 | disabled  | 5/1/4     | disabled  | pass-all       | leafs   | pass-all      | 65100    | 64609   | established |
    +----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
    ```


### Using level-1 infra intents

Alternative to a Fabric Intent, we can use level-1 Infra Intents. This gives more flexibility on configurable parameters at the expensive of extra configuration data. We have group-level and host-level infrastructure intents. An example of level-1 intents for the underlay are available in the `intent_examples` directory. Empty the `./intent` folder that currently holds the fabric intent and copy over the level-1 intent files that define the underlay:

```bash
rm -f intent/* && cp intent_examples/infra/underlay_with_level1_intents/* ./intent
ansible-playbook -i inv -e intent_dir=${PWD}/intent --diff playbooks/cf_fabric.yml
```

The schema files for these level-1 intents exist in the `playbooks/roles/infra/criteria` directory. There is a JSON-schema file per top-level level-1 resource.

Both the level-2 Fabric Intent and level-1 Infra Intents can be used together with the latter taking precedence over the Fabric intent generated level-1 intent. This is because of the order of role execution in the `cf_fabric` playbook: the `fabric` role is run before the `infra` role.

## Configuring services

### Multi-homing Access Intent

Although not a true service intent, the Multi-homing Access intent is a requirement for services that have multi-homed clients. It involves creating a LAG interface with the proper member links and LACP parameters as well as the EVPN Ethernet Segment that is the standarized construct for EVPN multi-homing in either _all-active_ or _single-active_ mode.
There is an N:1 relationship between a L2VPN service and a Multi-homing Access instance.

These intents are handled by the `mh_access` role and the schema of `mh_access` intents are defined in `playbooks/roles/mh_access/criteria/mh_access.json`.

Let's start by adding a `mh_access` intent to create a multi-homed lag for `cl121` that is multi-homed to `clab-4l2s-l1` and `clab-4l2s-l2`:

```yaml
mh-1: # ID used to construct ESI <prefix>:<id>:<lag_id>, lag_id per rack, id farbic wide 
  lag_id: lag1
  mh_mode: all-active # all-active or single-active
  description: mh-1:LAG1
  lacp_interval: FAST
  interface_list:
    clab-4l2s-l1:
    - ethernet-1/20
    clab-4l2s-l2:
    - ethernet-1/20
  lacp: true
  vlan_tagging: true
  min_links: 1
```

Each Multi-Homing Access intent is identified by an id in the format `mh-`_identifier_ that must be unique across all `mh_access` intents. This intent creates a LAG interface `lag1` on nodes specified in the `interface_list` on the specified interfaces.

Alternatively, you can use interface tags to reference the interfaces of a multi-homing access like so:

```yaml title="<code>mh_access-1.yml</code>"
mh-1:
  lag_id: lag1
  mh_mode: all-active 
  description: mh-1:LAG1
  lacp_interval: FAST
  interface_tags: # interfaces must be tagged with ANY tags specified in interface_tags
    - mh-1
  lacp: true
  vlan_tagging: true
  min_links: 1
```

This decouples the MH Access intent definition from physical topological aspects of the fabric. This requires that the proper interfaces are tagged with `mh-1` in the infra intents:

```yaml title="<code>host_infra_itf_tags.yml</code>"
clab-4l2s-l1:
  interfaces:
    ethernet-1/20:
      TAGS:
        - mh-1
clab-4l2s-l2:
  interfaces:
    ethernet-1/20:
      TAGS:
        - mh-1
```

Copy over above 2 files from `intent_examples/services` into `intent/` and run the playbook:

```
cp intent_examples/services/mh_access-1.yml intent_examples/services/host_infra_itf_tags.yml intent
ansible-playbook -i inv -e intent_dir=${PWD}/intent --diff playbooks/cf_fabric.yml
```

!!!note
    Although we use a separate infra intent file for the interface tagging, it's equally valid to update the existing group- or host_infra files to include the interface tagging. All level-1 intents in group and host infra files get merged to a single per-device level-1 intent, with host data taking precedence over group data.

Check the relevant state of the fabric:

=== "LAGs"
    ```bash
    ❯ fcli lag
                                                                                          LAGs
                                                                           Inventory filter:{'fabric': 'yes'}
    +--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
    | Node         | lag  | oper | mtu  | min | desc      | type | speed | stby-sig | lacp-key | lacp-itvl | lacp-mode | lacp-sysid        | lacp-prio | act    | member-itf | member-oper |
    |--------------+------+------+------+-----+-----------+------+-------+----------+----------+-----------+-----------+-------------------+-----------+--------+------------+-------------|
    | clab-4l2s-l1 | lag1 | up   | 9232 | 1   | mh-1:LAG1 | lacp | 25000 |          | 1        | FAST      | ACTIVE    | 00:1A:60:00:00:01 | 32768     | ACTIVE | et-1/20    | up          |
    |--------------+------+------+------+-----+-----------+------+-------+----------+----------+-----------+-----------+-------------------+-----------+--------+------------+-------------|
    | clab-4l2s-l2 | lag1 | up   | 9232 | 1   | mh-1:LAG1 | lacp | 25000 |          | 1        | FAST      | ACTIVE    | 00:1A:60:00:00:01 | 32768     | ACTIVE | et-1/20    | up          |
    +-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+  
    ```
=== "Ethernet Segments"
    ```bash
    ❯ fcli es
                                     Ethernet Segments
                              Inventory filter:{'fabric': 'yes'}
    +--------------------------------------------------------------------------------------------+
    | Node         | name  | esi                           | mh-mode    | oper | itf  | ni-peers |
    |--------------+-------+-------------------------------+------------+------+------+----------|
    | clab-4l2s-l1 | ES-01 | 00:01:01:00:00:00:66:00:01:01 | all-active | up   | lag1 |          |
    |--------------+-------+-------------------------------+------------+------+------+----------|
    | clab-4l2s-l2 | ES-01 | 00:01:01:00:00:00:66:00:01:01 | all-active | up   | lag1 |          |
    +--------------------------------------------------------------------------------------------+
    ```

### L2VPN Intent

L2VPN intents describe high-level parameters required to deploy a fabric-wide bridge-domain. The schema of the configuration data is defined in `playbooks/roles/l2vpn/criteria/l2vpn.json`.

Below is an example of a L2VPN intent definition:

```yaml title="l2vpn_101.yml"
subnet-1:
  id: 101
  type: mac-vrf
  description: subnet-1
  proxy_arp: true
  interface_tags:
    - _mh-1     # interfaces created by mh_access intent 'mh-1' are tagged with '_mh-1'
  export_rt: 100:101
  import_rt: 100:101
  vlan: 100
```

A L2VPN intent definition starts with the name of the service, `subnet-1` in this example together with its properties. `id` is a unique ID across all service instances. This intent will create a mac-vrf on all nodes that have interfaces tagged with `_mh-1` with the mac-vrf name equal to the L2VPN name.
This `_mh_1` tag is a special type of tag, starting with `_` and is automatically added to interfaces by the Multi-homing Access intent `mh-1`. A sub-interface for each of the tagged interfaces is created with the proper VLAN encapsulation and associated with the mac-vrf instances on the nodes with the tagged interfaces.

Let's copy this file from the intent examples directory and deploy it:

```
cp intent_examples/services/l2vpn_101.yml intent
ansible-playbook -i inv -e intent_dir=${PWD}/intent --diff playbooks/cf_fabric.yml
```

Check the state of the service and the Ethernet Segments in the fabric with `fcli`:

=== "Network Instances"
    ```bash
    ❯ fcli ni -f ni=subnet-1
                                     Network Instances and interfaces
                                      Fields filter:{'ni': 'subnet-1'}
    +-----------------------------------------------------------------------------------------------------------+
    | Node         | NI       | oper | type    | router-id | Subitf   | assoc-ni | if-oper | ipv4 | mtu  | vlan |
    |--------------+----------+------+---------+-----------+----------+----------+---------+------+------+------|
    | clab-4l2s-l1 | subnet-1 | up   | mac-vrf |           | lag1.100 |          | up      |      | 9232 | 100  |
    |--------------+----------+------+---------+-----------+----------+----------+---------+------+------+------|
    | clab-4l2s-l2 | subnet-1 | up   | mac-vrf |           | lag1.100 |          | up      |      | 9232 | 100  |
    +-----------------------------------------------------------------------------------------------------------+
    ```
=== "Ethernet Segments"
    ```bash
    ❯ fcli es
                                                       Ethernet Segments
    +------------------------------------------------------------------------------------------------------------------------------+
    | Node         | name  | esi                           | mh-mode    | oper | itf  | ni-peers                                   |
    |--------------+-------+-------------------------------+------------+------+------+--------------------------------------------|
    | clab-4l2s-l1 | ES-01 | 00:01:01:00:00:00:66:00:01:01 | all-active | up   | lag1 | subnet-1:[192.168.255.1 192.168.255.2(DF)] |
    |--------------+-------+-------------------------------+------------+------+------+--------------------------------------------|
    | clab-4l2s-l2 | ES-01 | 00:01:01:00:00:00:66:00:01:01 | all-active | up   | lag1 | subnet-1:[192.168.255.1 192.168.255.2(DF)] |
    +------------------------------------------------------------------------------------------------------------------------------+
    ```
We now have bridge domain across leaf1 and leaf2 with a single multi-homed interface for client `cl121`, which is not very useful. Lets add another another Multi-homing Access intent for `cl123` and `cl342` that are part of the same subnet (based on IP configuration of the `bond0.100` interface).

Two additional LAG interfaces are required to be mapped to the bridge domain:

* LAG with interface `e-1/30` on `leaf1` and `leaf2` for client `cl123`
* LAG with interface `e-1/30` on `leaf3` and `leaf4` for client `cl342`

The appropriate interface tagging has already been done in `host_infra_itf_tags.yml` of the previous step. We now need to reference these tags in 2 additional Multi-homing Access intents in the existing L2VPN intent.

The `mh_access_2.yml` file contains the 2 extra `mh_access` intents, the `l2vpn_101bis.yml` contains an updated L2VPN intent for `subnet-1` and now references these extra Multi-homing Access intents.

```
cp intent_examples/services/mh_access-2.yml intent
cp intent_examples/services/l2vpn_101bis.yml intent/l2vpn_101.yml # replaces the previous
ansible-playbook -i inv -e intent_dir=${PWD}/intent --diff playbooks/cf_fabric.yml
```

Verify the LAGs, ES's and mac-vrf `subnet-1`:

=== "LAGs"
    ```bash
    ❯ fcli lag
                                                                                          LAGs
    +--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
    | Node         | lag  | oper | mtu  | min | desc      | type | speed | stby-sig | lacp-key | lacp-itvl | lacp-mode | lacp-sysid        | lacp-prio | act    | member-itf | member-oper |
    |--------------+------+------+------+-----+-----------+------+-------+----------+----------+-----------+-----------+-------------------+-----------+--------+------------+-------------|
    | clab-4l2s-l1 | lag1 | up   | 9232 | 1   | mh-1:LAG1 | lacp | 25000 |          | 1        | FAST      | ACTIVE    | 00:1A:60:00:00:01 | 32768     | ACTIVE | et-1/20    | up          |
    |              | lag2 | up   | 9232 | 1   | mh-2:LAG1 | lacp | 25000 |          | 2        | FAST      | ACTIVE    | 00:1A:60:00:00:02 | 32768     | ACTIVE | et-1/30    | up          |
    |--------------+------+------+------+-----+-----------+------+-------+----------+----------+-----------+-----------+-------------------+-----------+--------+------------+-------------|
    | clab-4l2s-l2 | lag1 | up   | 9232 | 1   | mh-1:LAG1 | lacp | 25000 |          | 1        | FAST      | ACTIVE    | 00:1A:60:00:00:01 | 32768     | ACTIVE | et-1/20    | up          |
    |              | lag2 | up   | 9232 | 1   | mh-2:LAG1 | lacp | 25000 |          | 2        | FAST      | ACTIVE    | 00:1A:60:00:00:02 | 32768     | ACTIVE | et-1/30    | up          |
    |--------------+------+------+------+-----+-----------+------+-------+----------+----------+-----------+-----------+-------------------+-----------+--------+------------+-------------|
    | clab-4l2s-l3 | lag1 | up   | 9232 | 1   | mh-3:LAG1 | lacp | 25000 |          | 1        | FAST      | ACTIVE    | 00:1A:60:00:00:01 | 32768     | ACTIVE | et-1/30    | up          |
    |--------------+------+------+------+-----+-----------+------+-------+----------+----------+-----------+-----------+-------------------+-----------+--------+------------+-------------|
    | clab-4l2s-l4 | lag1 | up   | 9232 | 1   | mh-3:LAG1 | lacp | 25000 |          | 1        | FAST      | ACTIVE    | 00:1A:60:00:00:01 | 32768     | ACTIVE | et-1/30    | up          |
    +--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
    ```
=== "Ethernet Segments"
    ```bash
    ❯ fcli es
                                                          Ethernet Segments
    +------------------------------------------------------------------------------------------------------------------------------+
    | Node         | name  | esi                           | mh-mode    | oper | itf  | ni-peers                                   |
    |--------------+-------+-------------------------------+------------+------+------+--------------------------------------------|
    | clab-4l2s-l1 | ES-01 | 00:01:01:00:00:00:66:00:01:01 | all-active | up   | lag1 | subnet-1:[192.168.255.1 192.168.255.2(DF)] |
    |              | ES-02 | 00:02:02:00:00:00:66:00:02:02 | all-active | up   | lag2 | subnet-1:[192.168.255.1 192.168.255.2(DF)] |
    |--------------+-------+-------------------------------+------------+------+------+--------------------------------------------|
    | clab-4l2s-l2 | ES-01 | 00:01:01:00:00:00:66:00:01:01 | all-active | up   | lag1 | subnet-1:[192.168.255.1 192.168.255.2(DF)] |
    |              | ES-02 | 00:02:02:00:00:00:66:00:02:02 | all-active | up   | lag2 | subnet-1:[192.168.255.1 192.168.255.2(DF)] |
    |--------------+-------+-------------------------------+------------+------+------+--------------------------------------------|
    | clab-4l2s-l3 | ES-03 | 00:01:03:00:00:00:66:00:01:03 | all-active | up   | lag1 | subnet-1:[192.168.255.3 192.168.255.4(DF)] |
    |--------------+-------+-------------------------------+------------+------+------+--------------------------------------------|
    | clab-4l2s-l4 | ES-03 | 00:01:03:00:00:00:66:00:01:03 | all-active | up   | lag1 | subnet-1:[192.168.255.3 192.168.255.4(DF)] |
    +------------------------------------------------------------------------------------------------------------------------------+
    ```
=== "mac-vrf `subnet-1`"
    ```bash
    ❯ fcli ni -f ni=subnet-1
                                          Network Instances and interfaces
                                          Fields filter:{'ni': 'subnet-1'}
    +-----------------------------------------------------------------------------------------------------------+
    | Node         | NI       | oper | type    | router-id | Subitf   | assoc-ni | if-oper | ipv4 | mtu  | vlan |
    |--------------+----------+------+---------+-----------+----------+----------+---------+------+------+------|
    | clab-4l2s-l1 | subnet-1 | up   | mac-vrf |           | lag1.100 |          | up      |      | 9232 | 100  |
    |              |          |      |         |           | lag2.100 |          | up      |      | 9232 | 100  |
    |--------------+----------+------+---------+-----------+----------+----------+---------+------+------+------|
    | clab-4l2s-l2 | subnet-1 | up   | mac-vrf |           | lag1.100 |          | up      |      | 9232 | 100  |
    |              |          |      |         |           | lag2.100 |          | up      |      | 9232 | 100  |
    |--------------+----------+------+---------+-----------+----------+----------+---------+------+------+------|
    | clab-4l2s-l3 | subnet-1 | up   | mac-vrf |           | lag1.100 |          | up      |      | 9232 | 100  |
    |--------------+----------+------+---------+-----------+----------+----------+---------+------+------+------|
    | clab-4l2s-l4 | subnet-1 | up   | mac-vrf |           | lag1.100 |          | up      |      | 9232 | 100  |
    +-----------------------------------------------------------------------------------------------------------+
    ```

Verify connectivity between clients `cl121`, `cl123` and `cl342`. They should be able to ping each other.

=== "ping from `cl121` to `cl123` and `cl343`"
    ```bash
    $ docker exec -it clab-4l2s-cl121 ping -c3 10.0.1.3
    PING 10.0.1.3 (10.0.1.3) 56(84) bytes of data.
    64 bytes from 10.0.1.3: icmp_seq=1 ttl=64 time=0.116 ms
    64 bytes from 10.0.1.3: icmp_seq=2 ttl=64 time=0.074 ms
    64 bytes from 10.0.1.3: icmp_seq=3 ttl=64 time=0.068 ms

    --- 10.0.1.3 ping statistics ---
    3 packets transmitted, 3 received, 0% packet loss, time 2084ms
    rtt min/avg/max/mdev = 0.068/0.086/0.116/0.021 ms
    
    $ docker exec -it clab-4l2s-cl121 ping -c3 10.0.1.4
    PING 10.0.1.4 (10.0.1.4) 56(84) bytes of data.
    64 bytes from 10.0.1.4: icmp_seq=1 ttl=64 time=0.349 ms
    64 bytes from 10.0.1.4: icmp_seq=2 ttl=64 time=0.217 ms
    64 bytes from 10.0.1.4: icmp_seq=3 ttl=64 time=0.274 ms

    --- 10.0.1.4 ping statistics ---
    3 packets transmitted, 3 received, 0% packet loss, time 2028ms
    rtt min/avg/max/mdev = 0.217/0.280/0.349/0.054 ms
    ```

After a successful connectivity check, the mac-table of mac-vrf `subnet-1` is populated with the mac-addresses of the 3 clients.
Verify the mac-table of `subnet-1`:

=== "mac-vrf `subnet-1`"
    ```bash
    ❯ fcli mac -f ni=subnet-1
                                                            MAC Table
                                                  Fields filter:{'ni': 'subnet-1'}
    +--------------------------------------------------------------------------------------------------------------------------+
    | Node         | NI       | Address           | Dest                                                         | Type        |
    |--------------+----------+-------------------+--------------------------------------------------------------+-------------|
    | clab-4l2s-l1 | subnet-1 | 00:C1:AB:00:01:21 | lag1.100                                                     | learnt      |
    |              |          | 00:C1:AB:00:01:23 | lag2.100                                                     | learnt      |
    |              |          | 00:C1:AB:00:03:43 | vxlan-interface:vxlan1.101 esi:00:01:03:00:00:00:66:00:01:03 | evpn        |
    |              |          | 1A:26:09:FF:00:00 | vxlan-interface:vxlan1.101 vtep:192.168.255.2 vni:101        | evpn-static |
    |              |          | 1A:3D:0B:FF:00:00 | vxlan-interface:vxlan1.101 vtep:192.168.255.4 vni:101        | evpn-static |
    |              |          | 1A:87:0A:FF:00:00 | vxlan-interface:vxlan1.101 vtep:192.168.255.3 vni:101        | evpn-static |
    |              |          | 1A:F9:08:FF:00:00 | reserved                                                     | reserved    |
    |--------------+----------+-------------------+--------------------------------------------------------------+-------------|
    | clab-4l2s-l2 | subnet-1 | 00:C1:AB:00:01:21 | lag1.100                                                     | evpn        |
    |              |          | 00:C1:AB:00:01:23 | lag2.100                                                     | learnt      |
    |              |          | 00:C1:AB:00:03:43 | vxlan-interface:vxlan1.101 esi:00:01:03:00:00:00:66:00:01:03 | evpn        |
    |              |          | 1A:26:09:FF:00:00 | reserved                                                     | reserved    |
    |              |          | 1A:3D:0B:FF:00:00 | vxlan-interface:vxlan1.101 vtep:192.168.255.4 vni:101        | evpn-static |
    |              |          | 1A:87:0A:FF:00:00 | vxlan-interface:vxlan1.101 vtep:192.168.255.3 vni:101        | evpn-static |
    |              |          | 1A:F9:08:FF:00:00 | vxlan-interface:vxlan1.101 vtep:192.168.255.1 vni:101        | evpn-static |
    |--------------+----------+-------------------+--------------------------------------------------------------+-------------|
    | clab-4l2s-l3 | subnet-1 | 00:C1:AB:00:01:21 | vxlan-interface:vxlan1.101 esi:00:01:01:00:00:00:66:00:01:01 | evpn        |
    |              |          | 00:C1:AB:00:01:23 | vxlan-interface:vxlan1.101 esi:00:02:02:00:00:00:66:00:02:02 | evpn        |
    |              |          | 00:C1:AB:00:03:43 | lag1.100                                                     | learnt      |
    |              |          | 1A:26:09:FF:00:00 | vxlan-interface:vxlan1.101 vtep:192.168.255.2 vni:101        | evpn-static |
    |              |          | 1A:3D:0B:FF:00:00 | vxlan-interface:vxlan1.101 vtep:192.168.255.4 vni:101        | evpn-static |
    |              |          | 1A:87:0A:FF:00:00 | reserved                                                     | reserved    |
    |              |          | 1A:F9:08:FF:00:00 | vxlan-interface:vxlan1.101 vtep:192.168.255.1 vni:101        | evpn-static |
    |--------------+----------+-------------------+--------------------------------------------------------------+-------------|
    | clab-4l2s-l4 | subnet-1 | 00:C1:AB:00:01:21 | vxlan-interface:vxlan1.101 esi:00:01:01:00:00:00:66:00:01:01 | evpn        |
    |              |          | 00:C1:AB:00:01:23 | vxlan-interface:vxlan1.101 esi:00:02:02:00:00:00:66:00:02:02 | evpn        |
    |              |          | 00:C1:AB:00:03:43 | lag1.100                                                     | evpn        |
    |              |          | 1A:26:09:FF:00:00 | vxlan-interface:vxlan1.101 vtep:192.168.255.2 vni:101        | evpn-static |
    |              |          | 1A:3D:0B:FF:00:00 | reserved                                                     | reserved    |
    |              |          | 1A:87:0A:FF:00:00 | vxlan-interface:vxlan1.101 vtep:192.168.255.3 vni:101        | evpn-static |
    |              |          | 1A:F9:08:FF:00:00 | vxlan-interface:vxlan1.101 vtep:192.168.255.1 vni:101        | evpn-static |
    +--------------------------------------------------------------------------------------------------------------------------+
    ```

### L3VPN services

L3VPN intents describe high-level parameters required to deploy ip-vrfs on the participating nodes. The schema of the configuration data is defined in `playbooks/roles/l3vpn/criteria/l3vpn.json`.

Below is an example of a L3VPN intent definition:

```yaml title="l3vpn_2001.yml"
ipvrf-1:
  id: 2001
  type: ip-vrf
  arp_timeout: 280
  description: ipvrf-1::cust:Acme
  snet_list:
    - macvrf: subnet-1
      gw: 10.0.1.254/24
    - macvrf: subnet-2
      gw: 10.0.2.254/24
  export_rt: 100:2002
  import_rt: 100:2002
```

A L3VPN intent definition starts with the name of the service, `ipvrf-1` in this example together with its properties. `id` is a unique ID across all service instances (L2VPNs and L3VPNs).

`snet_list` is a list of subnets. Each subnet is defined by an existing mac-vrf on the node and the anycast gateway IP address of the subnet. This intent will create an ip-vrf with name `ipvrf-1` on all nodes that have mac-vrf `subnet-1` configured.

To verify inter-subnet routing, we need to create an additional L2VPN service. Let's first define 2 `mh_access` intents for multi-homed clients `cl122` and `cl341`. The appropriate interface-tagging has already been done in a previous step.

```yaml title="mh_access-3.yml"
mh-4: # ID used to construct ESI <prefix>:<id>:<lag_id>, lag_id per rack, id farbic wide 
  lag_id: lag3
  mh_mode: all-active # all-active or single-active
  description: mh-4:LAG1
  lacp_interval: FAST
  interface_tags: # interfaces must be tagged with ANY tags specified in interface_tags
    - mh-4
  lacp: true
  vlan_tagging: true
  min_links: 1
mh-5: # ID used to construct ESI <prefix>:<id>:<lag_id>, lag_id per rack, id farbic wide 
  lag_id: lag4
  mh_mode: all-active # all-active or single-active
  description: mh-5:LAG1
  lacp_interval: FAST
  interface_tags: # interfaces must be tagged with ANY tags specified in interface_tags
    - mh-5
  lacp: true
  vlan_tagging: true
  min_links: 1
```

Next, we define a new L2VPN instance `subnet-2` and attach it to `cl122` with IP address `10.0.2.2/24` and `cl341` (`10.0.2.3/24`) through the internal tags of `mh-4` and `mh-5`:

```yaml title="l2vpn_102.yml"
subnet-2:
  id: 102
  type: mac-vrf
  description: subnet-2
  proxy_arp: true
  interface_tags:
    - _mh-4
    - _mh-5
  export_rt: 100:102
  import_rt: 100:102
  vlan: 200
```

Now the L3VPN service is defined using the two L2VPN intents (subnets) together with the additional L2VPN intent for `subnet-2`. Let's copy this file from the intent examples directory and deploy it:

```
cp intent_examples/services/mh_access-3.yml intent
cp intent_examples/services/l2vpn_102.yml intent
cp intent_examples/services/l3vpn_2001.yml intent
ansible-playbook -i inv -e intent_dir=${PWD}/intent --diff playbooks/cf_fabric.yml
```

=== "ip-vrf `ipvrf-1`"
    ```bash
    ❯ fcli ni -f ni=ipvrf-1
                                               Network Instances and interfaces
                                                Fields filter:{'ni': 'ipvrf-1'}
    +----------------------------------------------------------------------------------------------------------------------+
    | Node         | NI      | oper | type   | router-id | Subitf   | assoc-ni | if-oper | ipv4              | mtu  | vlan |
    |--------------+---------+------+--------+-----------+----------+----------+---------+-------------------+------+------|
    | clab-4l2s-l1 | ipvrf-1 | up   | ip-vrf |           | irb1.101 | subnet-1 | up      | ['10.0.1.254/24'] | 9214 |      |
    |              |         |      |        |           | irb1.102 | subnet-2 | up      | ['10.0.2.254/24'] | 9214 |      |
    |--------------+---------+------+--------+-----------+----------+----------+---------+-------------------+------+------|
    | clab-4l2s-l2 | ipvrf-1 | up   | ip-vrf |           | irb1.101 | subnet-1 | up      | ['10.0.1.254/24'] | 9214 |      |
    |              |         |      |        |           | irb1.102 | subnet-2 | up      | ['10.0.2.254/24'] | 9214 |      |
    |--------------+---------+------+--------+-----------+----------+----------+---------+-------------------+------+------|
    | clab-4l2s-l3 | ipvrf-1 | up   | ip-vrf |           | irb1.101 | subnet-1 | up      | ['10.0.1.254/24'] | 9214 |      |
    |              |         |      |        |           | irb1.102 | subnet-2 | up      | ['10.0.2.254/24'] | 9214 |      |
    |--------------+---------+------+--------+-----------+----------+----------+---------+-------------------+------+------|
    | clab-4l2s-l4 | ipvrf-1 | up   | ip-vrf |           | irb1.101 | subnet-1 | up      | ['10.0.1.254/24'] | 9214 |      |
    |              |         |      |        |           | irb1.102 | subnet-2 | up      | ['10.0.2.254/24'] | 9214 |      |
    ```

You can now verify inter-subnet routing between clients in different subnets.

=== "ping from `cl121` to `cl341`"
    ```bash
    $ docker exec -it clab-4l2s-cl121 ip address show dev bond0.100
    3: bond0.100@bond0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
        link/ether 00:c1:ab:00:01:21 brd ff:ff:ff:ff:ff:ff
        inet 10.0.1.2/24 scope global bond0.100
          valid_lft forever preferred_lft forever
        inet6 fe80::2c1:abff:fe00:121/64 scope link
          valid_lft forever preferred_lft forever
    $ docker exec -it clab-4l2s-cl121 ping -c3 10.0.2.3
    PING 10.0.2.3 (10.0.2.3) 56(84) bytes of data.
    64 bytes from 10.0.2.3: icmp_seq=1 ttl=63 time=0.347 ms
    64 bytes from 10.0.2.3: icmp_seq=2 ttl=63 time=0.200 ms
    64 bytes from 10.0.2.3: icmp_seq=3 ttl=63 time=0.205 ms

    --- 10.0.2.3 ping statistics ---
    3 packets transmitted, 3 received, 0% packet loss, time 2039ms
    rtt min/avg/max/mdev = 0.200/0.250/0.347/0.068 ms
    ```
=== "ARP table"
    ```bash
    ❯ fcli arp -f ni="*ipvrf-1*"
                                                    ARP table
                                        Fields filter:{'ni': '*ipvrf-1*'}
    +-------------------------------------------------------------------------------------------------------+
    | Node         | interface | NI                     | IPv4     | MAC               | Type    | expiry   |
    |--------------+-----------+------------------------+----------+-------------------+---------+----------|
    | clab-4l2s-l1 | irb1.101  | ["ipvrf-1","subnet-1"] | 10.0.1.2 | 00:C1:AB:00:01:21 | dynamic | 0:00:58s |
    |              | irb1.102  | ["ipvrf-1","subnet-2"] | 10.0.2.2 | 00:C1:AB:00:01:22 | evpn    | -        |
    |              |           |                        | 10.0.2.3 | 00:C1:AB:00:03:41 | evpn    | -        |
    |--------------+-----------+------------------------+----------+-------------------+---------+----------|
    | clab-4l2s-l2 | irb1.101  | ["ipvrf-1","subnet-1"] | 10.0.1.2 | 00:C1:AB:00:01:21 | evpn    | -        |
    |              | irb1.102  | ["ipvrf-1","subnet-2"] | 10.0.2.2 | 00:C1:AB:00:01:22 | dynamic | 0:02:34s |
    |              |           |                        | 10.0.2.3 | 00:C1:AB:00:03:41 | evpn    | -        |
    |--------------+-----------+------------------------+----------+-------------------+---------+----------|
    | clab-4l2s-l3 | irb1.101  | ["ipvrf-1","subnet-1"] | 10.0.1.2 | 00:C1:AB:00:01:21 | evpn    | -        |
    |              | irb1.102  | ["ipvrf-1","subnet-2"] | 10.0.2.2 | 00:C1:AB:00:01:22 | evpn    | -        |
    |              |           |                        | 10.0.2.3 | 00:C1:AB:00:03:41 | dynamic | 0:00:58s |
    |--------------+-----------+------------------------+----------+-------------------+---------+----------|
    | clab-4l2s-l4 | irb1.101  | ["ipvrf-1","subnet-1"] | 10.0.1.2 | 00:C1:AB:00:01:21 | evpn    | -        |
    |              | irb1.102  | ["ipvrf-1","subnet-2"] | 10.0.2.2 | 00:C1:AB:00:01:22 | evpn    | -        |
    |              |           |                        | 10.0.2.3 | 00:C1:AB:00:03:41 | evpn    | -        |
    +-------------------------------------------------------------------------------------------------------+
    ```

### Deleting services

There are 2 ways to delete a service:

* implicitly by removing it from the intent. We call this _pruning_ or _purging_ resources
* explicitly by setting the `_state` field to `deleted`

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

You can try out pruning by commenting out or removing service instances in the intent files under `./intent` or by adding the property `_state: deleted` to the service instance and run the `cf_fabric` playbook as usual.

!!! note
    The use of the `_state` property to delete a service may serve the purpose of documentation. If you want to keep the service definition in your intent but don't want it to be deployed (yet/no more).

!!! note
    Use of the initial `_` in a field name is a convention to indicate that the field is not part of the intent but is _metadata_ used by the playbook to control the behaviour of the playbook.

If you are in a brownfield situation where not all resources are to be managed by this playbook, you can limit the scope of your intents to the part you want to automate with this project, together with tuning the `purge` and `purgeable` variables in the main playbook.

### Confirming commits

Although you have the option to run the playbook in _dry-run_ mode with the `--check` option to `ansible-playbook`, together with the `--diff` option to get the changes listed at the end of the playbook run, this still may not give you sufficient confidence in the changes you want to apply to the network.

The `cf_fabric` playbook leverages the _commit confirm_ functionality of SR Linux to require to explicitly confirm the commit after it has been applied to the device. If no confirmation is given within a specified interval, the changes of the last committed change are rolled back by the device.

To use this functionality, specify the extra variable `confirm_timeout` when you run the playbook, e.g.:

```bash
ansible-playbook -i inv -e intent_dir=${PWD}/intent -e confirm_timeout=60 --diff playbooks/cf_fabric.yml 
```

This will make the playbook run interactive and it will ask for explicit confirmation to leave the latest commit intact. If no confirmation is given, the commits are rolled back after the specified timeout.

```bash title="Playbook output with commit-confirm"
PLAY [Commit changes when confirm_timeout is set] ************************************************************************************************************************************************************

TASK [Pausing playbook before confirming commits] ************************************************************************************************************************************************************
Pausing for 55 seconds
(ctrl+C then 'C' = continue early, ctrl+C then 'A' = abort)
[Pausing playbook before confirming commits]
Abort and allow commits to revert in 60 secs.
Continue or wait to go ahead and confirm commits:
Press 'C' to continue the play or 'A' to abort 
```

To accept the change, wait for the timeout to expire or press `Ctrl+C` followed by `C` to accept before timeout. To roll back the change, press `Ctrl-C` followed by `A`, in which case the playbook run is aborted while the nodes have uncommitted confirms. After the specified `confirm_timeout`, the changes will roll back on the devices.

!!!note
    Using commit-confirm functionality of the playbook results in intent and configuration state on the nodes to be out-of-sync. You will need to update the intent and deploy again to bring the network into the desired state as defined by the intents.
    Also, the playbook run becomes interactive, which may not be desirable depending on how you use this playbook. When you run the playbook inside a _runner_ of a CI/CD pipeline, this is not desirable. Alternatively, you could rely on Git functionality, e.g. `git revert` to roll back your intents to a previous state.

### SROS devices

This playbook and the included roles provide limited support for SROS. This is especially useful if the Datacenter Gateway is an SROS device and you want to provide external connectivity to ip-vrf's configured in the fabric. It uses the same level-1 infra intents as with SR Linux and get transformed to device-specific configuration (netconf in case of SROS).

Further discussion on how to use this is out-of-scope of this tutorial. It may be part of a future update or a blog post that specifically focusses on SROS support.

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
