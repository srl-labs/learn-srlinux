---
comments: true
---

# Configuring the fabric

## Startup configuration

The initial configuration of the fabric nodes after setting up your environment, only contains the required statements to allow management connections to the nodes (SSH, gNMI, JSON-RPC). No further configuration is applied to the nodes.

If you have installed the [fcli](https://github.com/srl-labs/nornir-srl) tool, you can verify the initial state of the fabric with the following command that lists all the network-instances active on the fabric nodes. Alternatively, you can log into the nodes and verify the configuration manually. Only a single network instance `mgmt` should be present on each node.

=== "LLDP neighbors"
    ```bash
    ❯ fcli -t 4l2s.clab.yaml -i fabric=yes lldp-nbrs -f interface="eth*"
                                   LLDP Neighbors
                            Fields:{'interface': 'eth*'}
                            Inventory:{'fabric': 'yes'}
                   ╷               ╷            ╷               ╷
      Node         │ interface     │ Nbr-System │ Nbr-port      │ Nbr-port-desc  
     ══════════════╪═══════════════╪════════════╪═══════════════╪═══════════════
      clab-4l2s-l1 │ ethernet-1/48 │ s2         │ ethernet-1/1  │
                   │ ethernet-1/49 │ s1         │ ethernet-1/1  │
     ──────────────┼───────────────┼────────────┼───────────────┼───────────────
      clab-4l2s-l2 │ ethernet-1/48 │ s2         │ ethernet-1/2  │
                   │ ethernet-1/49 │ s1         │ ethernet-1/2  │
     ──────────────┼───────────────┼────────────┼───────────────┼───────────────
      clab-4l2s-l3 │ ethernet-1/48 │ s2         │ ethernet-1/3  │
                   │ ethernet-1/49 │ s1         │ ethernet-1/3  │
     ──────────────┼───────────────┼────────────┼───────────────┼───────────────
      clab-4l2s-l4 │ ethernet-1/48 │ s2         │ ethernet-1/4  │
                   │ ethernet-1/49 │ s1         │ ethernet-1/4  │
     ──────────────┼───────────────┼────────────┼───────────────┼───────────────
      clab-4l2s-s1 │ ethernet-1/1  │ l1         │ ethernet-1/49 │
                   │ ethernet-1/2  │ l2         │ ethernet-1/49 │
                   │ ethernet-1/3  │ l3         │ ethernet-1/49 │
                   │ ethernet-1/4  │ l4         │ ethernet-1/49 │
     ──────────────┼───────────────┼────────────┼───────────────┼───────────────
      clab-4l2s-s2 │ ethernet-1/1  │ l1         │ ethernet-1/48 │
                   │ ethernet-1/2  │ l2         │ ethernet-1/48 │
                   │ ethernet-1/3  │ l3         │ ethernet-1/48 │
                   │ ethernet-1/4  │ l4         │ ethernet-1/48 │
                   ╵               ╵            ╵               ╵
    ```
=== "Network instances and interfaces"
    ```bash
    ❯ fcli -t 4l2s.clab.yaml -i fabric=yes nwi-itfs
                                        Network-Instance Interfaces
                                        Inventory:{'fabric': 'yes'}
                   ╷      ╷      ╷        ╷           ╷         ╷         ╷                      ╷      ╷
      Node         │ ni   │ oper │ type   │ router-id │ Subitf  │ if-oper │ ipv4                 │ mtu  │ vlan  
     ══════════════╪══════╪══════╪════════╪═══════════╪═════════╪═════════╪══════════════════════╪══════╪══════
      clab-4l2s-l1 │ mgmt │ up   │ ip-vrf │           │ mgmt0.0 │ up      │ ['172.20.21.11/24']  │ 1500 │
     ──────────────┼──────┼──────┼────────┼───────────┼─────────┼─────────┼──────────────────────┼──────┼──────
      clab-4l2s-l2 │ mgmt │ up   │ ip-vrf │           │ mgmt0.0 │ up      │ ['172.20.21.12/24']  │ 1500 │
     ──────────────┼──────┼──────┼────────┼───────────┼─────────┼─────────┼──────────────────────┼──────┼──────
      clab-4l2s-l3 │ mgmt │ up   │ ip-vrf │           │ mgmt0.0 │ up      │ ['172.20.21.13/24']  │ 1500 │
     ──────────────┼──────┼──────┼────────┼───────────┼─────────┼─────────┼──────────────────────┼──────┼──────
      clab-4l2s-l4 │ mgmt │ up   │ ip-vrf │           │ mgmt0.0 │ up      │ ['172.20.21.14/24']  │ 1500 │
     ──────────────┼──────┼──────┼────────┼───────────┼─────────┼─────────┼──────────────────────┼──────┼──────
      clab-4l2s-s1 │ mgmt │ up   │ ip-vrf │           │ mgmt0.0 │ up      │ ['172.20.21.101/24'] │ 1500 │
     ──────────────┼──────┼──────┼────────┼───────────┼─────────┼─────────┼──────────────────────┼──────┼──────
      clab-4l2s-s2 │ mgmt │ up   │ ip-vrf │           │ mgmt0.0 │ up      │ ['172.20.21.102/24'] │ 1500 │
                   ╵      ╵      ╵        ╵           ╵         ╵         ╵                      ╵      ╵
    ```

## Configuring the underlay

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

## Configuring services

### Adding and modifying services

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

### Deleting services

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

### L3VPN services

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

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
