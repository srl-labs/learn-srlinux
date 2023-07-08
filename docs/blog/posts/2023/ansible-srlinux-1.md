---
date: 2023-07-06
tags:
  - sr linux
  - ansible
authors:
  - wdesmedt
---

# Managing an SR Linux fabric with Ansible

Ansible is today the _lingua franca_ for network engineers to automate the configuration of network devices. Due to its simplicity and low barrier to entry, it is a popular choice for network automation that provides for maintainable and reusable automation code within network teams.

Our intention with this post is to provide a practical example how you can use Ansible to manage configuration of an SR Linux fabric by leveraging the official [Ansible collection for SR Linux][collection-doc-link]. It is not an 'off-the-shelf' solution, but rather a starting point for your own automation efforts.

<!-- more -->

The approach we discuss here only partially covers the SR Linux configuration or data model. Only resources required to establish and maintain a functional fabric are covered. The solution could be extended to cover other aspects of the configuration or data model by employing similar techniques but this is left as an exercise for the reader.

The intent or desired state of the fabric in this solution is abstracting  the device-specific implementation. The abstraction level is always a trade-off between usability/consumability of the automation and feature coverage of the managed infrastructure: the higher the abstraction, the more user-friendly it becomes, but at the expense of feature coverage. The right abstraction level depends on your specific use cases and requirements.

## Setting up your environment
 
### Prerequisites

- You should have a basic understanding of SR Linux and its network constructs to understand what this project does. Things like mac-vrfs, network instances, sub-interfaces, etc. should be familiar to you. If not, we recommend you read the [SR Linux documentation](https://documentation.nokia.com/srlinux/).

- Make sure you are on a machine with Ansible installed. The Ansible version should be 2.9 or higher. We recommend you run Ansible from a Python virtual environment, for example:
  
      ```bash
      python3 -m venv .venv
      source .venv/bin/activate
      pip install ansible
      ```

- Ensure you have the latest version of [Containerlab](https://containerlab.srlinux.dev/) installed and are meeting the [requirements](https://containerlab.srlinux.dev/install/) to run it.
- Optionally, you can install the [fcli](https://github.com/srl-labs/nornir-srl) tool to interact with the SR Linux nodes from the command line. It generates reports in tabular format to verify things like configured services, interfaces, routes, etc. It is not required to run the demo, but it can be useful to verify the state of the fabric after running the playbook.



### Installing the Ansible collection

Install the SR Linux Ansible collection from [Ansible Galaxy](https://galaxy.ansible.com/) with the following command:

    ```bash
    ansible-galaxy collection install nokia.srlinux
    ```


### Clone the projecct repository

Clone the [ansible-srl-demo][ansible-srl-demo] repository. Following command will clone the repository to the current directory on your machine (in folder ansible-srl-demo):

    ```bash
    git clone https://github.com/wdesmedt/ansible-srl-demo.git
    cd ansible-srl-demo
    ```

The following sections assume you are in the ansible-srl-demo directory.




### Setting up your SR Linux lab environment

You need an SR Linux test topology to run the Ansible playbook and roles against. We will use [Containerlab](https://containerlab.srlinux.dev/) to create a lab environment with 6 SR Linux nodes: 4 leaf-nodes and 2 spine-nodes:

```bash
sudo containerlab deploy -t 4l2s.clab.yml -c
```

This will create a lab environment with 6 SR Linux nodes and a set of linux containers to act as hosts. Also, the `/etc/hosts` file on the host machine will be updated with the IP addresses of the SR Linux nodes. This will allow us to connect to the nodes with Ansible, that has a matching inventory file inside the `ansible-srl-demo` directory.

Verify that all containers are up and running:

```bash
sudo containerlab inspect -t 4l2s.clab.yml
```

## The Ansible Inventory

In this project, we use the native file-based Ansible inventory. It lists the hosts that are part of the fabric and groups them in a way that reflects the fabric topology. The inventory file is located in the `inv` directory and contains next to the inventory file `ansible-inventory.yml` also `host_vars` and `group_vars` directories that contain host- and group-specific variables. 

In this example, the `ansible-inventory.yml` defines 3 groups: `srl` for all SR Linux nodes, `spine` for the spine nodes and `leaf` for the leaf nodes. The `host_vars` directory contains a file for each host that defines host-specific variables. The `group_vars` directory contains a single file for the `srl` group to define Ansible-specific variables that are required for the JSON-RPC connection-plugin as well as some system-level configuration data.

## Running the playbook


The playbook can be run with the following command:



The code for this post can be found in the [ansible-srl-demo][ansible-srl-demo] repository.


We are eager to hear from you if you find any functionality missing or if you have any suggestions on how to improve the collection. Please leave comments below or [open an issue](https://github.com/nokia/srlinux-ansible-collection/issues) on GitHub.


## Available Ansible roles

### Approach

As explained in the [Ansible collection documentation][collection-doc-link], configuration of an SR Linux device is done by applying configuration to the different resources in the configuration or data model through the `config` module of the collection using 3 different operations: `update`, `delete` and `replace`. The `update` and `replace` arguments take a list of (path, value)-pairs that represent the configuration to be applied. The `delete` argument takes a list of paths that represent the configuration to be deleted. 

In this project, we took the approach to translate intents or desired-state from the variables associated with each role. These variables contain structured data and follow a model that is interpreted by the role's template to generate input for the `config` module. Only one role, the `common/configure` role, uses the `config` module directly. The other roles only generate the low-level intent, i.e. the input to the `config` module, from the higher-level intent stored in the role's variables and in the inventory.

The reasons for this approach are:

- avoid **dependencies** between resources and **sequencing** issues. Since SR Linux is a model-driven NOS, dependencies of resources, as described in the Yang modules are enforced by SR Linux. E.g. pushing configuration that adds sub-interfaces to a network instance that are not created beforehand, will result in a configuration error. By grouping all configuration statements together and call the config module only once, we avoid these issues. SR Linux will take care of the sequencing and apply changes in a single transaction.
- support for **resource pruning**. By building a full intent for managed resources, we know exactly the desired state the fabric should be in. Using the SR Linux node as configuration state store, we can compare the desired state with the actual configuration state of the node and prune any resources that are not part of the desired state. There is no need to flag such resources for deletion which is the typical approach with Ansible NetRes modules for other NOS's.
- support for **network audit**. The same playbook that is used to apply the desired state can be used to audit the network. By comparing the full desired state with the actual configuration state of the node, we can detect any drift and report it to the user. This is achieved by running the playbook in _dry-run_ or _check_ mode.
- keeping role-specific intent with the role itself, in the associated variables, results in separation of concerns and makes the playbook more readable and maintainable. It's like functions in a generic programming language: the role is the function and the variables are the arguments.

### Role structure

The SR Linux Ansible collection provides a set of Ansible roles to manage these resources. The roles are organized in a directory structure that reflects the configuration or data model. The roles are grouped in the following directories:

```bash
roles
├── common
│   ├── configure
│   ├── init
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


## Defining the intents

The next step is to define the intents. The intent is the desired state of the fabric. It is the configuration that we want to apply to the devices. The intent is defined in the playbook in the form of tasks. Each task is a separate intent. The tasks are executed in the order they are defined in the playbook.

## Running the playbook


[collection-doc-link]: ../../../ansible/collection/index.md
[ansible-srl-demo]: https://github.com/wdesmedt/ansible-srl-demo


