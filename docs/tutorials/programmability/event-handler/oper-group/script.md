---
comments: true
---

A MicroPython script is a central piece of the framework. It allows users to create programmable logic to handle events and thus presents a flexible interface for adding custom functionality to the Nokia SR Linux platform.

Writing MicroPython scripts for the Event Handler is very much like writing regular Python scripts; a developer just needs to keep in mind a limited set of standard library modules available to them.

For testing purposes, users may leverage `ghcr.io/srl-labs/upy:1.18` container image to execute their scripts against a MicroPython interpreter used in SR Linux. Granted, they add a `main()` function to their script in addition to the `event_hander_main()` function required by the framework.

VS Code users can create a dev container with the above image to develop inside the container with MicroPython interpreter as demonstrated in [opergroup-lab repo](https://github.com/srl-labs/opergroup-lab/tree/main/.devcontainer).

!!!note
    Event Handler scripts may exist in two locations:

    1. `/etc/opt/srlinux/eventmgr/` for user-provided scripts
    2. `/opt/srlinux/eventmgr` for Nokia-provided scripts.

    No other directory hierarchy can be used.

## Input

As explained in the [official docs][eh-script] Event Handler expects to find and execute a specific function - `event_handler_main(in_json_str)` - which takes in a json string as its single argument.  
For the oper-group use case, the input JSON string will consist of the current state of the two uplinks and the provided options. For example, the following JSON is expected to be passed to a function when `ethernet-1/49` operational state goes to `down`:

```json
{
    "paths": [
        {
            "path": "interface ethernet-1/49 oper-state",
            "value": "down"
        },
        {
            "path": "interface ethernet-1/50 oper-state",
            "value": "up"
        }
    ],
    "options": {
        "required-up-uplinks": "1",
        "down-links": [
            "ethernet-1/1"
        ]
    }
}
```

## Script walkthrough

Given the input JSON, let's have a look the script that implements the oper-group feature in its entirety.

```py linenums="1"
import sys
import json

# count_up_uplinks returns the number of monitored uplinks that have oper-state=up
def count_up_uplinks(paths):
    up_cnt = 0
    for path in paths:
        if path.get("value", "down") == "up":
            up_cnt = up_cnt + 1
    return up_cnt


# required_up_uplinks returns the value of the `required-up-uplinks` option
def required_up_uplinks(options):
    return int(options.get("required-up-uplinks", 1))


# main entry function for event handler
def event_handler_main(in_json_str):
    # parse input json string passed by event handler
    in_json = json.loads(in_json_str)
    paths = in_json["paths"]
    options = in_json["options"]

    num_up_uplinks = count_up_uplinks(paths)
    downlinks_new_state = (
        "down" if num_up_uplinks < required_up_uplinks(options) else "up"
    )

    # add `debug="true"` option to event-handler configuration to output parsed parameters
    if options.get("debug") == "true":
        print(
            f"num of required up uplinks = {required_up_uplinks(options)}\n\
detected num of up uplinks = {num_up_uplinks}\n\
downlinks new state = {downlinks_new_state}"
        )

    response_actions = []

    for downlink in options.get("down-links", []):
        response_actions.append(
            {
                "set-ephemeral-path": {
                    "path": f"interface {downlink} oper-state",
                    "value": downlinks_new_state,
                }
            }
        )

    response = {"actions": response_actions}
    return json.dumps(response)
```

### Parsing input JSON

Starting with the `event_handler_main` func we parse the incoming JSON string and extracting the relevant portions:

```py
in_json = json.loads(in_json_str)
paths = in_json["paths"]
options = in_json["options"]
```

Paths and Options are the only objects in the incoming JSON, which we respectfully save in the like-named variables.

### Evaluating the desired state of downlinks

With the input parsed, we enter the central piece of the script where we make a decision on what state should the access links be in, given the inputs we received.

```py
num_up_uplinks = count_up_uplinks(paths)
downlinks_new_state = (
    "down" if num_up_uplinks < required_up_uplinks(options) else "up"
)
```

First, we count the number of uplinks in oper-state up, this is done with `count_up_uplinks()` function which simply walks through the current state of the uplinks passed into the script by the Event Handler.

```py
# count_up_uplinks returns the number of monitored uplinks that have oper-state=up
def count_up_uplinks(paths):
    up_cnt = 0
    for path in paths:
        if path.get("value", "down") == "up":
            up_cnt = up_cnt + 1
    return up_cnt
```

When we calculated how many uplinks are operationally up, we can decide what state should the downlinks be in. To rule that decision we compare the number of operational uplinks with the required number of uplinks passed via options:

```py
downlinks_new_state = (
    "down" if num_up_uplinks < required_up_uplinks(options) else "up"
)
```

If the required number of operational uplinks is less than the required number of them, we should put down downlinks to prevent traffic blackholing. On the other hand, if the number of operational uplinks is >= the required number of uplinks, we should bring the access links up.

The desired state of the downlinks is saved in `downlinks_new_state` variable.

### Debugging

It is useful to take a pause here and embed some debugging log outputs for the key variables of a script. In our case, we've added a print statement that dumps important variables of our script.

```py
# add `debug="true"` option to event-handler configuration to output parsed parameters
if options.get("debug") == "true":
    print(
        f"num of required up uplinks = {required_up_uplinks(options)}\n\
detected num of up uplinks = {num_up_uplinks}\n\
downlinks new state = {downlinks_new_state}"
    )
```

The debug log will only be present if the `debug` option will be set to `"true"` in the Event Handler instance config. You will be able to find this log output by using this CLI command:

```
info from state /system event-handler instance opergroup last-stdout-stderr
```

### Composing output

At this point, our script is able to define the desired state of the downlinks, based on the state of the user-defined uplinks and the required number of healthy uplinks. For the Event Handler to take any action, the script needs to output a JSON string following the [expected format][eh-script-output].

```py
response_actions = []

for downlink in options.get("down-links", []):
    response_actions.append(
        {
            "set-ephemeral-path": {
                "path": f"interface {downlink} oper-state",
                "value": downlinks_new_state,
            }
        }
    )

response = {"actions": response_actions}
return json.dumps(response)
```

This code snippet shows the way to create an output JSON, using the calculated `downlinks_new_state` and the list of downlinks provided via `down-links` option.  
We range over the down-links option to append a structure that Event Handler expects to see in output JSON and using [`set-ephemeral-path`][eh-set-eph-path] action that will set oper state of the downlinks to the desired value (up or down).

The output is provided via `response` dictionary, that we marshal to JSON encoding at the end before returning from the function. This routine will provide a JSON back to the Event Handler and since it is formed in a well-known way, Event Handler will process and execute the actions passed to it.

Consequently, by receiving back a list of actions from the script, Event Handler will implement the oper-group feature when a state of a group of downlinks is derived from the state of a group of uplinks.

### Summary

Let's take a few input examples and see which outputs will be generated by the script to better understand the logic of the automation.

We start in a healthy state with both uplinks in operation and oper-group event handler configured as per the [previous steps](oper-group-cfg.md).

In the event of a single uplink interface going operationally down:

=== "Input JSON"
    ```json
    {
        "paths": [
            {
                "path": "interface ethernet-1/49 oper-state",
                "value": "down"
            },
            {
                "path": "interface ethernet-1/50 oper-state",
                "value": "up"
            }
        ],
        "options": {
            "required-up-uplinks": "1",
            "down-links": [
                "ethernet-1/1"
            ]
        }
    }
    ```
=== "Calculated parameters"
    *Number of required uplinks doesn't change as it is an option provided as user input. It is always `1` in our case.
    * Detected number of uplinks in operational state equals `1`, as we range through the `paths` in the incoming JSON and count paths which have `up` value for the `interface ethernet-* oper-state` leaf.
    * Downlinks' new state should be `"up"`, since we still have a minimum number of operational uplinks = `1`.

=== "Output JSON"
    ```json
    {
        "actions": [
            {
                "set-ephemeral-path": {
                    "path": "/interface ethernet-1/1 oper-state",
                    "value": "up",
                }
            }
        ]
    }
    ```

Then let's see what happens if the second uplink goes down.

=== "Input JSON"
    ```json
    {
        "paths": [
            {
                "path": "interface ethernet-1/49 oper-state",
                "value": "down"
            },
            {
                "path": "interface ethernet-1/50 oper-state",
                "value": "down"
            }
        ],
        "options": {
            "required-up-uplinks": "1",
            "down-links": [
                "ethernet-1/1"
            ]
        }
    }
    ```
=== "Calculated parameters"
    *Number of required uplinks doesn't change as it is an option provided as user input. It is always `1` in our case.
    * Detected number of uplinks in operational state equals `0`, as we range through the `paths` in the incoming JSON and count paths which have `up` value for the `interface ethernet-* oper-state` leaf.
    * Downlinks' new state should be `"down"`, since the number of operational uplinks (`0`) is less than the required number of operational uplinks.

=== "Output JSON"
    ```json
    {
        "actions": [
            {
                "set-ephemeral-path": {
                    "path": "/interface ethernet-1/1 oper-state",
                    "value": "down",
                }
            }
        ]
    }
    ```

## Off-box testing

Although it is absolutely possible to test Event Handler scripts using [containerized SR Linux image](../../../../get-started/lab.md#sr-linux-container-image-and-containerlab), it makes a lot of sense to test the script off-box.

Since scripts are provided with a known input JSON structure, we can pass it to a script's `main()` function as if it was provided by the Event Manager itself. Consider the following code snippet that is part of the opergroup.py script we just walked through:

```py linenums="1"
def main():
    example_in_json_str = """
{
    "paths": [
        {
            "path":"interface ethernet-1/49 oper-status",
            "value":"down"
        },
        {
            "path":"interface ethernet-1/50 oper-status",
            "value":"down"
        }
    ],
    "options": {
        "required-up-uplinks":1,
        "down-links": [
            "Ethernet-1/1",
            "Ethernet-1/2"
        ],
        "debug": "true"
    }
}
"""
    json_response = event_handler_main(example_in_json_str)
    print(f"Response JSON:\n{json_response}")


if __name__ == "__main__":
    sys.exit(main())
```

Since Event Handler's entrypoint is `event_handler_main()` func, we can create a `main()` function that contains a variable with a JSON-encoded string that follows the schema of the [input][eh-script-input] argument; this variable is then passed to the `event_handler_main()` simulating Event Handler invokation. In essence, we are mocking the Event Handler and provide a hand-crafted input JSON to the `event_handler_main()` function.

Now, we can test our script on any system that has Python/MicroPython installed, for example:

=== "Testing with Python"
    Given your script doesn't use any non supported by MicroPython libraries, you may use Python3 installed on any system to test your script. For example:
    ```bash
    ❯ python3 opergroup.py
    num of required up uplinks = 1
    detected num of up uplinks = 0
    downlinks new state = down
    Response JSON:
    {"actions": [{"set-ephemeral-path": {"path": "interface Ethernet-1/1 oper-state", "value": "down"}}, {"set-ephemeral-path": {"path": "interface Ethernet-1/2 oper-state", "value": "down"}}]}
    ```
=== "Testing with MicroPyton"
    Testing with MicroPython is advised, as this will guarantee that the code will work on SR Linux. Feel free to install Unix port of MicroPython or leverage `srl-labs/upy:1.18` container image:

    ```
    docker run -it  -v $(pwd):/workdir ghcr.io/srl-labs/upy:1.18 micropython opergroup.py
    num of required up uplinks = 1
    detected num of up uplinks = 0
    downlinks new state = down
    Response JSON:
    {"actions": [{"set-ephemeral-path": {"path": "interface Ethernet-1/1 oper-state", "value": "down"}}, {"set-ephemeral-path": {"path": "interface Ethernet-1/2 oper-state", "value": "down"}}]}
    ```
    To pretty print the output, use `jq`:
    ```
    docker exec -it dc6ded4ed7ff bash -c "micropython opergroup.py | tail -1 | jq ."
    ```
    ```json
    {
        "actions": [
            {
                "set-ephemeral-path": {
                    "path": "interface Ethernet-1/1 oper-state",
                    "value": "down"
                }
            },
            {
                "set-ephemeral-path": {
                    "path": "interface Ethernet-1/2 oper-state",
                    "value": "down"
                }
            }
        ]
    }
    ```

## Script delivery

Scripts created by users must be delivered to the SR Linux nodes and available by the well-known location. Any file transfer technique can be used to deliver the source files/packages.

When using [containerlab](https://containerlab.dev), users may take advantage of the `binds` option of a node and bind mount the script to its location. This is exactly how we do it in the [opergroup-lab](https://github.com/srl-labs/opergroup-lab/blob/6a1ea9be5003b136f27b26db34a2130885f6cfb5/opergroup.clab.yml#L16):

```yaml
name: opergroup

topology:
  nodes:
    leaf1:
      binds:
        - opergroup.py:/etc/opt/srlinux/eventmgr/opergroup.py
```

[eh-script]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/Event_Handler_Guide/scripts.html
[eh-script-input]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/Event_Handler_Guide/scripts.html#scripts__section_hk1_z1m_stb
[eh-script-output]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/Event_Handler_Guide/scripts.html#scripts__section_hjd_sbm_stb
[eh-set-eph-path]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/Event_Handler_Guide/scripts.html#actions__section_ewp_4md_rtb
