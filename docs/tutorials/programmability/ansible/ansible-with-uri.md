---
comments: true
title: Using Ansible's URI module with SR Linux's JSON-RPC Interface
---

# Using Ansible's URI module with SR Linux's JSON-RPC Interface

!!!warning
    This is an original tutorial that predate `nokia.srlinux` collection. It uses Ansible's `uri` module to interact with SR Linux's JSON-RPC interface. It is recommended to use `nokia.srlinux` collection instead.

    A new version of this tutorial is available [here](using-nokia-srlinux-collection.md).

| Summary                     |                                                                                                                            |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| **Tutorial name**           | JSON-RPC with Ansible                                                                                                      |
| **Lab components**          | 2 Nokia SR Linux nodes                                                                                                     |
| **Resource requirements**   | :fontawesome-solid-microchip: 2 vCPU <br/>:fontawesome-solid-memory: 4 GB                                                  |
| **Lab**                     | [jsonrpc-ansible][lab]                                                                                                     |
| **Main ref documents**      | [JSON-RPC Configuration][json-cfg-guide], [JSON-RPC Management][json-mgmt-guide]<br/>[Ansible URI module][ansible-uri-doc] |
| **Version information**[^1] | [`srlinux:22.11.1`][srlinux-container], [`containerlab:0.33.0`][clab-install], [`ansible:v6.6`][ansible-install]           |
| **Authors**                 | Roman Dodin [:material-twitter:][rd-twitter] [:material-linkedin:][rd-linkedin]                                            |
| **Discussions**             | [:material-twitter: Twitter][twitter-share] · [:material-linkedin: LinkedIn][linkedin-share]                               |

[rd-linkedin]: https://linkedin.com/in/rdodin
[rd-twitter]: https://twitter.com/ntdvps
[lab]: https://github.com/srl-labs/jsonrpc-ansible
[json-cfg-guide]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/Configuration_Basics_Guide/configb-mgmt_servers.html#ai9ep6mg7n
[json-mgmt-guide]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/SysMgmt_Guide/json-interface.html
[srlinux-container]: https://github.com/nokia/srlinux-container-image
[clab-install]: https://containerlab.dev/install/
[ansible-uri-doc]: https://docs.ansible.com/ansible/6/collections/ansible/builtin/uri_module.html
[ansible-install]: https://docs.ansible.com/ansible/6/installation_guide/index.html
[twitter-share]: https://twitter.com/ntdvps/status/1600920062214688768
[linkedin-share]: https://www.linkedin.com/feed/update/urn:li:activity:7006686238267039745/

[^1]: the following versions have been used to create this tutorial. The newer versions might work; please pin the version to the mentioned ones if they don't.

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
There is no point in arguing if Ansible is the right tool of choice when network automation branches out as a separate netops discipline. If Ansible does the job for certain netops teams, our task it to help them understand how it can be used with SR Linux.

At the time of this writing, SR Linux provides three management interfaces:

* gNMI
* JSON-RPC
* CLI

We've [discussed before](../json-rpc/basics.md) how these interfaces have the same visibility, but which one to pick for Ansible?

A few years back, Nokia open-sourced the [`nokia.grpc`][grpc-coll] galaxy collection to add [gNMI](https://github.com/openconfig/reference/blob/master/rpc/gnmi/gnmi-specification.md) support to Ansible. Unfortunately, due to the complications in the upstream python-grpcio library[^3], this plugin was not widely used in the context of Ansible. In addition to that limitation, Ansible host has to be provided with gRPC libraries as dependencies, which might be problematic for some users.  
Having said that, it is still possible to use this collection.

[grpc-coll]: https://galaxy.ansible.com/nokia/grpc
[^3]: The library does not allow to use unsecured gRPC transport nor it allows to skip certificate validation process.

In contrast with gNMI, which requires a custom collection to operate, using JSON-RPC with Ansible is easy; the HTTP client is part of the Ansible core [URI module][ansible-uri-doc] and both secured and unsecured transports are possible. Also bear in mind, that the performance that gNMI offers is not of critical importance for Ansible-based network automation stacks. Add to the mix JSON-RPC's ability to call out CLI commands via reliable HTTP transport and it makes it easy to converge on this interface as far as Ansible is concerned.

## Lab deployment

If this is not your first tutorial on this site, you rightfully expect to get a [containerlab][clab-install]-based lab provided so that you can follow along with the provided examples. The [lab][lab-file] defines two Nokia SR Linux nodes connected over `ethernet-1/1` interfaces.

[lab-file]: https://github.com/srl-labs/jsonrpc-ansible/blob/main/lab.clab.yml

To deploy the lab clone the [repository][lab] and do `containerlab deploy` from within the repository's directory. Shortly after you should have two SR Linux containers running:

```c title="Result of containerlab deploy command"
+---+----------------+--------------+-------------------------------+------+---------+----------------+----------------------+
| # |      Name      | Container ID |             Image             | Kind |  State  |  IPv4 Address  |     IPv6 Address     |
+---+----------------+--------------+-------------------------------+------+---------+----------------+----------------------+
| 1 | clab-2srl-srl1 | cc5ba5f8cc04 | ghcr.io/nokia/srlinux:22.11.1 | srl  | running | 172.20.20.3/24 | 2001:172:20:20::3/64 |
| 2 | clab-2srl-srl2 | aa5f8626ac4b | ghcr.io/nokia/srlinux:22.11.1 | srl  | running | 172.20.20.2/24 | 2001:172:20:20::2/64 |
+---+----------------+--------------+-------------------------------+------+---------+----------------+----------------------+
```

## Ansible setup

### Inventory

The reason our lab has two nodes is to leverage Ansible's [inventory][ansible-inventory]. The two nodes that are deployed by containerlab fit nicely in the simplest inventory ever. We use the names of the containers as containeralb reports back to us and shovel them in the YAML format of the inventory:

```yaml title="inventory.yml file"
all:
  hosts:
    clab-2srl-srl1:
      e1_1_ip: 192.168.0.1/24
    clab-2srl-srl2:
      e1_1_ip: 192.168.0.2/24
```

[ansible-inventory]: https://docs.ansible.com/ansible/latest//inventory_guide/

We put a variable `e1_1_ip` for each host, as later we would like to use the values of these variables in the configuration tasks.

### Container

Ansible is infamous for breaking things when you least expect it. For that reason we put that beast in a [container cage](https://github.com/hellt/ansible-docker/pkgs/container/ansible).

We built a container image with Ansible v6.6.0 and are going to use it throughout this tutorial via a runner script `ansible.sh` that simply calls a `docker run` command with a few args:

```bash title="ansible-in-a-container runner script"
docker run --rm -it \
  -v $(pwd):/ansible \ #(1)!
  -v ~/.ssh:/root/.ssh \ #(2)!
  -v /etc/hosts:/etc/hosts \ #(3)!
  ghcr.io/hellt/ansible:6.6.0 ansible-playbook -i inventory.yml $@
```

1. `/ansible` is a working dir for our container image, so we mount the repo's directory to this path.
2. although not needed for this lab, we still mount ssh dir of the host to the container, in case we need key-based ssh access
3. to make sure that Ansible container can reach the nodes deployed by containerlab we mount the `/etc/hosts` file to it. That way ansible inside the container can resolve node names to IP addresses.

!!!note
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

### URI module

One of the biggest advantages of JSON-RPC interface is that it uses HTTP1.1 transport that every automation platform or programming language has native support for. In Ansible, the HTTP client is implemented with the builtin [URI module][ansible-uri-doc].  
We will solely use this core module of Ansible to interact with SR Linux's JSON-RPC interface.

Here is an example of a playbook with a single play utilizing this module could look like.

```yaml
- name: Get state data from SR Linux
  hosts: all
  connection: local
  gather_facts: no
  tasks:
    - name: Get hostname and version
      ansible.builtin.uri: #(1)!
        url: http://{{inventory_hostname}}/jsonrpc #(2)!
        url_username: admin #(3)!
        url_password: NokiaSrl1!
        method: POST
        body: #(4)!
          jsonrpc: "2.0"
          id: 1
          method: get
          params:
            datastore: state
            commands: #(5)!
              - path: /system/name/host-name
              - path: /system/information/version
              - path: /system/json-rpc-server/network-instance[name=mgmt]/https/tls-profile
                datastore: running
        body_format: json #(6)!
      register: get_result #(7)!

    - ansible.builtin.debug: #(8)!
        msg: "Host {{get_result.json.result[0]}} runs {{get_result.json.result[1]}} version"
```

1. Fully qualified module name
2. URL to use. See [basics tutorial](../json-rpc/basics.md#configuring-json-rpc).
3. Credentials for [user authentication](../json-rpc/basics.md#authentication).
4. Body of the request as per [basics tutorial](../json-rpc/basics.md#requestresponse-structure).
5. Commands to use in the RPC. See [basics tutorial](../json-rpc/basics.md#get) for additional information.
6. `body_format=json` will encode the body data structure to json string.
7. Registering the result will make it possible to extract the results of the RPC in the subsequent tasks.
8. In case of a successful RPC invocation, the resulting data structure will contain `json` key which provides access to the [`results` list](../json-rpc/basics.md#__tabbed_4_2).

## Tasks

Once the lab repository is cloned and the lab is deployed, we are ready to start solving the tasks using Ansible and JSON-RPC.  
Note, that the tasks will be solved straightforwardly without using clever Ansible features; the goal of this tutorial is to understand how to leverage JSON-RPC interface of SR Linux, and not how to effectively use Ansible in general.

### Retrieving state and config

Beginning with the common task of retrieving state and configuration data from SR Linux using model-based paths.

Playbook [`task01/get-state-and-config-data.yml`](https://github.com/srl-labs/jsonrpc-ansible/blob/main/task01/get-state-and-config-data.yml):

```yaml
- name: Get state and config data from SR Linux
  hosts: all
  connection: local
  gather_facts: no
  tasks:
    - name: Get hostname, version and tls-profile
      ansible.builtin.uri:
        url: http://{{inventory_hostname}}/jsonrpc
        url_username: admin
        url_password: NokiaSrl1!
        method: POST
        body:
          jsonrpc: "2.0"
          id: 1
          method: get
          params:
            datastore: state
            commands:
              - path: /system/name/host-name
              - path: /system/information/version
              - path: /system/json-rpc-server/network-instance[name=mgmt]/https/tls-profile
                datastore: running
        body_format: json
      register: get_result

    - ansible.builtin.debug:
        msg: "Host {{get_result.json.result[0]}} runs {{get_result.json.result[1]}} version and json-rpc server uses '{{get_result.json.result[2]}}' TLS profile"
```

In the `Get hostname, version and tls-profile` task we craft the body payload with multiple commands, each of which is targeting a certain leaf. Note, how we provided `state` datastore on the global level and override it in the 3rd command where we needed to use `running` datastore. Read more on datastores [here](../json-rpc/basics.md#datastore).

To execute the playbook:

```bash
./ansible.sh task01/get-state-and-config-data.yml
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

Of course, your paths might not necessarily point to a leaf, it can be a conatiner, a list, or other YANG element. We used leaves in the example to demonstrate how to access the data in the response.

Based on the provided example, users can fetch any configuration or state data available in SR Linux.

### Configuration backup

Another bestseller task in the network operations category - configuration backup. In SR Linux, the running configuration is what populates the `running` datastore. We can easily fetch the entire `running` datastore by using the `/` path and the Get method of JSON-RPC.

Playbook [`task02/cfg-backup.yml`](https://github.com/srl-labs/jsonrpc-ansible/blob/main/task02/cfg-backup.yml) demonstrates how this is can be done.

```yaml title="snip from the task02/cfg-backup.yml"
body:
    jsonrpc: "2.0"
    id: 1
    method: get
    params:
    datastore: running
    commands:
        - path: /
```

Once the whole running datastore is fetched we write (using the [copy module](https://docs.ansible.com/ansible/6/collections/ansible/builtin/copy_module.html)) it to the ansible host filesystem to the same directory where the playbook is located:

```yaml
- name: Save fetched configs
    ansible.builtin.copy:
    content: "{{get_result.json.result[0] | to_nice_json}}"
    dest: "{{playbook_dir}}/{{inventory_hostname}}.cfg.json"
```

As a result, running configs of the two nodes are written to the `task02` directory:

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

```bash
❯ ls task02
cfg-backup.yml  clab-2srl-srl1.cfg.json  clab-2srl-srl2.cfg.json
```

!!!note
    Alternative approach to do configuration backup is to transfer the config file that resides on the file system of the Network OS.

### Setting configuration

Configuration tasks are not the white crows either. Many Ansible operators provision their network devices using popular techniques such as configuration templating.

In [`task03/config.yml`](https://github.com/srl-labs/jsonrpc-ansible/blob/main/task03/config.yml) playbook we switch to the JSON-RPC's [Set method](../json-rpc/basics.md#set) and demonstrate different sourcing of configuration data.

The body of our request contains three different commands which demonstrate various ways of changing the configuration on the device.

```yaml
body:
  jsonrpc: "2.0"
  id: 1
  method: set
  params:
    commands:
      - action: replace
        path: /interface[name=mgmt0]/description:{{inventory_hostname}} management interface
      - action: update
        path: /system/information
        value:
          location: the Netherlands
          contact: Roman Dodin
      - action: update
        path: /
        value: "{{lookup('ansible.builtin.template', '{{playbook_dir}}/iface-cfg.json.j2') }}"
body_format: json
```

#### Path-embedded value

The first command:

```yaml
- action: replace
  path: /interface[name=mgmt0]/description:{{inventory_hostname}} management interface
```

is a [`replace` action](../json-rpc/basics.md#replace) that embeds the value of the leaf we set in the `path` field. Note, that templating can be used throughout the playbook, which we leverage to customize the description value.

This is the most simple way of setting the configuration for a given leaf.

#### Value container

A little bit more interesting case is shown with the 2nd command, which updates several fields under `/system/information` container:

```yaml
- action: update
  path: /system/information
  value:
    location: the Netherlands
    contact: Roman Dodin
```

We set two leaves - `location` and `contact` - by creating the `value` container which embeds leaves and values we want to set under the `/system/information` path.

#### Config sourced from a file

Quite often, configuration templates that are intended to be pushed to the node are saved on disk. Hence, we would like to show how to use those tempaltes and configure SR Linux.

The [`iface-cfg.json.j2`](https://github.com/srl-labs/jsonrpc-ansible/blob/main/task03/iface-cfg.json.j2) file contains a template for two interfaces - `ethernet-1/1` and `lo0`. The `ethernet-1/1` interface is configured with a sub-interface and IP address sourced from the variable we put in the [inventory](#inventory) and is attached to the default network instance.

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

Since `/interface` list is a top-level element in our YANG model (as denoted by `/interface` path), to create a new member of this list, we craft a JSON object with `interface` list and specify its members (`ethernet-1/1` and `lo0`). This JSON object is then updates/merges the `/` path, thus making two new interfaces. Same with the `network-instance`.

```yaml
- action: update
  path: /
  value: "{{lookup('ansible.builtin.template', '{{playbook_dir}}/iface-cfg.json.j2') }}"
```

#### Error handling

To catch [potential errors](../json-rpc/basics.md#error-handling) that might happen during config provisioning a task that fails when error is returned by JSON-RPC is part of the playbook.

```yaml
- name: Stop if request contains error
  ansible.builtin.fail:
    msg: "Error: {{set_result.json.error.message}}"
  when: set_result.json.error is defined
```

#### Results validation

Run the playbook with `./ansible.sh task03/config.yml`:

???note "Run output"
    ```
    ❯ ./ansible.sh task03/config.yml

    PLAY [Configuration] ************************************************************************************************************************

    TASK [Various configuration tasks] **********************************************************************************************************
    ok: [clab-2srl-srl1]
    ok: [clab-2srl-srl2]

    TASK [Stop if request contains error] *******************************************************************************************************
    skipping: [clab-2srl-srl1]
    skipping: [clab-2srl-srl2]

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

To ensure that the changes were applied properly the last task fetches state information for the leaves that were touched. Looking at the output we can verify that the config was set correctly.

Additionally, since we configured IP addresses over the connected interfaces on both nodes, you should be able to execute a ping between the nodes:

```bash
--{ + running }--[  ]--
A:srl1# ping 192.168.0.2 network-instance default  
Using network instance default
PING 192.168.0.2 (192.168.0.2) 56(84) bytes of data.
64 bytes from 192.168.0.2: icmp_seq=1 ttl=64 time=90.3 ms
64 bytes from 192.168.0.2: icmp_seq=2 ttl=64 time=12.6 ms
```

### Replacing partial config

To replace portions of a config a [Set method with `replace` operation](../json-rpc/basics.md#replace) is used.

In [`task04/replace-partial-cfg.yml`](https://github.com/srl-labs/jsonrpc-ansible/blob/main/task04/replace-partial-cfg.yml) playbook we replace everything that was configured in the [configuration task](#config-sourced-from-a-file) with a single leaf `admin-state: disable`.

```yaml
body:
  jsonrpc: "2.0"
  id: 1
  method: set
  params:
    commands:
      - action: replace
        path: /interface[name=ethernet-1/1]
        value:
          name: ethernet-1/1
          admin-state: disable
      - action: delete
        path: /network-instance[name=default]/interface[name=ethernet-1/1.0]
```

The replace action will delete everything under `/interface[name=ethernet-1/1]` and update it with the value specified in the request. We also remove the binding of the subinterface `ethernet-1/1.0` as it is about to be removed as the result of our replace operation.

Run the playbook with `./ansible.sh task04/replace-partial-cfg.yml`:

???note "Run output"
    ```
    ❯ ./ansible.sh task04/replace-partial-cfg.yml

    PLAY [Replace operation] ********************************************************************************************************************

    TASK [Replace partial config] ***************************************************************************************************************
    ok: [clab-2srl-srl2]
    ok: [clab-2srl-srl1]

    TASK [Stop if request contains error] *******************************************************************************************************
    skipping: [clab-2srl-srl1]
    skipping: [clab-2srl-srl2]

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

In [`task05/replace-entire-cfg.yml`](https://github.com/srl-labs/jsonrpc-ansible/blob/main/task05/replace-entire-cfg.yml) we do just that. The [golden config](https://github.com/srl-labs/jsonrpc-ansible/blob/main/task05/golden.cfg.json.j2) that resides in the task directory has jinja variables that Ansible populates at runtime to add node-specific values. The golden config we used in this example is similar to what we retrieve in the [backup task](#configuration-backup).

```yaml
body:
  jsonrpc: "2.0"
  id: 1
  method: set
  params:
    commands:
      - action: replace
        path: /
        value: "{{lookup('ansible.builtin.template', '{{playbook_dir}}/golden.cfg.json.j2') }}"
```

To replace the entire config we set the path to `/` value and provide the entire config in the value field.

Run the playbook with `./ansible.sh task05/replace-entire-cfg.yml`:

???note "Run output"
    ```
    ❯ ./ansible.sh task05/replace-entire-cfg.yml

    PLAY [Replace operation] ********************************************************************************************************************

    TASK [Replace partial config] ***************************************************************************************************************
    ok: [clab-2srl-srl1]
    ok: [clab-2srl-srl2]

    TASK [Stop if request contains error] *******************************************************************************************************
    skipping: [clab-2srl-srl1]
    skipping: [clab-2srl-srl2]

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

Another golden record of the netops is to dump some operational `show` commands for audit, pre/post checks, etc. Using JSON-RPC's CLI method we can execute `show` and other commands with output format being json, text or table.

In [`task06/fetch-show-cmd-output.yml`](https://github.com/srl-labs/jsonrpc-ansible/blob/main/task06/fetch-show-cmd-output.yml) we collect the output of a few `show` commands in text outputs and save them in per-node files.

```yaml
- name: Operational commands
  # --snip--
  vars:
    commands:
      - show version
      - show platform chassis
  tasks:
    - name: Fetch show commands output
      ansible.builtin.uri:
        # --snip--
        body:
          jsonrpc: "2.0"
          id: 1
          method: cli
          params:
            commands: "{{commands}}"
            output-format: text
        body_format: json
      register: cli_result
```

For this playbook we introduce playbook variable - `commands` - that host a list of show commands we would like to execute remotely. In the body part of the request we use the CLI method and our commands refer to the variable.

To save the results of the executed commands we loop over the results array (see [CLI method examples](../json-rpc/basics.md#cli) for response format explanation) and save each result in its own file with a sanitized name:

```yaml
- name: Save fetched show outputs
  ansible.builtin.copy:
    content: "{{item}}"
    dest: '{{playbook_dir}}/{{inventory_hostname}}.{{ commands[idx] | replace(" ", "-") | regex_replace("[^A-Za-z0-9\-]", "") }}.txt'
  loop: "{{cli_result.json.result}}"
  loop_control:
    index_var: idx
```

Run the playbook with `./ansible.sh task06/fetch-show-cmd-output.yml`:

??? "Run output"

    ```
    ❯ ./ansible.sh task06/fetch-show-cmd-output.yml

    PLAY [Operational commands] *****************************************************************************************************************

    TASK [Fetch show commands output] ***********************************************************************************************************
    ok: [clab-2srl-srl2]
    ok: [clab-2srl-srl1]

    TASK [Stop if request contains error] *******************************************************************************************************
    skipping: [clab-2srl-srl1]
    skipping: [clab-2srl-srl2]

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

[URI module][ansible-uri-doc] allows users to use secured transport and optionally skip certificate verification. Check the basics tutorial [section on https](../json-rpc/basics.md#https) details and how containerlab certificates can help you test the secured connection.

## Summary

While Ansible may not be the best tool for the network automation job due to complicated troubleshooting, weird looping mechanisms, challenging ways to manipulate and extract modelled data - it is still being used by many teams.

Our mission was to demonstrate how Ansible can be used in conjunction with SR Linux Network OS and which interface to choose - [gNMI or JSON-RPC](#gnmi-or-json-rpc)? Then, through a set of task-oriented exercises, we showed almost all methods of JSON-RPC interface. Our selection criteria was to provide the examples that we see typically in the field and at the same time not overcomplicate them so that everyone can follow along.

Do you want us to cover more tasks using Ansible, or any other automation stack? Do let us know in the comments!
