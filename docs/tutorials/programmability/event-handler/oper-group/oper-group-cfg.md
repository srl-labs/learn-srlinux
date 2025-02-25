---
comments: true
---

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>

Now that we are [aware of a potential traffic blackholing](problem-statement.md#traffic-loss-scenario) that may happen in the all-active EVPN-based fabrics it is time to meet one of the remediation tactics.

What would have helped to prevent traffic to get blackholed is to not let it be forwarded to a leaf that has no active uplinks in the first place. This may be achieved by disabling links connected to workloads as soon as uplinks become operationally disabled. This is what oper-group can do and what is depicted below.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:3,&quot;zoom&quot;:3,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/opergroup.drawio&quot;}"></div>

In this section, we will look into how a particular flavor of the oper-group feature is realized using the Event Handler framework.

## Event Handler-based Oper Group

Starting with the 22.6.1 release SR Linux comes equipped with the [**Event Handler**][eh-overview] framework that allows users to write custom Python scripts and has these scripts be called in the event state paths change the value. Event Handler enables SR Linux operators to add programmable logic to handle events that happen in a system.

The following sequence[^1] captures the core logic of the Event-Handler framework:

1. A user configures the Event Handler instance with a set of objects to monitor. The objects are referenced by their [path](#monitored-paths) provided in a CLI notation.
2. In addition to the paths, a user may configure arbitrary static [options](#options) that will parametrize a script.
[script](#script)
4. Whenever there is a state change for any of the monitored paths, Event Handler executes a script with a single argument - a JSON string that consists of:
    - the current value of the monitored paths
    - options provided by a user
    - persistent data if it was set by a script

One of the first features that leverage Event Handler capability is Oper Group. As was explained in the introduction section, oper-group feature allows changing the operational status of selected ports based on the operational status of another, related, group of ports.

Event Handler is supported in SR Linux by the `event_mgr` process which exposes configuration and state via a container at `.system.event-handler`. Within this container, a list of event handling instances can be configured at `.system.event-handler.instance{}` with a user-defined name.

```sh
--{ * candidate shared default }--[ system event-handler ]--
A:leaf1# info
    instance opergroup { #(1)!
    }
```

1. creation of `opergroup` Event Handler instance

In this tutorial we will touch upon the most crucial configuration options:

- `paths` - to select paths for monitoring state changes
- `options` - to provide optional parameters to a script
- `upython-script` - a path to a MicroPython script that contains the automation logic

## Monitored paths

The oper-group feature requires users to define a set of uplinks that are crucial for a working service. By monitoring the state of these selected uplinks oper-group decides if the downlinks' operational state should be changed.

In the context of this tutorial, on `leaf1` two uplink interfaces `ethernet-1/49` and `ethernet-1/50` should be put under monitoring to avoid blackholing of traffic in case their oper-state will change to a down state.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:13,&quot;zoom&quot;:3,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/opergroup.drawio&quot;}"></div>

Event Handler configuration contains [`paths`][eh-paths] leaf-list for users to select objects for monitoring. Paths should be provided in a CLI format.

To monitor the operational state of a given interface the `interface <interface-name> oper-state` leaf shall be used; in our case, this requirement will translate to the following configuration:

```sh
--{ * candidate shared default }--[ system event-handler instance opergroup ]--
A:leaf1# info
    paths [
        "interface ethernet-1/{49..50} oper-state" #(1)!
    ]
```

1. Paths can use range expansion and wildcards

With this configuration Event Handler will subscribe to state changes for `oper-state` leaf of the two interfaces.

## Options

By just monitoring the operational state of certain uplinks we don't gain much. There needs to be a coupling between the monitored uplinks and the downlinks.

- Which access links should react to state changes of the uplinks?
- How many uplinks must be "healthy" before we bring down access links?

To answer these questions we need to provide additional parameters to the Event Handler and this is done via [`options`][eh-options].

Options are a user-defined set of parameters that will be [passed to a script][eh-script] along with the state of the monitored paths. For the oper-group feature we are going to define two options, that help us parametrize

```sh
--{ * candidate shared default }--[ system event-handler instance opergroup ]--
A:leaf1# info options
    options {
        object down-links {
            values [
                ethernet-1/1
            ]
        }
        object required-up-uplinks {
            value 1
        }
    }
```

To define which links should follow the state of the uplinks we provide the `down-links` option. This option is defined as a list of values to accommodate for potential support of many access links, but since our lab only has single access lint, the list.

!!!note
    Values defined in options are free-formed strings and may or may not follow any particular syntax. For `down-links` option, we choose to use a CLI-compatible value of an interface since this will make it easier to create an action in the script body. But we could use any other form of the interface name.

The second option - `required-up-uplinks` - conveys the number of uplinks we want to have in operation before we put access links down. When a leaf has more than 1 uplink, we may want to tolerate it losing a single uplink. In this tutorial, we pass a value of `1` which means that at a minimum we want to have at least one uplink to be up.  
In the script body, we will implement the logic of calculating the number of uplinks in an operational state, and the option is needed to provide the required boundary.

We will also add a third option that will indicate to our script that it should print the value of certain script variables as explained later in the [debug](script.md#debugging) section. This option will help us explain script operations when we reach [Oper group in action chapter](opergroup-operation.md).

## Script

Event-Handler is a programmable framework that doesn't enforce any particular logic when it comes to handling events occurring in a system. Instead, users are free to create their [scripts][eh-script] and thus program the handling of events.

As part of the event handler instance configuration, users have to provide a path to a MicroPython script:

```sh
--{ * candidate shared default }--[ system event-handler instance opergroup ]--
A:leaf1# info
    admin-state enable
    upython-script opergroup.py # (1)!
    --snip--
```

1. A file named `opergroup.py` will be looked up in the following directories:
    - `/etc/opt/srlinux/eventmgr/` for user-provided scripts
    - `/opt/srlinux/eventmgr` for Nokia-provided scripts.

This script will be called each time a state of any monitored paths changes.

## Resulting configuration

When paths, options and script location are put together the Event Handler instance config takes the following shape:

```sh
--{ * candidate shared default }--[ system event-handler instance opergroup ]--
A:leaf1# info
    admin-state enable
    upython-script opergroup.py #(4)!
    paths [
        "interface ethernet-1/{49..50} oper-state" #(1)!
    ]
    options {
        object debug { #(5)!
            value true
        }
        object down-links { #(2)!
            values [
                ethernet-1/1
            ]
        }
        object required-up-uplinks { #(3)!
            value 1
        }
    }
```

1. Monitor the operational state of these uplinks.
2. The following links we consider "access" links, their operational state will depend on the state of the uplinks when processed by a script.
3. Required number of uplinks to be in the oper-up state before putting down downlinks.
4. Path to the script file which defines the logic of the event-handling routine using the state changes of the monitored paths and provided options.
5. [Debug](script.md#debugging) option to indicate to a scrip that it should print additional debugging information.

Now when the configuration is done, it is time to dive into the MicroPython code itself; at the end of the day, it is the core component of the framework.

[^1]: see [the sequence diagram][eh-overview] for additional details.

[eh-overview]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/Event_Handler_Guide/eh-overview.html
[eh-paths]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/Event_Handler_Guide/event_handler.html#event-handler-config__section_ojq_kxt_stb
[eh-options]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/Event_Handler_Guide/event_handler.html#event-handler-config__section_umk_zb5_stb
[eh-script]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/Event_Handler_Guide/scripts.html
