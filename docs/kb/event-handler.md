|                          |                |
| ------------------------ | -------------- |
| **Official doc section** | TODO: add link |

!!!warning
    Always consult with the official documentation, as knowledge base articles provide only the gist of a certain feature/functionality.

Event-driven architecture is a software architecture paradigm promoting the production, detection, consumption of, and reaction to events. In network automation, an event-driven approach is often seen as a holy grail of closed-loop systems as a reaction to events makes the loop close in highly automated networks.

Keeping ourselves in the network boundaries, we can define the following main components of an event-driven system:

1. **Event**  
    Most commonly produced by the network element itself. A link goes down, session transitions to `oper-state=up` - are the events that the network element produces.
2. **Event transport system**  
    Events sourced at a certain point in the network or a specific subsystem of a node need to be transferred to an Event processor for evaluation. This can be a local message bus or a management protocol (gNMI, etc).
3. **Event processor**  
    A system that consumes the events and produces an output

The event processor can be deployed centrally in the network, distributed over several nodes, or even run on each network element. Starting with Nokia SR Linux 22.6.1[^1] software release, a new application called "Event Handler" has been introduced to give users a way to make SR Linux react to local events.

The event handling concept is being able to react to certain system events, with programmable logic on what actions to take as a result. Event Handler allows users to write custom Python[^1] scripts and has these scripts be called in the event state paths change the value, thus introducing programmable logic to handle events.

The most common use case that leverages Event Handler capability is known as [Oper Group](../tutorials/programmability/event-handler/oper-group/oper-group-intro.md), where specific ports are put operationally up/down based on the oper status of another group of ports. Of course, many other use cases can benefit from local events that can be programmatically handled whenever users wish to.

Interactions between Event Handler, SR Linux' Management Server and user-provided script are outlined within the following sequence diagram and are explained in detail further.

``` mermaid
sequenceDiagram
  autonumber
  participant M as Mgmt Server
  participant EH as Event Handler
  participant S as Script
  EH->>M: Subscribe to YANG paths
  Note over M: State change occurs for any<br/>of the subscribed paths
  M->>EH: Current state for all subscribed paths
  EH->>S: Invoke a script with passing<br/> state changes as input parameter
  S->>S: Process input parameters
  S->>EH: Output as a list of actions
  EH->>EH: Process actions list
  EH->>M: Execute action(s)<br/>(or run another script)
```

## Configuration
Event Handler is supported in SR Linux by the `event_mgr` process which exposes configuration and state via a container at `.system.event-handler`. Within this container, a list of event handling instances can be configured at `.system.event-handler.instance{}` with a user-defined name.

Here is the annotated config of `event-handler` container that highlights most important knobs of this feature.

An event handler instance config consists of:

```sh
--{ * candidate shared default }--[ system event-handler instance opergroup ]--
A:leaf1# info
    admin-state enable # (1)!
    upython-script opergroup.py # (2)!
    paths [
        "interface ethernet-1/55 oper-state" # (3)!
        "interface ethernet-1/56 oper-state"
    ]
    options { # (4)!
        object down-links {
            values [ # (5)!
                ethernet-1/1
                ethernet-1/2
            ]
        }
        object required-num-up-link {
            value 1 # (6)!
        }
    }
```

1. A toggle to enable or disable the instance
2. A reference to a MicroPython script to run. This script must live in `/etc/opt/srlinux/eventmgr/`, or `/opt/srlinux/eventmgr/` for Nokia-provided scripts
3. A list of paths in a CLI notation that Event Handler will receive state change events for.
4. A set of options in the form of objects and their value or values. This is useful for passing configuration to the function, and is described in [options](#options) chapter.
5. An example of an option's object with multiple values. Values are passed as json strings and need not to follow any particular schema.
6. An example of an option's object with a single value passed as string.

The config above is created for [Oper Group](../tutorials/programmability/event-handler/oper-group/oper-group-intro.md) use case that monitors the operation state of uplinks `ethernet-1/55`/`ethernet-1/56`, and if any of those uplinks change their state to `down`, then downstream links from the options list `down-link` will be set to down operationally. The logic to counting the amount of oper-up uplinks and putting down down-links is kept within the `opergroup.py` script referenced in the config.

### Paths
Event Handler monitors objects referenced by their path. Paths must be given in a CLI notation and refer to a leaf or leaf-list[^2]. A few examples:

* `interface ethernet-1/1 oper-state`
* `interface ethernet-1/{1..12} oper-state`
* `interface ethernet-1/* oper-state`
* `interface * oper-state`

In our example, we configure Event Handler to subscribe to state changes of the `oper-state` leaf of the two uplink interfaces.

### Options
The options field lets a user define a set of arbitrarily named objects, and associate either a value or values to it. This allows users to provide configuration options to the script's main function.

In the example above, two options are configured:

1. `down-links` - an option with multiple values, in that case two values `ethernet-1/1` and `ethernet-1/2`.  
    The `down-links` option thus keeps a list of downstream links we want to pass to the script. Script's logic then may use those values when it is being run.
2. `required-num-up-link` - an option with a single value that conveys the number of uplinks we want to always have in oper up state before bringing down links down.

!!!note
    1. Option' values passed via CLI are encoded as strings
    2. Option' name is a free-formed string that users define as they see fit.

### uPython script
A path to a MicroPython script is provided with `upython-script` config parameter. Read more about it in the subsequent sections.

## Script
An Event Handler script is the core component of the framework. It contains the logic that operates on the input JSON string passed by the `event_mgr` process to it each time there is a state change detected for the paths used in the event handler instance configuration.

### MicroPython
Scripts are executed by MicroPython[^1] interpreter and thus have a limited set of modules available in the standard library. For the most part, users may use a regular Python interpreter to write the scripts for the Event Handler, granted they use [standard libraries available for MicroPython](http://docs.micropython.org/en/latest/library/index.html).

Check the [Dev environment](#dev-environment) section for various ways of developing for MicroPython.

### Location
Event Handler scripts may exist in two locations:

1. `/etc/opt/srlinux/eventmgr/` for user-provided scripts
2. `/opt/srlinux/eventmgr` for Nokia-provided scripts.

No other directory hierarchy can be used.

### Input
Whenever a state change is detected for any of the monitored paths, the Event Handler calls a referenced MicroPython script. Event Handler calls a specific function `event_handler_main()` in the provided script, passing it a JSON string indicating the current values of the monitored paths, and any other options configured

Using the configuration example given at the beginning of this page, in the event of a state change for any of the two links operational status, the following JSON string would have been generated by the Event Handler and passed over to a script as input.

```json
{
    "paths": [
        {
            "path": "interface ethernet-1/55 oper-state", // (1)!
            "value": "down"
        },
        {
            "path": "interface ethernet-1/56 oper-state",
            "value": "down"
        }
    ],
    "options": { // (2)!
        "required-up-uplinks": "2",
        "down-links": [
            "ethernet-1/1",
            "ethernet-1/2"
        ]
    }
}
```

1. the current state of each monitored path is provided in the `paths` list which contains `path:value` objects.
2. user-provided options are passed in the `options` JSON object.

### Output
A MicroPython script must return a single parameter, which is a JSON string with a structure expected by the Event Handler.

The structure of the output JSON string adheres to the following schema:

??? "Output JSON format"
    ```json
    {
        "actions": [
            {
                "set-ephemeral-path": {
                    "path": "",
                    "value": "",
                    "always-execute": false
                }
            },
            {
                "set-cfg-path": {
                    "path": "",
                    "value": "",
                    "always-execute": false  
                }
            },
            {
                "set-cfg-path": {
                    "path": "",
                    "json-value": {},
                    "always-execute": false
                }
            },
            {
                "delete-cfg-path": {
                    "path": "",
                    "always-execute": false
                }
            },
            {
                "set-tools-path": {
                    "path": "",
                    "value": "",
                    "always-execute": false
                }
            },
            {
                "set-tools-path": {
                    "path": "",
                    "json-value": {},
                    "always-execute": false
                }
            },
            {
                "run-script": {
                    "cmdline": "",
                    "always-execute": false
                }
            },
            {
                "reinvoke-with-delay": 5000
            }
        ],
        "persistent-data": {
            "last-state-up": false
        }
    }
    ```

As seen from the output example above, script' output mostly contains a list of various actions. These actions are passed to the Event Handler for processing.

#### Actions
An incomplete list of actions is provided below for reference.

##### set-ephemeral-cfg
Allows a user to ephemerally change a state leaf. Each `set-ephemeral-path` is a `path:value`. Paths are provided in a CLI notation with a possibility to use ranges.

The most common use case for this action is setting an interface oper-state based on some other criteria like in the [oper-group use case](../tutorials/programmability/event-handler/oper-group/oper-group-intro.md).

In release 21.6.1 a single path is supported by this action - `interface * oper-state` - with the values of `up`/`down`.

## Dev environment
Writing MicroPython scripts for the Event Handler is very much like writing regular Python scripts; a developer just needs to keep in mind a limited set of standard library modules available to them.

For testing purposes, users may leverage `ghcr.io/srl-labs/upy:1.18` container image to execute their scripts against a MicroPython interpreter used in SR Linux. Granted, they add a `main()` function to their script in addition to the `event_hander_main()` func required by the framework.

VS Code users can create a dev container with the above image to develop inside the container with MicroPython interpreter as demonstrated in [opergroup-lab repo](https://github.com/srl-labs/opergroup-lab/tree/main/.devcontainer).

[^1]: a trimmed-down python engine - [MicroPython](https://micropython.org/) - is used to run Event Handler scripts.
