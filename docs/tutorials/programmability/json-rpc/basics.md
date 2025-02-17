---
comments: true
title: JSON-RPC Basics
---

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>

# JSON-RPC Basics

| Summary                     |                                                                                              |
| --------------------------- | -------------------------------------------------------------------------------------------- |
| **Tutorial name**           | JSON-RPC Basics                                                                              |
| **Lab components**          | Single Nokia SR Linux node                                                                   |
| **Resource requirements**   | :fontawesome-solid-microchip: 2 vCPU <br/>:fontawesome-solid-memory: 4 GB                    |
| **Lab**                     | [Instant SR Linux Lab][lab]                                                                  |
| **Main ref documents**      | [JSON-RPC Configuration][json-cfg-guide], [JSON-RPC Management][json-mgmt-guide]             |
| **Version information**[^1] | [`srlinux:23.10.1`][srlinux-container], [`containerlab:0.48.6`][clab-install]                |
| **Authors**                 | Roman Dodin [:material-twitter:][rd-twitter] [:material-linkedin:][rd-linkedin]              |
| **Discussions**             | [:material-twitter: Twitter][twitter-share]                                                  |

[rd-linkedin]: https://linkedin.com/in/rdodin
[rd-twitter]: https://twitter.com/ntdvps
[lab]: ../../../blog/posts/2023/instant-srl-labs.md#single-node-sr-linux-lab
[json-cfg-guide]: https://documentation.nokia.com/srlinux/23-10/books/config-basics/management-servers.html#json-rpc-server
[json-mgmt-guide]: https://documentation.nokia.com/srlinux/23-10/books/system-mgmt/json-interface.html
[srlinux-container]: https://github.com/nokia/srlinux-container-image
[clab-install]: https://containerlab.dev/install/
[twitter-share]: https://twitter.com/ntdvps/status/1600261024719917057

As of release 23.10.1, Nokia SR Linux Network OS employs three fully modeled management interfaces:

* gNMI
* JSON-RPC
* CLI

Not only these interfaces are modeled, but they all use the same set of models and therefore enable one of the key differentiators of SR Linux - every management interface has access to the state and configuration datastores and provides the same visibility and configuration capabilities[^2].

<figure markdown>
  [![yang1](https://gitlab.com/rdodin/pics/-/wikis/uploads/9cddf69339c1837019cbb56aee29b860/image.png){: class="img-shadow"}](https://gitlab.com/rdodin/pics/-/wikis/uploads/9cddf69339c1837019cbb56aee29b860/image.png)
  <figcaption>Every management interface is a client of the same core API</figcaption>
</figure>

Every management interface, in essence, uses the same API provided by the management server of SR Linux which makes interfaces equal in access rights and visibility.

<figure>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:1,&quot;zoom&quot;:1.5,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/ndk.drawio&quot;}"></div>
  <figcaption>JSON-RPC as just another client of the same management API</figcaption>
</figure>

In this tutorial, we are going to meet SR Linux's JSON-RPC interface and learn how to achieve basic management tasks using the `curl` utility. In the subsequent tutorials, our focus will shift from the JSON-RPC towards the different tooling that leverages it; think of Ansible, Postman tools and integrations with programming languages like Go and Python.

## Why JSON-RPC?

But first, why even bother using JSON-RPC if SR Linux sports a more performant-on-the-wire and modern gNMI interface? While it is true, that gNMI can be considered more performant on the wire by leveraging HTTP2 multiplexing and protobuf encoding, some well established automation stacks may not be able to offer gRPC/gNMI support just yet.  
To make SR Linux accessible to non-hyperscalers and network teams who have been using HTTP/JSON-based management tools we offered a JSON-RPC management interface that can be easily integrated with a wide variety of higher-level Network Management Systems (NMS) and automation stacks.

## JSON-RPC methods

Being a custom management interface, JSON-RPC offers both standard methods like `get` and `set` to work with the state and configuration datastores of SR Linux, as well as custom functions like `validate` for validating the config and `cli` to invoke CLI commands on the system.  
All of that uses JSON-encoded messages exchanged over HTTP transport.

As the RPC part of the name suggests, users are able to execute certain remote procedures on SR Linux via JSON-RPC interface. We refer to these procedures as methods; the following table summarizes the JSON-RPC provided methods as stated in the [JSON-RPC Management Guide][json-mgmt-guide].

| Method       | Description                                                                                                                                                                                                      |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Get**      | Used to retrieve configuration and state details from the system. The get method can be used with candidate, running, and state datastores, but cannot be used with the tools datastore.                         |
| **Set**      | Used to set a configuration or run operational transaction. The set method can be used with the candidate and tools datastores.                                                                                  |
| **Validate** | Used to verify that the system accepts a configuration transaction before applying it to the system.                                                                                                             |
| **CLI**      | Used to run CLI commands. The get and set methods are restricted to accessing data structures via the YANG models, but the cli method can access any commands added to the system via python plugins or aliases. |

We will introduce all of these methods in detail during the practical section of this tutorial.

To continue with the practical part of this tutorial, make sure you have containerlab >=0.48.6 installed and deploy the [Instant SR Linux Lab][lab] to get SR Linux node up and running in a matter of minutes:

```
SRL_VERSION=23.10.1 sudo -E clab deploy -c -t srlinux.dev/clab-srl
```

<div class="embed-result">
```
INFO[0000] Containerlab v0.48.6 started
+---+------+--------------+-------------------------------+---------------+---------+----------------+----------------------+
| # | Name | Container ID |             Image             |     Kind      |  State  |  IPv4 Address  |     IPv6 Address     |
+---+------+--------------+-------------------------------+---------------+---------+----------------+----------------------+
| 1 | srl  | ca09c745ec38 | ghcr.io/nokia/srlinux:23.10.1 | nokia_srlinux | running | 172.20.20.2/24 | 2001:172:20:20::2/64 |
+---+------+--------------+-------------------------------+---------------+---------+----------------+----------------------+
```
</div>

## Configuring JSON-RPC

SR Linux factory configuration doesn't have JSON-RPC management enabled, but it is easy to configure one. [JSON-RPC Configuration Guide][json-cfg-guide] does a good job explaining all the bits and pieces of interface configuration, so to not repeat ourselves let's look at what containerlab configures automatically for every SR Linux node based on a [single-node lab][lab] that we use in this tutorial.

```srl
--{ running }--[  ]--
A:srl# info /system json-rpc-server
    system {
        json-rpc-server {
            admin-state enable
            network-instance mgmt {
                http {
                    admin-state enable
                }
                https {
                    admin-state enable
                    tls-profile clab-profile
                }
            }
        }
    }
```

By default, containerlab enables JSON-RPC management interface in the management network instance[^4] by configuring `json-rpc-server` instance running both in secure/https and plain-text/http modes on ports 80 and 443 accordingly. For https endpoint, containerlab uses the `tls-profile clab-profile` that it generates on lab startup.

/// note
JSON-RPC management interface runs on the `/jsonrpc` HTTP(S) endpoint of the SR Linux, which means that to access this interface, users should use the following URI:

```bash
http(s)://<srlinux-address>/jsonrpc #(1)!
```

1. where `srlinux-address` is the address of the management interface of SR Linux. The lab used in this tutorial has a deterministic name for the srlinux node - `clab-srl01-srl` - which we will use as the address.
///

With this configuration in place, users can leverage JSON-RPC immediately after containerlab finishes deploying the lab.

## Request/response structure

The management interface sends requests[^3] to the JSON-RPC server and receives responses. The request/response format is a JSON encoded string and is detailed in the [docs][json-msg-structure]. Let's look at the skeleton of the request/response messages as it will help us getting through practical exercises:

/// tab | Request

```json title="JSON-RPC request structure"
{
  "jsonrpc": "2.0",
  "id": 0,
  "method": "get",
  "params": {
    "commands": [],
    "output-format": "" //(1)!
  }
}
```

1. Only applicable for CLI method.

where:

* `jsonrpc` - selects the version of the management interface and at the moment of this writing should be always set to `2.0`.
* `id` - sets the ID of a request which is echoed back in the response to help correlate the message flows[^8].
* `method` - sets one of the supported RPC [methods](#json-rpc-methods) used for this request.
* `params` - container for RPC commands. We will cover the contents of this container through the practical exercises.
///

/// tab | Response

```json
{
  "result": [],
  "id": 0,
  "jsonrpc": "2.0"
}
```

The response object structure provides a `result` list that contains the result of the invoked RPC. Additionally, the response object contains the RPC version and request ID.
///

[json-msg-structure]: https://documentation.nokia.com/srlinux/23-10/books/system-mgmt/json-interface.html#json-message-structure

## Authentication

JSON-RPC server uses basic authentication for both HTTP and HTTPS transports, which means user information must be provided in a request.

```bash title="User credentials are passed in a request"
curl -s -X POST 'http://admin:NokiaSrl1!@srl/jsonrpc'
```

In the example above, the user `admin` with a password `NokiaSrl1!` is used to authenticate with the JSON-RPC API.

## Methods

Enough with the boring theory, let's have some handson fun firing off requests, and learn how JSON-RPC works in real life. To keep things focused on the JSON-RPC itself, we will be using `curl` utility as our HTTP client with `jq` helping format the responses.

/// tip
Keep the [JSON-RPC Management Guide][json-mgmt-guide] tab open, as additional theory is provided there which we won't duplicate in this tutorial.
///

### Get

Starting with the basics, let's see how we can query SR Linux configuration and state datastores using `get` method of JSON-RPC. How about we start with a simple management task of getting to know the software version we're running in our lab container?

/// tab | Request
`curl` by default uses HTTP POST method, thus we don't explicitly specify it. With `-d @- <<EOF` argument we pass the heredoc-styled body of the request in a JSON format of this POST request.

Our `commands` list contains a single object with `path` and `datastore` values set.

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "get",
    "params": {
        "commands": [
            {
                "path": "/system/information/version",
                "datastore": "state"
            }
        ]
    }
}
EOF
```

///

/// tab | Response
`jq` used in the request command displays the json response in a formatted way.

```json
{
  "result": [
      "v23.10.1-218-ga3fc1bea5a"
  ],
  "id": 0,
  "jsonrpc": "2.0"
}
```

///

There is something to unpack in the message used in this exchange. First, note that in the `params` container we specified the `commands` list. Each element in this list is an object that contains a `path` and `datastore` values.  

#### Path

The `path` is a string that follows gNMI Path Conventions[^5] and used to point to an element that is . It is not hard to spot that the `path` follows the [SR Linux YANG model](../../../yang/index.md) and allows us to select a certain leaf that contains the version information.

#### Datastore

The `datastore` value sets the SR Linux datastore we would like to use with our RPC. SR Linux offers four datastores that JSON-RPC users can choose from:

| Datastore     | Description                                                                                                                                                   |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Candidate** | Used to change the configuration of the system with the get, set, and validate methods; default datastore is used if the datastore parameter is not provided. |
| **Running**   | Used to retrieve the active configuration with the get method.                                                                                                |
| **State**     | Used to retrieve the running (active) configuration along with the operational state.                                                                         |
| **tools**     | Used to perform operational tasks on the system; only supported with the update action command and the set method.                                            |

By specifying `path=/system/information/version` and `datastore=state` in our request, we instruct SR Linux to return the value of the targeted leaf using the `state` datastore. An equivalent CLI command on SR Linux to retrieve the same would be:

```
--{ running }--[  ]--
A:srl# info from state system information version  
    system {
        information {
            version v23.10.1-218-ga3fc1bea5a
        }
    }
--{ running }--[  ]--
```

/// note
Datastore value can be set either per-command as in the example above, or on the `params` level. Command-scope datastore value takes precedence over the `params`-scope value.
///

When datastore value is omitted, `running` datastore is assumed. For example, repeating the same request without specifying the datastore will error, as `running` datastore doesn't hold state leaves and thus can't return the `version` leaf under the `/system/information` container.

/// tab | Request

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "get",
    "params": {
        "commands": [
            {
                "path": "/system/information/version"
            }
        ]
    }
}
EOF
```

///

/// tab | Response
An error is returned since running datastore holds configuration, not state, and `version` leaf is a state one.

```json
{
    "error": {
        "code": -1,
        "message": "Path not valid - unknown element 'version'. Options are [contact, location]"
    },
    "id": 0,
    "jsonrpc": "2.0"
}
```

///

The response object contains the same ID used in the request, as well as the list of results. The number of entries in the `results` list will match the number of `commands` specified in the request.

???question "How to get entire configuration?"
    It is quite easy, actually. Just send the request with the `/` path:

    ```bash
    curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
    {
        "jsonrpc": "2.0",
        "id": 0,
        "method": "get",
        "params": {
            "commands": [
                {
                    "path": "/"
                }
            ]
        }
    }
    EOF
    ```

    To get rid of the response fields and only get the value of the result, change the jq expression to `jq '.result[]'`.

    In the same way, to get the full state of the switch, add `state` datastore:

    ```bash
    curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq '.result[]' > /tmp/test.json
    {
        "jsonrpc": "2.0",
        "id": 0,
        "method": "get",
        "params": {
            "commands": [
                {
                    "path": "/",
                    "datastore": "state"
                }
            ]
        }
    }
    EOF
    ```

#### Multiple commands

JSON-RPC allows users to batch commands of the same method in the same request. Just add elements to the `commands` list of the body message. In the following example we query the state datastore for two elements inside the same request:

1. system version
2. statistics data of the mgmt0 interface

/// tab | Request

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "get",
    "params": {
        "commands": [
            {
                "path": "/system/information/version",
                "datastore": "state"
            },
            {
                "path": "/interface[name=mgmt0]/statistics",
                "datastore": "state"
            }
        ]
    }
}
EOF
```

///

/// tab | Response
Response message will contain a list of results with results being ordered the same way as the commands in the request.

```json
{
    "result": [
        "v23.10.1-218-ga3fc1bea5a",
        {
            "in-octets": "140285",
            "in-unicast-packets": "1389",
            "in-broadcast-packets": "0",
            "in-multicast-packets": "1",
            "in-discarded-packets": "0",
            "in-error-packets": "5",
            "in-fcs-error-packets": "0",
            "out-octets": "748587",
            "out-mirror-octets": "0",
            "out-unicast-packets": "2349",
            "out-broadcast-packets": "6",
            "out-multicast-packets": "30",
            "out-discarded-packets": "0",
            "out-error-packets": "0",
            "out-mirror-packets": "0",
            "carrier-transitions": "1"
        }
    ],
    "id": 0,
    "jsonrpc": "2.0"
}
```

Note, that when the path in a request points to a leaf (like `/system/information/version`), then the result entry will be just the value of this leaf. In contrast with that, when the path is pointing to a container, then a JSON object is returned, like in the case of the result for the `/interface[name=mgmt0]/statistics` path.
///

### Set

JSON-RPC is quite flexible when it comes to creating, updating and deleting configuration on SR Linux[^7]. And additionally, Set method allows users to execute operational (aka `/tools`) commands.

When changing configuration with the Set method, the JSON-RPC server creates a private candidate datastore, applies the changes and performs an implicit commit. Thus, changes are commited automatically (if they are valid) for each RPC.

#### Update

Switching to the 1st gear, let's just add a description to our `mgmt0` interface.

/// tab | Request

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "set",
    "params": {
        "commands": [
            {
                "action": "update",
                "path": "/interface[name=mgmt0]/description:set-via-json-rpc"
            }
        ]
    }
}
EOF
```

///

/// tab | Response

```json
{
    "result": [
        {}
    ],
    "id": 0,
    "jsonrpc": "2.0"
}
```

///

/// tab | Verification
Checking that the interface description has been set successfully.

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "get",
    "params": {
        "commands": [
            {
                "path": "/interface[name=mgmt0]/description",
                "datastore": "state"
            }
        ]
    }
}
EOF
```

Response:

```json
{
    "result": [
        "set-via-json-rpc"
    ],
    "id": 0,
    "jsonrpc": "2.0"
}
```

///

##### Action

As you can see, the request message now contains the `set` method, and in the list of commands we have a new field - `action`. Action field is only set with `set` and `validate` methods and can take the following values:

* **update** - updates a leaf or container with the new value.
* **delete** - deletes a leaf or container.
* **replace** - replaces configuration with the supplied new configuration blob for a specified path. This is equivalent to a delete+update operation tandem.

Since we wanted to set a description on the interface, the `update` action was just enough.

The response object for a successful Set method contains a single empty JSON object regardless of how many commands were in the request.

##### Path value formats

I bet you noticed the peculiar path value used in the Set request message - `"path": "/interface[name=mgmt0]/description:set-via-json-rpc"`. This path notation follows the `<path>:<value>` schema, where a scalar value of a leaf is provided in the path itself separated by a `:` char.

Alternatively, users can specify the value using the `"value"` field inside the command. This allows to provide structutred values for a certain path. For example, lets set multiple fields under the `/system/information` container:

/// tab | Request
Set two leaves - `location` and `contact` under the `/system/information` container by using the `value` field of the command.

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "set",
    "params": {
        "commands": [
            {
                "action": "update",
                "path": "/system/information",
                "value": {
                  "location": "the Netherlands",
                  "contact": "Roman Dodin"
                }
            }
        ]
    }
}
EOF
```

///

/// tab | Response

```json
{
  "result": [
    {}
  ],
  "id": 0,
  "jsonrpc": "2.0"
}
```

///

/// tab | Verification

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "get",
    "params": {
        "datastore": "state",
        "commands": [
            {
                "path": "/system/information/location"
            },
            {
                "path": "/system/information/contact"
            }
        ]
    }
}
EOF
```

Result:

```json
{
  "result": [
    "the Netherlands",
    "Roman Dodin"
  ],
  "id": 0,
  "jsonrpc": "2.0"
}
```

///

#### Replace

With the `replace` action it is possible to replace the entire configuration block for a given path with another configuration blob supplied in the request message. In essense, a replace operation is a combination of `delete + update` actions for a given path.

To demonstrate replace operation in action, we will use the same `/system/information` container, that by now contains the `contact` and location leaves:

```bash title="Verify current configuration of /system/information container"
❯ docker exec clab-srl01-srl sr_cli info from running /system information
    system {
        information {
            contact "Roman Dodin"
            location "the Netherlands"
        }
    }
```

Let's replace this conatiner with setting just the contact leaf to "John Doe" value.

/// tab | Request

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "set",
    "params": {
        "commands": [
            {
                "action": "replace",
                "path": "/system/information",
                "value": {
                  "contact": "John Doe"
                }
            }
        ]
    }
}
EOF
```

///

/// tab | Response

```json
{
  "result": [
    {}
  ],
  "id": 0,
  "jsonrpc": "2.0"
}
```

///

/// tab | Verification

```bash
❯ docker exec clab-srl01-srl sr_cli info from running /system information
system {
    information {
        contact "John Doe"
    }
}
```

///

Notice, how the verification command proves that the whole configuration under `/system/information` has been replaced with a single `contact` leaf value, there is no trace of `location` leaf.

???tip "Replacing the whole configuration"
    One of the common management tasks is to replace the entire config with a golden or intended configuration. To do that with JSON-RPC use `/` path and a file with JSON-formatted config:

    ```bash
    curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF
    {
        "jsonrpc": "2.0",
        "id": 0,
        "method": "set",
        "params": {
            "commands": [
                {
                    "action": "replace",
                    "path": "/",
                    "value": $(cat /path/to/config.json)
                }
            ]
        }
    }
    ```

#### Delete

To delete a configuration region for a certain path use `delete` action of the Set method. For example, let's delete everything under the `/system/information` container:

/// tab | Initial state
We start with `information` container containing `contact` leaf.

```bash
❯ docker exec clab-srl01-srl sr_cli info from running /system information 
    system {
        information {
            contact "John Doe"
        }
    }
```

///

/// tab | Request
Delete the configuration under the `/system/information` container.

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "set",
    "params": {
        "commands": [
            {
                "action": "delete",
                "path": "/system/information"
            }
        ]
    }
}
EOF
```

///

/// tab | Response

```json
{
  "result": [
    {}
  ],
  "id": 0,
  "jsonrpc": "2.0"
}
```

///

/// tab | Verification
Verify that the container is now empty:

```bash
❯ docker exec clab-srl01-srl sr_cli info from running /system information
system {
    information {
    }
}
```

///

/// note
Delete operation will not error when trying to delete a valid but non-existing node.
///

#### Multiple actions

For advanced configuration management tasks JSON-RPC interface allows to batch different actions in a single RPC. Multiple commands with various actions can be part of an RPC message body; these actions are going to be applied to the same private candidate datastore that JSON-RPC interfaces uses and will be committed together as a single transaction.

For example, let's create an RPC that will have all the actions batched together:

/// tab | Request
In this composite request we replace the description for the management interface, then create a new network-instance `vrf-red` and finally deleteing a login banner. All those actions will be committed together as a single transaction.

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "set",
    "params": {
        "commands": [
            {
                "action": "replace",
                "path": "/interface[name=mgmt0]/description:set-via-multi-cmd-json-rpc"
            },
            {
                "action": "update",
                "path": "/network-instance[name=vrf-red]",
                "value": {
                    "name": "vrf-red",
                    "description": "set-via-json-rpc"
                }
            },
            {
                "action": "delete",
                "path": "/system/banner/login-banner"
            }
        ]
    }
}
EOF
```

This example also shows how to create an element of a list (like a new network instance) - specify the key in the `path` and the content of the list member in the `value`.
///

/// tab | Response

```json
{
  "result": [
    {}
  ],
  "id": 0,
  "jsonrpc": "2.0"
}
```

///

#### Tools commands

Set method allows users to invoke operational commands that use a specific `tools` datastore. These commands are typically RPCs themselves, as they invoke some action on the SR Linux NOS.

For example, `/tools interface mgmt0 statistics clear` command when invoked via CLI will clear stats for `mgmt0` interface. The same command can be called out using the Set method, as well as using the CLI method.  
The difference being that with Set method users should specify the modelled path using gNMI path notations, while with the CLI method users use the syntax of the CLI.

/// tab | Initial state
Check the amount of incoming octets for mgmt0 interface.

```
--{ + running }--[  ]--
A:srl# info from state /interface mgmt0 statistics in-octets  
    interface mgmt0 {
        statistics {
            in-octets 383557
        }
    }
```

///

/// tab | Request
Clearing statistics of `mgmt0` interface by calling the `/tools` command using the modelled path[^6].

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "set",
    "params": {
        "datastore": "tools",
        "commands": [
            {
                "action": "update",
                "path": "/interface[name=mgmt0]/statistics/clear"
            }
        ]
    }
}
EOF
```

///

/// tab | Response

```json
{
  "result": [
    {}
  ],
  "id": 0,
  "jsonrpc": "2.0"
}
```

///

/// tab | Verification
The following output shows that the stats has been cleared via the tools command executed via JSON-RPC.

```
--{ + running }--[  ]--
A:srl# info from state /interface mgmt0 statistics in-octets
    interface mgmt0 {
        statistics {
            in-octets 4379
        }
    }
```

///

#### Commit confirmation

Starting from SR Linux version 23.3.2 users can leverage `confirm-timeout` parameter available in the Set method. This parameter allows users to specify the amount of time in seconds that the system will wait for a confirmation from the user before committing the configuration specified in this particular Set request. If the user does not confirm the commit within the specified time, the configuration is rolled back.

/// tab | Set request
This request sets a description for the management interface and waits for 5 seconds for a confirmation from the user before committing the configuration.

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "set",
    "params": {
        "commands": [
            {
                "action": "update",
                "path": "/interface[name=mgmt0]/description:set-via-json-rpc"
            }
        ],
        "confirm-timeout": 5
    }
}
EOF
```

///

/// tab | Confirmation
Confirmation of the commit is done via `tools` command.

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "set",
    "params": {
        "datastore": "tools",
        "commands": [
            {
                "action": "update",
                "path": "/system/configuration/confirmed-accept"
            }
        ]
    }
}
EOF
```

///

### Diff

Knowing if the configuration you carefully crafted is going to change the active running configuration is important. It might be a decision factor in whether you want to send the configuration or not.

JSON-RPC's `diff` method allows users to send a configuration blob and let SR Linux perform a diff function between the received configuration blob and the running configuration. The result of the diff function is then sent back to the user.

The Diff method is similar to the Set, so it is very easy to switch one with another. Let's take a Set request that updates `location` and `contact` fields on SR Linux and compare it to the Diff request for the same fields:

/// tab | Diff Request

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "diff",
    "params": {
        "commands": [
            {
                "action": "update",
                "path": "/system/information",
                "value": {
                    "location": "from the diff",
                    "contact": "differ"
                }
            }
        ]
    }
}
EOF
```

///

/// tab | Set Request

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "set",
    "params": {
        "commands": [
            {
                "action": "update",
                "path": "/system/information",
                "value": {
                    "location": "from the diff",
                    "contact": "differ"
                }
            }
        ]
    }
}
EOF
```

///

We are not executing this set request just yet, we want to compare it to the diff request first. As you can see, the requests are almost identical, except for the method name, this makes it super easy to switch between the two.

Let's execute our diff request as it is present in the example above and look at the output:

```json
{
  "result": [
    "  {\n    \"system\": {\n      \"information\": {\n+       \"contact\": \"differ\",\n+       \"location\": \"from the diff\"\n      }\n    }\n  }\n"
  ],
  "id": 0,
  "jsonrpc": "2.0"
}
```

Let's display the result in a more human-readable way by changing the jq command to `jq -r '.result[]'`:

```json
  {
    "system": {
      "information": {
+       "contact": "differ",
+       "location": "from the diff"
      }
    }
  }
```

As you can see the diff method returns a JSON-like formatted string that contains the difference between the running configuration and the configuration that was sent in the request. Plus `+` and Minus `-` chars denotes additions and deletions respectively.

You can also notice that this format is not the same as the format of the diff command executed in the SR Linux CLI. But there is a way to get the same output as the CLI diff command by using the `output-format` parameter of the diff method.

Let's try it out:
/// tab | Diff with text format

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq -r '.result[]'
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "diff",
    "params": {
        "commands": [
            {
                "action": "update",
                "path": "/system/information",
                "value": {
                    "location": "from the diff",
                    "contact": "differ"
                }
            }
        ],
        "output-format": "text"
    }
}
EOF
```

///

/// tab | Output

```diff
      system {
          information {
+             contact differ
+             location "from the diff"
          }
      }
```

///

The `output-format` takes only one value - `text` - to denote that the output should be in the same format as the CLI diff command.

When there is no difference between the provided blob in the diff method and the actual configuration, the diff method returns an empty array. To check that, execute the set request provided in the beginning of this section and then execute the diff method again. This is what you should see as the output:

```json
{
  "result": [],
  "id": 0,
  "jsonrpc": "2.0"
}
```

/// details | How do we use `diff`?
Our [Ansible collection for SR Linux](../../../ansible/collection/index.md) uses `diff` method extensively to implement idempotency principles.
///

### Validate

One of the infamous fallacies that people associate with gNMI is its inability to work with candidate datastores, do confirmed commits and validate configs. While JSON-RPC interface doesn't let you do incremental updates to an opened candidate datastore with the Set method, it allows you to validate a portion of a config using Validate method.

Under the hood, SR Linux executes `commit validate` command on the provided configuration blob, and no configuration changes are made to the system. The goal of Validate method is to give users a way to ensure that the config they are about to push will be accepted.

/// details | validation nuance
It is important to understand that `commit validate` and the Validate method do not guarantee with 100% certainty that the configuration will be accepted. The reason for that is that the validation method relies on YANG-powered validation, which is not the only validation that SR Linux does. Some applications may perform additional validation checks that are not covered by YANG validation. That is why you might see that `commit validate` succeeds, but the actual commit fails due to application-bound validation check.
///

Validate method works with the same actions as Set method - update, replace and delete. For example, lets take our composite change request from the [last exercise](#multiple-actions) and validate it.

/// tab | Request

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "validate",
    "params": {
        "commands": [
            {
                "action": "replace",
                "path": "/interface[name=mgmt0]/description:set-via-multi-cmd-json-rpc"
            },
            {
                "action": "update",
                "path": "/network-instance[name=vrf-red]",
                "value": {
                    "name": "vrf-red",
                    "description": "set-via-json-rpc"
                }
            },
            {
                "action": "delete",
                "path": "/system/banner/login-banner"
            }
        ]
    }
}
EOF
```

///

/// tab | Response

```json
{
  "result": [
    {}
  ],
  "id": 0,
  "jsonrpc": "2.0"
}
```

///

The empty result object indicates that changes were successfully validated and no errors were detected. What happens when the changes are not valid? Let's make some errors in our request, for example, let's try setting a description for an invalid interface:

/// tab | Request

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "validate",
    "params": {
        "commands": [
            {
                "action": "update",
                "path": "/interface[name=GigabitEthernet1/0]/description:set-via-json-rpc"
            }
        ]
    }
}
EOF
```

///

/// tab | Response

```json
{
  "error": {
    "code": -1,
    "message": "Failed to parse value 'GigabitEthernet1/0' for key 'name' (node 'interface') - Invalid value \"GigabitEthernet1/0\": Must match the pattern '(mgmt0|mgmt0-standby|system0|lo(0|1[0-9][0-9]|2([0-4][0-9]|5[0-5])|[1-9][0-9]|[1-9])|lif-.*|vhn-.*|enp(0|1[0-9][0-9]|2([0-4][0-9]|5[0-5])|[1-9][0-9]|[1-9])s(0|[1-9]|[1-2][0-9]|3[0-1])f[0-7]|ethernet-([1-9](\\d){0,1}(/[abcd])?(/[1-9](\\d){0,1})?/(([1-9](\\d){0,1})|(1[0-1]\\d)|(12[0-8])))|irb(0|1[0-9][0-9]|2([0-4][0-9]|5[0-5])|[1-9][0-9]|[1-9])|lag(([1-9](\\d){0,1})|(1[0-1]\\d)|(12[0-8])))'"
  },
  "id": 0,
  "jsonrpc": "2.0"
}
```

///

And SR Linux immediately returns an error explaining where exactly the error was.

### CLI

One of the reasons we ended up having JSON-RPC interface and not RESTCONF was the need to support CLI-formatted operations. At SR Linux, we are big believers in all things modeled, but we can't neglect the fact that transition to model-based world may take time for some teams. In the interim, these teams can effectively accomplish operational tasks using CLI-based automation.

With JSON-RPC CLI method we allow users to remotely execute CLI commands while offering HTTP transport reliability and saving users from the burdens of screen scraping.

/// tip
CLI method also allows to call CLI commands that are not modelled, such as aliases or plugins (e.g. `show version`). But it is not possible to execute interactive commands, e.g. `ping`, `bash`, etc.
///

Staring with basics, let's see what it takes to execute a simple `show version` command using JSON-RPC?

/// tab | Request

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "cli",
    "params": {
        "commands": [
            "show version"
        ]
    }
}
EOF
```

///

/// tab | Response

```json
{
  "result": [
    {
      "basic system info": {
        "Hostname": "srl",
        "Chassis Type": "7220 IXR-D3L",
        "Part Number": "Sim Part No.",
        "Serial Number": "Sim Serial No.",
        "System HW MAC Address": "1A:90:00:FF:00:00",
        "Software Version": "v23.10.1",
        "Build Number": "218-ga3fc1bea5a",
        "Architecture": "x86_64",
        "Last Booted": "2022-12-06T11:38:51.482Z",
        "Total Memory": "24052875 kB",
        "Free Memory": "17004746 kB"
      }
    }
  ],
  "id": 0,
  "jsonrpc": "2.0"
}
```

///

/// tab | Executed in CLI with JSON formatting

```json
--{ + running }--[  ]--
A:srl# show version | as json  
{
  "basic system info": {
    "Hostname": "srl",
    "Chassis Type": "7220 IXR-D3L",
    "Part Number": "Sim Part No.",
    "Serial Number": "Sim Serial No.",
    "System HW MAC Address": "1A:90:00:FF:00:00",
    "Software Version": "v23.10.1",
    "Build Number": "218-ga3fc1bea5a",
    "Architecture": "x86_64",
    "Last Booted": "2022-12-06T11:38:51.482Z",
    "Total Memory": "24052875 kB",
    "Free Memory": "16858484 kB"
  }
}
```

///

/// tab | Executed in CLI

```bash
--{ + running }--[  ]--
A:srl# show version
---------------------------------------------------
Hostname             : srl
Chassis Type         : 7220 IXR-D3L
Part Number          : Sim Part No.
Serial Number        : Sim Serial No.
System HW MAC Address: 1A:90:00:FF:00:00
Software Version     : v23.10.1
Build Number         : 218-ga3fc1bea5a
Architecture         : x86_64
Last Booted          : 2022-12-06T11:38:51.482Z
Total Memory         : 24052875 kB
Free Memory          : 16973972 kB
---------------------------------------------------
```

///

Okay, there is a lot of output here, focus first on the request message. In the request body, we have `cli` method set, and the `commands` list contains a list of strings, where each string is a CLI command as it is seen in the CLI. We have only one command to execute, hence our list has only one element - `show version`.

The response message contains a list of results. Since we had only one command, our results list contains a single element, which matches the output of the `show version | as json` command when it is invoked in the CLI.

/// note
The peculiar `"basic system info"` key in the response is a special node name that is set in the `show version` plugin of the CLI as a constant.

SR Linux uses a concept of CLI plugins for all its `show` commands, and each such command has a root node name that has a unique name. For `show version` command this node name is `basic system info`.
///

#### Output format

Alright, we executed a CLI command, but the returned result is formed as JSON, which is a default formatting option for JSON-RPC. Can we influence that? Turns out we can.

With `output-format` field of the request we can choose the formatting of the returned data:

* json - the default format option
* text - textual/ascii output as seen in the CLI
* table - table view of the returned data

/// tab | Req with `text`
`jq` arguments used in this command filter out the result element and use the raw processing to render newlines.

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq -r '.result[]'
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "cli",
    "params": {
        "commands": [
            "show version"
        ],
        "output-format": "text"
    }
}
EOF
```

///

/// tab | Resp with `text`

```bash
-------------------------------------------------------------
Hostname             : srl
Chassis Type         : 7220 IXR-D3L
Part Number          : Sim Part No.
Serial Number        : Sim Serial No.
System HW MAC Address: 1A:90:00:FF:00:00
Software Version     : v23.10.1
Build Number         : 218-ga3fc1bea5a
Architecture         : x86_64
Last Booted          : 2022-12-06T11:38:51.482Z
Total Memory         : 24052875 kB
Free Memory          : 16414484 kB
-------------------------------------------------------------
```

///

/// tab | Req with `table`

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq -r '.result[]'
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "cli",
    "params": {
        "commands": [
            "show version"
        ],
        "output-format": "table"
    }
}
EOF
```

///

/// tab | Resp with `table`

```bash
+-----------------+-----------------+-----------------+-----------------+-----------------+-----------------+-----------------+-----------------+-----------------+-----------------+-----------------+
|    Hostname     |  Chassis Type   |   Part Number   |  Serial Number  |  System HW MAC  |    Software     |  Build Number   |  Architecture   |   Last Booted   |  Total Memory   |   Free Memory   |
|                 |                 |                 |                 |     Address     |     Version     |                 |                 |                 |                 |                 |
+=================+=================+=================+=================+=================+=================+=================+=================+=================+=================+=================+
| srl             | 7220 IXR-D3L    | Sim Part No.    | Sim Serial No.  | 1A:90:00:FF:00: | v23.10.1        | 218-ga3fc1bea5a | x86_64          | 2022-12-06T11:3 | 24052875 kB     | 16466207 kB     |
|                 |                 |                 |                 | 00              |                 |                 |                 | 8:51.482Z       |                 |                 |
+-----------------+-----------------+-----------------+-----------------+-----------------+-----------------+-----------------+-----------------+-----------------+-----------------+-----------------+
```

///

#### Context switching

When using CLI method, the commands entered one after another work exactly the same as when you enter them in the CLI. This means that current working context changes based on the entered commands. For instance, if you first enters to the interface context and then execute the `info` command, it will work out nicely, since the context switch is persistent across commands in the same RPC.  
The next RPC, as expected, will not maintain the context of a previous RPC; by default running datastore is activated and `/` context is set.

/// tab | Request

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "cli",
    "params": {
        "commands": [
            "interface mgmt0",
            "info"
        ]
    }
}
EOF
```

///

/// tab | Response

```json
{
  "result": [
    {},
    {
      "name": "mgmt0",
      "description": "set-via-multi-cmd-json-rpc",
      "admin-state": "enable",
      "subinterface": [
        {
          "index": 0,
          "admin-state": "enable",
          "ipv4": {
            "dhcp-client": {}
          },
          "ipv6": {
            "dhcp-client": {}
          }
        }
      ]
    }
  ],
  "id": 0,
  "jsonrpc": "2.0"
}
```

///

Note, how the `result` list contains two elements matching the number of commands used in the request. The first command - `/interface mgmt0` - doesn't produce any output, as it just enters the context of an interface. The second command though - `info` - produces the output as it dumps the configuration items for the interface, and we get its output with json formatting.

#### Configuration

You guessed it right, you can also perform configuration tasks with CLI method and use the CLI format of the configuration to do that. Let's configure an interface using CLI-styled commands in different ways:

/// note
When using CLI method for configuration tasks explicit entering into the candidate datastore and committing is necessary.
///

//// tab | Contextual commands
One option to use when executing configuration tasks is to use the commands sequence that an operator would have used. This way every other command respects the present working context.

This method is error-prone, since tracking the context changes is tedious. But, still, this is an option.
/// tab | Request

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "cli",
    "params": {
        "commands": [
            "enter candidate",
            "/interface ethernet-1/1",
            "description \"this is a new interface\"",
            "admin-state enable",
            "commit now"
        ]
    }
}
EOF
```

///
/// tab | Response

```json
{
    "result": [
    {},
    {},
    {},
    {},
    {
        "text": "All changes have been committed. Leaving candidate mode.\n"
    }
    ],
    "id": 0,
    "jsonrpc": "2.0"
}
```

///
////

//// tab | Flattened commands
Flattened commands are levied from the burdens of the contextual commands, as each command starts from the root. This makes configuration snippets longer, but safer to use.
/// tab | Request

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "cli",
    "params": {
        "commands": [
            "enter candidate",
            "/interface ethernet-1/1 description \"this is a new interface\" admin-state enable",
            "commit now"
        ]
    }
}
EOF
```

///
/// tab | Response

```json
{
    "result": [
    {},
    {},
    {
        "text": "All changes have been committed. Leaving candidate mode.\n"
    }
    ],
    "id": 0,
    "jsonrpc": "2.0"
}
```

///
////

//// tab | Config dump
Another popular way to use CLI-styled configs is to dump the configuration from the device, template or change a few fields in the text blob and use it for configuration. In the example below we did `info from running /interface ethernet-1/1` and captured the output. We used this output as is in our request body just escaping the quotes.
/// tab | Request

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "cli",
    "params": {
        "commands": [
            "enter candidate",
            "/interface ethernet-1/1 {
                description \"this is a new interface\"
                admin-state enable
            }",
            "commit now"
        ]
    }
}
EOF
```

///
/// tab | Response

```json
{
    "result": [
    {},
    {},
    {
        "text": "All changes have been committed. Leaving candidate mode.\n"
    }
    ],
    "id": 0,
    "jsonrpc": "2.0"
}
```

///
////

/// tab | Verification
All of the methods should result in the same configuration added:

```bash
❯ docker exec clab-srl01-srl sr_cli info from running /interface ethernet-1/1
    interface ethernet-1/1 {
        description "this is a new interface"
        admin-state enable
    }
```

///

#### Tools commands

Remember how we executed the tools commands within the Set method? We can do the same with CLI method, but in this case we provide the command in the CLI-style. Using the same command to clear statistics counters:

/// tab | Request

```bash
curl -s 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "cli",
    "params": {
        "commands": [
            "tools interface mgmt0 statistics clear"
        ]
    }
}
EOF
```

///

/// tab | Response
The result contains the text output of the tools command which confirms that the command worked:

```json
{
  "result": [
    {
      "text": "/interface[name=mgmt0]:\n    interface mgmt0 statistics cleared\n\n"
    }
  ],
  "id": 0,
  "jsonrpc": "2.0"
}
```

///

## HTTPS

All of the examples have been using plain HTTP schema. As was explained in the beginning of this tutorial, containerlab configures JSON-RPC server to run both HTTP and HTTPS transports.

To use the secured transport any request can be changed to https schema and skipped certificate verification:

```bash
curl -sk 'https://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "get",
    "params": {
        "commands": [
            {
                "path": "/system/information/version",
                "datastore": "state"
            }
        ]
    }
}
EOF
```

If you want to verify the self-signed certificate that containerlab generates at startup use the CA certificate that containerlab keeps in the lab directory:

```bash
curl -s --cacert ./clab-srl01/ca/root/root-ca.pem 'https://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF | jq
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "get",
    "params": {
        "commands": [
            {
                "path": "/system/information/version",
                "datastore": "state"
            }
        ]
    }
}
EOF
```

## Error handling

When either of the commands specified in the RPC request message fails, the returned message will contain an error, even if other commands might be correct. This atomicity of the commands is valid for both Get and Set methods.

For example, the following request has two commands, where 2nd command uses a wrong path.

/// tab | Request

```bash
curl -v 'http://admin:NokiaSrl1!@srl/jsonrpc' -d @- <<EOF
{
    "jsonrpc": "2.0",
    "id": 0,
    "method": "get",
    "params": {
        "commands": [
            {
                "path": "/interface[name=mgmt0]/statistics",
                "datastore": "state"
            },
            {
                "path": "/system/somethingwrong",
                "datastore": "state"
            }
        ]
    }
}
EOF
```

///

/// tab | Response

```json
{
  "error": {
    "code": -1,
    "message": "Path not valid - unknown element 'somethingwrong'. Options are [features, trace-options, management, configuration, aaa, authentication, warm-reboot, boot, l2cp-transparency, lacp, lldp, mtu, name, dhcp-server, event-handler, ra-guard-policy, gnmi-server, tls, json-rpc-server, bridge-table, license, dns, ntp, clock, ssh-server, ftp-server, snmp, sflow, load-balancing, banner, information, logging, mirroring, network-instance, maintenance, app-management]"
  },
  "id": 0,
  "jsonrpc": "2.0"
}
```

///

The response will contain just an error container, even though technically the first command is correct. Note, that the HTTP response code is still `200 OK`, since JSON-RPC was able to deliver and execute the RPC, it is just that the RPC lead to an error.

[^1]: the following versions have been used to create this tutorial. The newer versions might work; please pin the version to the mentioned ones if they don't.
[^2]: differences in capabilities that different management interfaces provide are driven by the interfaces standards.
[^3]: using HTTP POST method.
[^4]: JSON-RPC, as gNMI, can run in a user-configured network-instance.
[^5]: https://github.com/openconfig/reference/blob/master/rpc/gnmi/gnmi-path-conventions.md
[^6]: Tools paths can be viewed in our [tree YANG browser](https://yang.srlinux.dev/releases/v23.10.1/tree).
[^7]: Support for setting configuration with Openconfig schema will be added at a later date. Currently only CLI method allows working with Openconfig schema via `enter oc` command.
[^8]: SR Linux logs JSON-RPC incoming and outgoing requests to `/var/log/srlinux/debug/sr_json_rpc_server.log` log file.
