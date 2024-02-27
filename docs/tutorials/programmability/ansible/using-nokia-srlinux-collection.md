---
comments: true
title: Using nokia.srlinux Ansible collection
---
# Using `nokia.srlinux` Ansible collection

| Summary                     |                                                                                                                                             |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tutorial name**           | `nokia.srlinux` collection with Ansible                                                                                                     |
| **Lab components**          | 2 Nokia SR Linux nodes                                                                                                                      |
| **Resource requirements**   | :fontawesome-solid-microchip: 2 vCPU <br/>:fontawesome-solid-memory: 4 GB                                                                   |
| **Lab**                     | [jsonrpc-ansible][lab]                                                                                                                      |
| **Main ref documents**      | [JSON-RPC Configuration][json-cfg-guide], [JSON-RPC Management][json-mgmt-guide]<br/>[`nokia.srlinux` collection][nokia-srlinux-collection] |
| **Version information**[^1] | [`srlinux:23.3.1`][srlinux-container], [`containerlab:0.40.0`][clab-install], [`ansible-core:2.13`][ansible-install]                        |
| **Authors**                 | Roman Dodin [:material-twitter:][rd-twitter] [:material-linkedin:][rd-linkedin]                                                             |
| **Discussions**             | [:material-twitter: Twitter][twitter-share] · [:material-linkedin: LinkedIn][linkedin-share]                                                |

[rd-linkedin]: https://linkedin.com/in/rdodin
[rd-twitter]: https://twitter.com/ntdvps
[lab]: https://github.com/srl-labs/jsonrpc-ansible
[json-cfg-guide]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/Configuration_Basics_Guide/configb-mgmt_servers.html#ai9ep6mg7n
[json-mgmt-guide]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/SysMgmt_Guide/json-interface.html
[srlinux-container]: https://github.com/nokia/srlinux-container-image
[clab-install]: https://containerlab.dev/install/
[nokia-srlinux-collection]: ../../../ansible/collection/index.md
[ansible-install]: https://docs.ansible.com/ansible/6/installation_guide/index.html
[twitter-share]: https://twitter.com/ntdvps/status/1600920062214688768
[linkedin-share]: https://www.linkedin.com/feed/update/urn:li:activity:7006686238267039745/

[^1]: the following versions have been used to create this tutorial. The newer versions might work; please pin the version to the mentioned ones if they don't.

!!!note
    This is an updated tutorial that uses the new [`nokia.srlinux`][nokia-srlinux-collection] Ansible collection. The previous version of this tutorial that uses Ansible URI module is deprecated but still can be found [here](ansible-with-uri.md).

In the [JSON-RPC Basics](../json-rpc/basics.md) tutorial, we focused on the JSON-RPC interface mechanics and its capabilities. The examples we used there used a well-known `curl` command-line utility to put the focal point on the JSON-RPC itself and some automation framework.

Arguably, using `curl` for network automation tasks that aren't trivial may be challenging and likely lead to hairy bash scripting. Instead, network ops teams prefer to use home-grown automation that leverages programming languages or configuration management tools like Ansible[^2] fitted to the networking purpose.

!!!danger "Ansible for network automation?"
    We should mention that using Ansible for network automation might feel like a shortcut to automation nirvana with both infra and network domains automated via a single cfg management tool, but this might be a trap.

    From our experience using Ansible for network automation may work great when your automation tasks are trivial and do not require advanced configuration or state management. Programming in Ansible is tricky at best, and we advise you to consider using general-purpose languages instead (Python, Go, etc).

    Still, network teams who have experience with Ansible may work around its limitations and make the tool do the job without falling into a trap of troubleshooting playbooks, variable shadowing and jinja-programming.

The topic of this tutorial is exactly this - using Ansible and SR Linux's JSON-RPC interface to automate common network operations. This task-oriented tutorial will help you understand how Ansible can be used to perform day0+ operations on our magnificent Nokia SR Linux Network OS.

[^2]: Or home-grown automation tools leveraging some general purpose programming language.

## gNMI or JSON-RPC?

Ansible has been marketing itself as a framework [suitable for network automation](https://docs.ansible.com/ansible/latest/network/index.html). We've seen lots of network platforms integrated with Ansible using custom galaxy collections.  
There is no point in arguing if Ansible is the right tool of choice when network automation branches out as a separate netops discipline. If Ansible does the job for some netops teams, our task it to help them understand how it can be used with SR Linux.

At the time of this writing, SR Linux provides three management interfaces:

* gNMI
* JSON-RPC
* CLI

We've [discussed before](../json-rpc/basics.md) how these interfaces have the same visibility, but which one to pick for Ansible?

A few years back, Nokia open-sourced the [`nokia.grpc`][grpc-coll] galaxy collection to add [gNMI](https://github.com/openconfig/reference/blob/master/rpc/gnmi/gnmi-specification.md) support to Ansible. Unfortunately, due to the complications in the upstream python-grpcio library[^3], this plugin was not widely used in the context of Ansible. In addition to that limitation, Ansible host has to be provided with gRPC libraries as dependencies, which might be problematic for some users.  
Having said that, it is still possible to use this collection.

[grpc-coll]: https://galaxy.ansible.com/nokia/grpc
[^3]: The library does not allow to use unsecured gRPC transport nor it allows to skip certificate validation process.

## SR Linux collection

In contrast with gNMI, which requires a custom collection to operate, using HTTP API with Ansible is easy, and lots of Ansible's networking collections use that interface, and so do we.

We are pleased to have our [`nokia.srlinux`][nokia-srlinux-collection] collection published that empowers Ansible users to automate Nokia SR Linux-based fabrics.

The collection is available on [Ansible Galaxy](../../../ansible/collection/index.md#installation) and can be installed using the `ansible-galaxy` command. As part of the collection, we provide a set of Ansible modules that allow you to perform common network operations on SR Linux devices:

* `nokia.srlinux.config` - to configure the device in fully model-driven way.
* `nokia.srlinux.get` - to retrieve the device configuration and operational state.
* `nokia.srlinux.validate` - to validate changes before applying them to the device.
* `nokia.srlinux.cli` - to execute arbitrary CLI commands on the device.

## Lab deployment

If this is not your first tutorial on this site, you rightfully expect to get a [containerlab][clab-install][^1]-based lab provided so that you can follow along with the provided examples. The [lab][lab-file] uses Containerlab v0.51.3 and defines two Nokia SR Linux nodes connected over `ethernet-1/1` interfaces.

[lab-file]: https://github.com/srl-labs/jsonrpc-ansible/blob/main/lab.clab.yml

To deploy the lab, simply run:

```
sudo containerlab deploy -c -t https://github.com/srl-labs/jsonrpc-ansible
```

Shortly after you should have two SR Linux containers running:

```c title="Result of containerlab deploy command"
+---+----------------+--------------+--------------------------------+------+---------+----------------+----------------------+
| # |      Name      | Container ID |             Image              | Kind |  State  |  IPv4 Address  |     IPv6 Address     |
+---+----------------+--------------+--------------------------------+------+---------+----------------+----------------------+
| 1 | clab-2srl-srl1 | cc5ba5f8cc04 | ghcr.io/nokia/srlinux:23.10.2  | srl  | running | 172.20.20.3/24 | 2001:172:20:20::3/64 |
| 2 | clab-2srl-srl2 | aa5f8626ac4b | ghcr.io/nokia/srlinux:23.10.2  | srl  | running | 172.20.20.2/24 | 2001:172:20:20::2/64 |
+---+----------------+--------------+--------------------------------+------+---------+----------------+----------------------+
```

Finally change into the cloned directory - `cd jsonrpc-ansible` - and we are ready to start.

## Ansible setup

### Inventory

Ansible requires an [inventory][ansible-inventory] file to be present to identify the fleet of hosts it is going to operate on. Luckily, Containerlab automatically generates a suitable inventory file for us. You will find the auto-generated inventory file in the lab directory by the `./clab-2srl/ansible-inventory.yml` path.

It will look similar to this:

```yaml
all:
  vars:
    # The generated inventory is assumed to be used from the clab host.
    # Hence no http proxy should be used. Therefore we make sure the http
    # module does not attempt using any global http proxy.
    ansible_httpapi_use_proxy: false
  children:
    nokia_srlinux:
      vars:
        ansible_network_os: nokia.srlinux.srlinux
        # default connection type for nodes of this kind
        # feel free to override this in your inventory
        ansible_connection: ansible.netcommon.httpapi
        ansible_user: admin
        ansible_password: NokiaSrl1!
      hosts:
        clab-2srl-srl1:
          ansible_host: 172.20.20.3
        clab-2srl-srl2:
          ansible_host: 172.20.20.2
```

[ansible-inventory]: https://docs.ansible.com/ansible/latest//inventory_guide/

### Container

Ansible is infamous for breaking things when you least expect it. For that reason, we [caged](../../../ansible/collection/index.md#container-image) the beast.  
We [created a pipeline](https://github.com/nokia/srlinux-ansible-collection/blob/main/.github/workflows/container-build.yml) that builds container images for each release of our collection making sure that our users have one worry less during their automation journey.

Throughout this tutorial we will be using `ghcr.io/nokia/srlinux-ansible-collection/2.15.5/py3.11:v0.3.0` container image that as the url suggests is based on `ansible-core==2.15.5` with `python 3.11` running srlinux collection v0.3.0.

To save some finger energy we will create a handy alias `ansible-playbook` that runs our container image with the `ansible-inventory.yml` file being already loaded:

```bash title="ansible-in-a-container alias"
alias ansible-playbook='docker run --rm -it \
  -v $(pwd):/ansible \(1)
  -v ~/.ssh:/root/.ssh \(2)
  -v /etc/hosts:/etc/hosts \(3)
  ghcr.io/nokia/srlinux-ansible-collection/2.15.5/py3.11:v0.4.0 \
  ansible-playbook -i clab-2srl/ansible-inventory.yml $@'
```

1. `/ansible` is a working dir for our container image, so we mount the repo's directory to this path.
2. although not needed for this lab, we still mount ssh dir of the host to the container, in case we need key-based ssh access
3. to make sure that Ansible container can reach the nodes deployed by containerlab we mount the `/etc/hosts` file to it. That way ansible inside the container can resolve node names to IP addresses.

Now we can ensure that our alias works, just as if you had Ansible installed locally:

```bash
❯ ansible-playbook --version
ansible-playbook [core 2.15.5]
  config file = None
  configured module search path = ['/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/local/lib/python3.11/site-packages/ansible
  ansible collection location = /root/.ansible/collections:/usr/share/ansible/collections
  executable location = /usr/local/bin/ansible-playbook
  python version = 3.11.6 (main, Oct 11 2023, 23:23:39) [GCC 12.2.0] (/usr/local/bin/python)
  jinja version = 3.1.2
  libyaml = True
```

???note "setting up `iptables` for container networking"
    With Ansible running in a container connected to the default bridge network and the rest of the nodes running in the `clab` docker network users may experience communication problems between Ansible and network elements.  
    This stems from the default iptables rules Docker maintains preventing container communications between different networks. To overcome this, consider one of the following methods (one of them, not all):

    1. Install iptables rule to allow packets to `docker0` network:
       ```
       sudo iptables -I DOCKER-USER -o docker0 -j ACCEPT -m comment --comment "allow inter-network comms"
       ```
    2. Instruct containerlab to start nodes in the Docker [default network](https://containerlab.dev/manual/network/#default-docker-network).
    3. Run Ansible container in the network that containerlab uses (`clab` by default)

    Using this container image is not required for this tutorial, you still can install Ansible using any of the supported methods.

    With the container image, we tried to make sure you will have one problem less to worry about.

## Tasks

Once the [lab repository](#lab-deployment) is cloned and the lab is deployed, we are ready to start solving the tasks using `nokia.srlinux` Ansible collection.  

### Retrieving state and config

Beginning with the common task of retrieving state and configuration data from SR Linux using model-based paths.

Playbook [`task01/get-state-and-config-data.yml`](https://github.com/srl-labs/jsonrpc-ansible/blob/main/task01/get-state-and-config-data.yml):

```yaml
- name: Get state and config data from SR Linux
  hosts: all
  gather_facts: false
  tasks:
    - name: Get hostname, version and tls-profile
      nokia.srlinux.get:
        paths:
          - path: /system/name/host-name
          - path: /system/information/version
          - path: /system/json-rpc-server/network-instance[name=mgmt]/https/tls-profile
      register: get_result

    - ansible.builtin.debug:
        msg: "Host {{get_result.result[0]}} runs {{get_result.result[1]}} version and json-rpc server uses '{{get_result.result[2]}}' TLS profile"
```

In the `Get hostname, version and tls-profile` task we leverage the [`nokia.srlinux.get`](../../../ansible/collection/get.md) to fetch three parameters off of the SR Linux node.

Each path in the `paths` list uses an XPATH-like path notation that points to a YANG-modelled node. In this particular example, we retrieve the data from the `state` datastore, as this is the default value for the [datastore](../../../ansible/collection/get.md#datastore) parameter of the get module. Read more on datastores [here](../json-rpc/basics.md#datastore).

To execute the playbook:

```bash
ansible-playbook task01/get-state-and-config-data.yml
```

The result of the playbook will contain the message string per each lab node with the relevant information:

```
TASK [ansible.builtin.debug] ***********************************************************************************
ok: [clab-2srl-srl1] => {
    "msg": "Host srl1 runs v22.11.1-184-g6eeaa254f7 version and json-rpc server uses 'clab-profile' TLS profile"
}
ok: [clab-2srl-srl2] => {
    "msg": "Host srl2 runs v22.11.1-184-g6eeaa254f7 version and json-rpc server uses 'clab-profile' TLS profile"
}
```

The `debug` task shows how to access the data returned by the module. Read more on the returned data in the [get module documentation](../../../ansible/collection/get.md#return-values).

Of course, your paths might not necessarily point to a leaf; it can be a container, a list, or another YANG element. We used leaves in the example to demonstrate how to access the data in the response.

Based on the provided example, users can fetch any configuration or state data available in SR Linux.

### Configuration backup

Another bestseller task in the network operations category - configuration backup. In SR Linux, the running configuration is what populates the `running` datastore. We can easily fetch the entire `running` datastore by using the `/` path with the `get` module.

Playbook [`task02/cfg-backup.yml`](https://github.com/srl-labs/jsonrpc-ansible/blob/main/task02/cfg-backup.yml) demonstrates how this is done.

```yaml title="snip from the task02/cfg-backup.yml"
- name: Configuration backup
  hosts: all
  gather_facts: false
  tasks:
    - name: Backup running configuration
      nokia.srlinux.get:
        paths:
          - path: /
            datastore: running
      register: get_result
```

Once the whole running datastore is fetched we write (using the [copy module](https://docs.ansible.com/ansible/6/collections/ansible/builtin/copy_module.html)) it to the ansible host filesystem to the same directory where the playbook is located:

```yaml
- name: Save fetched configs
  ansible.builtin.copy:
    content: "{{get_result.result[0] | to_nice_json}}"
    dest: "{{playbook_dir}}/{{inventory_hostname}}.cfg.json"
```

As a result, running configs of the two nodes are written to the `task02` directory:

```bash
ansible-playbook task02/cfg-backup.yml
```

<div class="embed-result">
```
PLAY [Configuration backup] **************************************************************************************

TASK [Backup running configuration] ******************************************************************************
ok: [clab-2srl-srl1]
ok: [clab-2srl-srl2]

TASK [Save fetched configs] **************************************************************************************
changed: [clab-2srl-srl1]
changed: [clab-2srl-srl2]

PLAY RECAP *******************************************************************************************************
clab-2srl-srl1             : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
clab-2srl-srl2             : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

```
</div>

```bash
❯ ls task02
cfg-backup.yml  clab-2srl-srl1.cfg.json  clab-2srl-srl2.cfg.json
```

!!!note
    Alternative approach to do configuration backup is to transfer the config file that resides on the file system of the Network OS.

### Setting configuration

Configuration tasks are not the white crows either. Many Ansible operators provision their network devices using popular techniques such as configuration templating.

In `task03/config.yml` playbook, we switch to the [`config` module](../../../ansible/collection/config.md) and demonstrate several ways to source the configuration data.

The tasks' body highlights module's ability to stuff many configuration operations in a single request. In this case a replace operation is accompanied by two update operations.

```yaml
- name: Configuration
  hosts: all
  gather_facts: false
  tasks:
    - name: Various configuration tasks
      nokia.srlinux.config:
        replace:
          - path: /interface[name=mgmt0]/description
            value: "{{inventory_hostname}} management interface"
        update:
          - path: /system/information
            value:
              location: the Netherlands
              contact: Roman Dodin
          - path: /
            value: "{{lookup('ansible.builtin.template', '{{playbook_dir}}/iface-cfg.json.j2') }}"
      register: set_result
```

#### Value container

A most common way to provide configuration values is by writing them in the `value` parameter of an operation. Like in the case of the `update`'s first operation, we provide values for the `/system/information` container:

```yaml
- action: update
  path: /system/information
  value:
    location: the Netherlands
    contact: Roman Dodin
```

We set two leaves - `location` and `contact` - by creating the `value` container, which embeds leaves and values we want to set under the `/system/information` path.

#### Config sourced from a file

Quite often, configuration templates intended to be pushed to the node are saved on disk. Hence, we want to show how to use those templates in your configuration tasks.

The [`iface-cfg.json.j2`](https://github.com/srl-labs/jsonrpc-ansible/blob/main/task03/iface-cfg.json.j2) file contains a template for the two interfaces - `ethernet-1/1` and `lo0`. The `ethernet-1/1` interface is configured with a sub-interface and IP address sourced from the `{{e1_1_ip}}` variable and is attached to the default network instance.

```json
{
  "interface": [
    {
      "name": "ethernet-1/1",
      "description": "ethernet-1/1 interface on {{inventory_hostname}} node",
      "admin-state": "enable",
      "subinterface": [
        {
          "index": 0,
          "admin-state": "enable",
          "ipv4": {
            "address": [
              {
                "ip-prefix": "{{e1_1_ip}}"
              }
            ]
          }
        }
      ]
    },
    {
      "name": "lo0",
      "description": "loopback interface on {{inventory_hostname}} node",
      "admin-state": "enable"
    }
  ],
  "network-instance": [
    {
      "name": "default",
      "interface": [
        {
          "name": "ethernet-1/1.0"
        }
      ]
    }
  ]
}
```

But where do we define the `{{e1_1_ip}}` variable? We can define it in the inventory file by making a tight coupling between the target device and its variables. Edit the `clab-2srl/ansible-inventory.yml` file and add the `e1_1_ip` variable to the `clab-2srl-srl1` and `clab-2srl-srl2` hosts:

```yaml hl_lines="4 7"
      hosts:
        clab-2srl-srl1:
          ansible_host: 172.20.20.3
          e1_1_ip: 192.168.0.1/24
        clab-2srl-srl2:
          ansible_host: 172.20.20.2
          e1_1_ip: 192.168.0.2/24
```

Now with the variables defined and set for each host we can use them in the template

Since `/interface` list is a top-level element in our [YANG model](../../../yang/index.md) (as denoted by `/interface` path), to create a new member of this list, we craft a JSON object with `interface` list and specify its members (`ethernet-1/1` and `lo0`). This JSON object is then updates/merges the `/` path, thus making two new interfaces. Same with the `network-instance`.

```yaml
- action: update
  path: /
  value: "{{lookup('ansible.builtin.template', '{{playbook_dir}}/iface-cfg.json.j2') }}"
```

#### Results validation

Run the playbook with `ansible-playbook task03/config.yml`:

???note "Run output"
    ```
    ❯ ansible-playbook task03/config.yml

    PLAY [Configuration] ************************************************************************************************************************

    TASK [Various configuration tasks] **********************************************************************************************************
    ok: [clab-2srl-srl1]
    ok: [clab-2srl-srl2]

    TASK [Verify configuration set] *************************************************************************************************************
    ok: [clab-2srl-srl1]
    ok: [clab-2srl-srl2]

    TASK [ansible.builtin.debug] ****************************************************************************************************************
    ok: [clab-2srl-srl1] => {
        "msg": [
            "mgmt0 description is: clab-2srl-srl1 management interface",
            "location is: the Netherlands",
            "contact is: Roman Dodin",
            "ethernet-1/1 description is: ethernet-1/1 interface on clab-2srl-srl1 node",
            "loopback0 description is: loopback interface on clab-2srl-srl1 node"
        ]
    }
    ok: [clab-2srl-srl2] => {
        "msg": [
            "mgmt0 description is: clab-2srl-srl2 management interface",
            "location is: the Netherlands",
            "contact is: Roman Dodin",
            "ethernet-1/1 description is: ethernet-1/1 interface on clab-2srl-srl2 node",
            "loopback0 description is: loopback interface on clab-2srl-srl2 node"
        ]
    }

    PLAY RECAP **********************************************************************************************************************************
    clab-2srl-srl1             : ok=3    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0   
    clab-2srl-srl2             : ok=3    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
    ```

To ensure that the changes were correctly applied, the last task fetches state information for the touched leaves. Looking at the output, we can verify that the config was applied correctly.

Additionally, since we configured IP addresses over the connected interfaces on both nodes, you should be able to execute a ping between the nodes:

Login to `srl1`:

```bash
ssh clab-2srl-srl1
```

and run the ping command:

```bash
--{ + running }--[  ]--
A:srl1# ping -c 2 192.168.0.2 network-instance default
Using network instance default
PING 192.168.0.2 (192.168.0.2) 56(84) bytes of data.
64 bytes from 192.168.0.2: icmp_seq=1 ttl=64 time=59.3 ms
64 bytes from 192.168.0.2: icmp_seq=2 ttl=64 time=14.5 ms

--- 192.168.0.2 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 14.501/36.886/59.271/22.385 ms
```

### Replacing partial config

To replace a portion of a config a `replace` operation of the `config` module is used with the path pointing to the subtree to be replaced. The value of the `replace` operation is the new subtree to be replaced with.

In [`task04/replace-partial-cfg.yml`](https://github.com/srl-labs/jsonrpc-ansible/blob/main/task04/replace-partial-cfg.yml) playbook we replace everything that was configured in the previous [configuration task](#config-sourced-from-a-file) for `ethernet-1/1` interface with a container having a single leaf set - `admin-state: disable`.

```yaml
- name: Replace operation
  hosts: all
  gather_facts: false
  tasks:
    - name: Replace partial config
      nokia.srlinux.config:
        replace:
          - path: /interface[name=ethernet-1/1]
            value:
              name: ethernet-1/1
              admin-state: disable
        delete:
          - path: /network-instance[name=default]/interface[name=ethernet-1/1.0]
```

The replace action will delete everything under `/interface[name=ethernet-1/1]` and update it with the value specified in the request. We also remove the binding of the subinterface `ethernet-1/1.0` from the network instance, since the subinterface is going to be removed by the replace operation and we can't have it referenced in the network instance anymore.

Run the playbook with `ansible-playbook task04/replace-partial-cfg.yml`:

???note "Run output"
    ```
    ❯ ansible-playbook task04/replace-partial-cfg.yml

    PLAY [Replace operation] ********************************************************************************************************************

    TASK [Replace partial config] ***************************************************************************************************************
    ok: [clab-2srl-srl2]
    ok: [clab-2srl-srl1]

    TASK [Verify configuration set] *************************************************************************************************************
    ok: [clab-2srl-srl2]
    ok: [clab-2srl-srl1]

    TASK [ansible.builtin.debug] ****************************************************************************************************************
    ok: [clab-2srl-srl1] => {
        "get_result.json.result": [
            {
                "admin-state": "disable"
            }
        ]
    }
    ok: [clab-2srl-srl2] => {
        "get_result.json.result": [
            {
                "admin-state": "disable"
            }
        ]
    }

    PLAY RECAP **********************************************************************************************************************************
    clab-2srl-srl1             : ok=3    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0   
    clab-2srl-srl2             : ok=3    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
    ```

### Replacing entire config

One of the common tactics to provision a new box with services after it has been ZTP'd is to replace whatever is there with the golden or node-specific config.

In [`task05/replace-entire-cfg.yml`](https://github.com/srl-labs/jsonrpc-ansible/blob/main/task05/replace-entire-cfg.yml) we do just that. The [golden config](https://github.com/srl-labs/jsonrpc-ansible/blob/main/task05/golden.cfg.json.j2) that resides in the task directory has jinja variables that Ansible populates at runtime to add node-specific values. The golden config we used in this example is similar to what we retrieved in the [backup task](#configuration-backup).

```yaml
- name: Replace operation
  hosts: all
  gather_facts: false
  tasks:
    - name: Replace entire config
      nokia.srlinux.config:
        replace:
          - path: /
            value: "{{lookup('ansible.builtin.template', '{{playbook_dir}}/golden.cfg.json.j2') }}"
```

To replace the entire config we set the path to `/` value and provide the entire config in the value field.

Run the playbook with `ansible-playbook task05/replace-entire-cfg.yml`:

???note "Run output"
    ```
    ❯ ansible-playbook task05/replace-entire-cfg.yml

    PLAY [Replace operation] ********************************************************************************************************************

    TASK [Replace partial config] ***************************************************************************************************************
    ok: [clab-2srl-srl1]
    ok: [clab-2srl-srl2]

    TASK [Verify configuration set] *************************************************************************************************************
    ok: [clab-2srl-srl1]
    ok: [clab-2srl-srl2]

    TASK [ansible.builtin.debug] ****************************************************************************************************************
    ok: [clab-2srl-srl1] => {
        "msg": "Location from golden config: CONTAINERLAB"
    }
    ok: [clab-2srl-srl2] => {
        "msg": "Location from golden config: CONTAINERLAB"
    }

    PLAY RECAP **********************************************************************************************************************************
    clab-2srl-srl1             : ok=3    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0   
    clab-2srl-srl2             : ok=3    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
    ```

### Collecting `show` commands

Another golden record of the netops is to dump some operational `show` commands for audit, pre/post checks, etc. Using [`nokia.srlinux.cli`](../../../ansible/collection/cli.md) module we can execute `show` and other commands with output format being `json`, `text` or `table`.

In [`task06/fetch-show-cmd-output.yml`](https://github.com/srl-labs/jsonrpc-ansible/blob/main/task06/fetch-show-cmd-output.yml) we collect the output of a few `show` commands in text outputs and save them in per-node files.

```yaml
- name: Operational commands
  hosts: all
  gather_facts: false
  vars:
    commands:
      - show version
      - show platform chassis
  tasks:
    - name: Fetch show commands output
      nokia.srlinux.cli:
        commands: "{{commands}}"
        output_format: text
      register: cli_result
```

For this playbook we introduce playbook variable - `commands` - that host a list of show commands we would like to execute remotely.

To save the results of the executed commands we loop over the results array and save each result in its own file with a sanitized name:

```yaml
- name: Save fetched show outputs
  ansible.builtin.copy:
    content: "{{item}}"
    dest: '{{playbook_dir}}/{{inventory_hostname}}.{{ commands[idx] | replace(" ", "-") | regex_replace("[^A-Za-z0-9\-]", "") }}.txt'
  loop: "{{cli_result.result}}"
  loop_control:
    index_var: idx
```

Run the playbook with `ansible-playbook task06/fetch-show-cmd-output.yml`:

??? "Run output"

    ```
    ❯ ansible-playbook task06/fetch-show-cmd-output.yml

    PLAY [Operational commands] *****************************************************************************************************************

    TASK [Fetch show commands output] ***********************************************************************************************************
    ok: [clab-2srl-srl2]
    ok: [clab-2srl-srl1]

    TASK [Save fetched show outputs] ************************************************************************************************************
    changed: [clab-2srl-srl1] => (item=--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    Hostname             : srl1
    Chassis Type         : 7220 IXR-D2
    Part Number          : Sim Part No.
    Serial Number        : Sim Serial No.
    System HW MAC Address: 1A:C0:00:FF:00:00
    Software Version     : v22.11.1
    Build Number         : 184-g6eeaa254f7
    Architecture         : x86_64
    Last Booted          : 2022-12-08T13:55:46.394Z
    Total Memory         : 24052875 kB
    Free Memory          : 14955894 kB
    --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    )
    changed: [clab-2srl-srl2] => (item=--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    Hostname             : srl2
    Chassis Type         : 7220 IXR-D2
    Part Number          : Sim Part No.
    Serial Number        : Sim Serial No.
    System HW MAC Address: 1A:1E:01:FF:00:00
    Software Version     : v22.11.1
    Build Number         : 184-g6eeaa254f7
    Architecture         : x86_64
    Last Booted          : 2022-12-08T13:55:46.390Z
    Total Memory         : 24052875 kB
    Free Memory          : 14955894 kB
    --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    )
    ok: [clab-2srl-srl2] => (item=--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    Type             : 7220 IXR-D2
    Last Boot type   : normal
    HW MAC address   : 1A:1E:01:FF:00:00
    Slots            : 1
    Oper Status      : up
    Last booted      : 2022-12-08T13:55:46.390Z
    Last change      : 2022-12-08T13:55:46.390Z
    Part number      : Sim Part No.
    CLEI code        : Sim CLEI
    --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    )
    ok: [clab-2srl-srl1] => (item=--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    Type             : 7220 IXR-D2
    Last Boot type   : normal
    HW MAC address   : 1A:C0:00:FF:00:00
    Slots            : 1
    Oper Status      : up
    Last booted      : 2022-12-08T13:55:46.394Z
    Last change      : 2022-12-08T13:55:46.394Z
    Part number      : Sim Part No.
    CLEI code        : Sim CLEI
    --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    )

    PLAY RECAP **********************************************************************************************************************************
    clab-2srl-srl1             : ok=2    changed=1    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0   
    clab-2srl-srl2             : ok=2    changed=1    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
    ```

As a result of that run, you should get a file per the executed command per the node in your inventory:

```
❯ ls task06
clab-2srl-srl1.show-platform-chassis.txt  clab-2srl-srl2.show-platform-chassis.txt  fetch-show-cmd-output.yml
clab-2srl-srl1.show-version.txt           clab-2srl-srl2.show-version.txt

❯ cat task06/clab-2srl-srl1.show-version.txt 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Hostname             : srl1
Chassis Type         : 7220 IXR-D2
Part Number          : Sim Part No.
Serial Number        : Sim Serial No.
System HW MAC Address: 1A:C0:00:FF:00:00
Software Version     : v22.11.1
Build Number         : 184-g6eeaa254f7
Architecture         : x86_64
Last Booted          : 2022-12-08T13:55:46.394Z
Total Memory         : 24052875 kB
Free Memory          : 14955894 kB
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
```

## HTTPS

All the examples in this tutorial were using HTTP as a transport protocol. However, in production environments, you would want to use HTTPS to secure your communication with the network devices.

Using HTTPS with this collection is as simple as adding the `ansible_httpapi_use_ssl: true` and `ansible_httpapi_validate_certs: false` variable. For instance, to the list of variables in the inventory file:

```yaml hl_lines="7 8"
all:
  vars:
    ansible_connection: ansible.netcommon.httpapi
    ansible_user: admin
    ansible_password: NokiaSrl1!
    ansible_network_os: nokia.srlinux.srlinux
    ansible_httpapi_use_ssl: true
    ansible_httpapi_validate_certs: false
  hosts:
    # snip
```

To see other options of TLS-secured connections, see the [TLS section](../../../ansible/collection/index.md#tls) of the module's docs.

## Summary

While Ansible may not be the best tool for the network automation job due to complicated troubleshooting, weird looping mechanisms, and challenging ways to manipulate and extract modelled data - it is still being used by many teams.

Our mission was to demonstrate how Ansible can be used in conjunction with SR Linux Network OS and which interface to choose - [gNMI or JSON-RPC](#gnmi-or-json-rpc)? Then, through a set of task-oriented exercises, we showed how modules in [`nokia.srlinux`](../../../ansible/collection/index.md) collection can help you reach your automation goals with Ansible.

Do you want us to cover more tasks using Ansible, or any other automation stack? Do let us know in the comments!
