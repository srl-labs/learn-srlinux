---
date: 2023-07-27
tags:
  - gnmi
  - pygnmi
  - evpn
authors:
  - mau
---

# Finding misconfigurations in your fabric using pyGNMI

<small>:material-github: [Git Repo](https://github.com/cloud-native-everything/pygnmi-srl-nanog88)</small>

Today, I'm sharing another piece of my experience from the [NANOG88](https://www.nanog.org/events/nanog-88/) conference where I had the privilege of presenting a tutorial featuring pyGNMI, a powerful tool for diagnosing network issues. During my talk, I used [pyGNMI](https://github.com/akarneliuk/pygnmi) to visualize EVPN Layer2 and Layer 3 domains, sorting them by switch or network instance. I also added a special feature that detects discrepancies in the settings between different switches using the same EVPN domain – a great way to catch typos in your BGP/VXLAN settings.

!!!note
    The script demonstrates how to use pyGNMI to retrieve BGP EVPN information from a list of routers. It then formats the data for easy viewing.  
    For real world use cases, you would likely wrap pyGNMI with Nornir and leverage Nornir's inventory and task management capabilities, like shown [here](https://github.com/srl-labs/nornir-srl).

For this demonstration, I leveraged [containerlab](https://containerlab.dev) and [Nokia SR Linux](https://learn.srlinux.dev) to build a VXLAN-EVPN Fabric, replicating a typical configuration I often use in my Kubernetes labs. I incorporated eBGP for underlay communication, and the topology I utilized comprised two spines, two leaf switches, and a border leaf.

In this blog post we are going to dive into the details of the script, discovering how it works and what it is capable of. If you want to try it out yourself, you can find the source code in the [pygnmi-srl-nanog88 repo](https://github.com/cloud-native-everything/pygnmi-srl-nanog88)

<!-- more -->

## Setup

This script installs and starts Docker, a containerization platform, on a Linux machine using the dnf package manager. Then, it installs containerlab, a tool used for creating and managing container-based network labs

```bash
# Install docker
sudo dnf -y install docker
sudo systemctl start docker
sudo systemctl enable docker

# Install containerlab
bash -c "$(curl -sL https://get.containerlab.dev)"
```

Then, create your own virtual env for python and install the [requirements](https://github.com/cloud-native-everything/pygnmi-srl-nanog88/blob/main/py-scripts/requirements.txt).

And finally, start the lab with the topology file in the repo: `clab deploy -t topo.yml`

## How this app works

This application connects to a list of specified routers via the gNMI protocol, retrieving BGP EVPN and BGP VPN information, which is then formatted for easy viewing using Python modules like tabulate and Prettytable.

The heart of the application is the `SrlDevice` class, representing a router. The class is initialized with the router's basic details and employs the gNMI client to extract BGP EVPN and BGP VPN data. The app creates a list of these SrlDevice instances based on a YAML configuration file ('[datacenter-nodes.yml](https://github.com/cloud-native-everything/pygnmi-srl-nanog88/blob/main/py-scripts/datacenter-nodes.yml)'), resulting in two tables sorted by router name and network instance.

Running the python script `display_evpn_per_netinst.py` with the YAML configuration file generates an output like the one shown below:

```bash
[root@rbc-r2-hpe4 py-scripts]# python3 display_evpn_per_netinst.py datacenter-nodes.yml
Table: Sorted by Network Instance
+-----------------------+------------------+----+------------------+-----------------+------+------+------------+--------------+-------------------+-------------------+
|        Router         | Network instance | ID | EVPN Admin state | VXLAN interface | EVI  | ECMP | Oper state |      RD      |     import-rt     |     export-rt     |
+-----------------------+------------------+----+------------------+-----------------+------+------+------------+--------------+-------------------+-------------------+
| clab-dc-k8s-LEAF-DC-1 |    kube-ipvrf    | 1  |      enable      |    vxlan1.4     |  4   |  4   |     up     |  1.1.1.1:4   |  target:65123:4   |  target:65123:4   |
| clab-dc-k8s-LEAF-DC-2 |    kube-ipvrf    | 1  |      enable      |    vxlan1.4     |  4   |  4   |     up     |  1.1.1.2:4   |  target:65123:4   |  target:65123:4   |
| clab-dc-k8s-BORDER-DC |    kube-ipvrf    | 1  |      enable      |    vxlan1.4     |  4   |  4   |     up     |  1.1.1.10:4  |  target:65123:4   |  target:65123:4   |
| clab-dc-k8s-LEAF-DC-1 |   kube_macvrf    | 1  |      enable      |    vxlan1.1     |  1   |  1   |     up     |  1.1.1.1:1   |  target:65123:1   |  target:65123:1   |
| clab-dc-k8s-LEAF-DC-2 |   kube_macvrf    | 1  |      enable      |    vxlan1.1     |  1   |  1   |     up     |  1.1.1.2:1   |  target:65123:1   |  target:65123:1   |
| clab-dc-k8s-LEAF-DC-1 |    l2evpn1001    | 2  |      enable      |   vxlan2.1001   | 1001 |  1   |     up     | 1.1.1.1:1001 | target:65123:1001 | target:65123:1001 |
| clab-dc-k8s-LEAF-DC-2 |    l2evpn1001    | 2  |      enable      |   vxlan2.1001   | 1001 |  1   |     up     | 1.1.1.2:1001 | target:65123:1001 | target:65123:1001 |
| clab-dc-k8s-LEAF-DC-1 |    l2evpn1002    | 2  |      enable      |   vxlan2.1002   | 1002 |  1   |     up     | 1.1.1.1:1002 | target:65123:1002 | target:65123:1002 |
| clab-dc-k8s-LEAF-DC-2 |    l2evpn1002    | 2  |      enable      |   vxlan2.1002   | 1002 |  1   |     up     | 1.1.1.2:1002 | target:65123:1002 | target:65123:1002 |
| clab-dc-k8s-LEAF-DC-1 |    l2evpn1003    | 2  |      enable      |   vxlan2.1003   | 1003 |  1   |     up     | 1.1.1.1:1003 | target:65123:1003 | target:65123:1003 |
| clab-dc-k8s-LEAF-DC-2 |    l2evpn1003    | 2  |      enable      |   vxlan2.1003   | 1003 |  1   |     up     | 1.1.1.2:1013 | target:65123:1013 | target:65123:1013 |
| clab-dc-k8s-LEAF-DC-1 |    l2evpn1004    | 2  |      enable      |   vxlan2.1004   | 1004 |  1   |     up     | 1.1.1.1:1004 | target:65123:1004 | target:65123:1004 |
| clab-dc-k8s-LEAF-DC-2 |    l2evpn1004    | 2  |      enable      |   vxlan2.1004   | 1004 |  1   |     up     | 1.1.1.2:1004 | target:65123:1004 | target:65123:1004 |
| clab-dc-k8s-LEAF-DC-1 |    l2evpn1005    | 2  |      enable      |   vxlan2.1005   | 1005 |  1   |     up     | 1.1.1.1:1005 | target:65123:1005 | target:65123:1005 |
| clab-dc-k8s-LEAF-DC-2 |    l2evpn1005    | 2  |      enable      |   vxlan2.1005   | 1005 |  1   |     up     | 1.1.1.2:1005 | target:65123:1005 | target:65123:1005 |
| clab-dc-k8s-LEAF-DC-1 |    l2evpn1006    | 2  |      enable      |   vxlan2.1006   | 1006 |  1   |     up     | 1.1.1.1:1006 | target:65123:1006 | target:65123:1006 |
| clab-dc-k8s-LEAF-DC-2 |    l2evpn1006    | 2  |      enable      |   vxlan2.1006   | 1006 |  1   |     up     | 1.1.1.2:1006 | target:65123:1006 | target:65123:1006 |
| clab-dc-k8s-LEAF-DC-1 |      l3evpn      | 1  |      enable      |    vxlan1.2     |  2   |  4   |     up     |  1.1.1.1:2   |  target:65123:2   |  target:65123:2   |
| clab-dc-k8s-LEAF-DC-2 |      l3evpn      | 1  |      enable      |    vxlan1.2     |  2   |  4   |     up     |  1.1.1.2:2   |  target:65123:2   |  target:65123:2   |
+-----------------------+------------------+----+------------------+-----------------+------+------+------------+--------------+-------------------+-------------------+
Total time: 1.42 seconds
```

Now, if you have a typo in the EVI number, then the script will show you that:
![EVPN configuration typo](https://github.com/cloud-native-everything/pygnmi-srl-nanog88/blob/4a8046a239eabf1613cb2d8b204d83b3509fd4c8/py-scripts/images/Highligthed-Typo-EVPN-Fabric-Configuration.png?raw=true){.img-shadow}

## How to use it

To use the python class, you'll need to install some modules, including tabulate and pygnmi.
Use this [requirements.txt](https://github.com/cloud-native-everything/pygnmi-srl-nanog88/blob/main/py-scripts/requirements.txt) file in the repo.

```python
from SrlEvpn import SrlDevice
from SrlEvpn import MergeEvpnToArray
from SrlEvpn import HighlightAlternateGroups
```

We're using the yaml module to import data for the app. Once you've imported the data, you can call the class as follows:

```python
    srl_devices = []
    for router in routers:
        srl_devices.append(SrlDevice(router, port, DEFAULT_MODEL, DEFAULT_RELEASE, username, password, skip_verify))

    rows = MergeEvpnToArray(srl_devices)
```

As the data is located in different places (VXLAN info and EVPN/iBGP info), we use the MergeEvpnToArray method to consolidate it.

Finally, you can print the table by using this snippet:

```python
    sorted_rows = sorted(rows, key=lambda x: x[1])
    print("Table: Sorted by Network Instance")          
    highlighted_rows = HighlightAlternateGroups(sorted_rows, 5)  # Assuming Network Instance is the 1st column (0-indexed)
    table = tabulate(highlighted_rows, headers=['Router', 'Network instance', 'ID', 'EVPN Admin state', 
                                                'VXLAN interface', 'EVI', 'ECMP', 'Oper state', 
                                                'RD', 'import-rt', 'export-rt'], tablefmt="pretty")
    print(table)
```

This will highlight any typos – in our case, it will flag any errors in the EVI.
You can see the presentation in a previous post [right here](nanog88-srlinux-pygnmi-gnmic-chatgpt.md).
Catch you next time.
