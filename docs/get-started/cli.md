---
comments: true
---

# SR Linux CLI

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>

Over the past years the industry has seen numerous attempts to sacrifice the CLI to the SDN and/or automation gods. We believe that CLI is here to stay, and we must evolve it and make it powerful, modern, programmable, and highly customizable.

With the ambitious goal of making SR Linux CLI the pinnacle of the text-based interfaces, we knew it would look different from the traditional CLI. But fear not, the powers that come with SR Linux CLI outweigh the little effort it takes to make your fingers type new commands.

/// admonition | Highly customizable CLI
    type: subtle-note
SR Linux CLI is highly customizable, you can change the prompt, add new commands, create aliases, etc. If you miss a feature - join our [Discord community](https://go.srlinux.dev/discord) and let us know!
///

## Prompt

The first thing you will see when logged into SR Linux is its default two-line prompt and a CLI bottom toolbar.

-{{ diagram(url='srl-labs/srlinux-getting-started/main/diagrams/get-started.drawio', title='Default SR Linux prompt', page=0) }}-

The prompt' picture title reads "default", because it is highly customizable. For the purpose of this guide, we will use the default prompt and leave prompt customization for later. The annotations in the picture provide a brief explanation of each part of the prompt, and we provide a more detailed through the rest of this guide.

## Help

When you first log into an unknown OS, you want to know what commands are available to you. In SR Linux, there are several contex-aware help commands and key bindings that can help you navigate the CLI.

Hitting the <kbd>?</kbd> in the CLI will list all available **local** commands:
<!-- --8<-- [start:local-in-running] -->
```srl
--{ running }--[  ]--
A:leaf1# <pressed ? key>
Local commands:
  acl               Top level container for configuration and operational state related to access control lists (ACLs)
  bfd               Context to configure BFD parameters and report BFD sessions state
  interface         The list of named interfaces on the device
  network-instance  Network instances configured on the local system
  platform          Enclosing container for platform components
  qos               Top-level container for QoS data
  routing-policy    Top-level container for all routing policy configuration
  system            Enclosing container for system management
  tunnel            This model collects all config and state aspects of the tunnel table
  tunnel-interface  In the case that the interface is logical tunnel

*** Not all commands are listed, press '?' again to see all options ***
```
<!-- --8<-- [end:local-in-running] -->

Local commands are actual configuration elements available in the present working context. See this `[  ]` in the prompt? That means the user is in root context, and local commands that are available in the `running` mode for the root context are listed.

If you press <kbd>?</kbd> again, you will see all available commands, local and global:

```srl
--{ running }--[  ]--
A:leaf1# <pressed ? key> <pressed ? key again>
Local commands:
  acl               Top level container for configuration and operational state related to access control lists (ACLs)
  bfd               Context to configure BFD parameters and report BFD sessions state
 # clipped
  tunnel-interface  In the case that the interface is logical tunnel

Global commands:
  !                 History substitution
  /                 Moves you to the root
  back              Return to previous context
  bash              Open bash session
# clipped
  environment       Control the look-and-feel of the CLI
```

Global commands, as the name implies, are available in any context. They are not tied to a specific context.

### Suggestions and completions

Something that you will notice when hitting <kbd>TAB</kbd> is the auto-suggestion form that is common in powerful shells like zsh/fish but was not available in any other NOS CLI until now.

-{{ diagram(url='srl-labs/srlinux-getting-started/main/diagrams/get-started.drawio', title='', page=1) }}-

The suggestion popup shows global and local commands available in the current context. In other words, it is context aware.  
Since we are still sitting in the root context (`[  ]` indicates that), the suggestion popup shows all available commands in the root context.

You can use the arrow keys (<kbd><-</kbd><kbd>-></kbd>, etc) to navigate the suggestions and press <kbd>ENTER</kbd> to select a suggestion.

-{{ diagram(url='srl-labs/srlinux-getting-started/main/diagrams/get-started.drawio', title='', page=2) }}-

Besides the suggestions, SR Linux comes with the smart autocompletion system. Again, something that modern shells offer you on *nix systems. When you start typing a command, the CLI will suggest the next command right in the command line using the same context-aware suggestions.

And if you are a fast typer, autocompletion engine will try to fix typos for you whenever it can.

-{{ video(url='https://gitlab.com/rdodin/pics/-/wikis/uploads/d8f7d0644fa6c26c88f9251396b6fe04/completion-1.mp4') }}-

## CLI modes

SR Linux CLI has three main modes that a user can be in:

* running
* candidate (aka configuration)
* state

### Running

When a user logs into SR Linux, they start in the `running` mode. This is the mode in which the user can use operational and show commands, view configuration and perform actions via `/tools` commands, but they **can not** perform any configuration changes.

/// admonition | Similar to...
    type: subtle-note
This mode is similar to the enable mode (in Cisco/Arista) or the operational mode (Juniper Junos). The prompt and the toolbar show `running` when the user is in this mode.
///

As said, in this mode a user can execute operational and show commands. To give you a few examples:

/// tab | `ping`

```srl
Ping is an operational command.

--{ running }--[  ]--
A:leaf1# ping network-instance mgmt 172.20.20.1
Using network instance mgmt
PING 172.20.20.1 (172.20.20.1) 56(84) bytes of data.
64 bytes from 172.20.20.1: icmp_seq=1 ttl=64 time=5.59 ms
64 bytes from 172.20.20.1: icmp_seq=2 ttl=64 time=1.26 ms
```

///
/// tab | `show version`

```srl
--{ running }--[  ]--
A:leaf1# show version
--------------------------------------------------
Hostname             : leaf1
Chassis Type         : 7220 IXR-D2L
Part Number          : Sim Part No.
Serial Number        : Sim Serial No.
System HW MAC Address: 1A:29:02:FF:00:00
Software Version     : v23.10.1
Build Number         : 218-ga3fc1bea5a
Architecture         : x86_64
Last Booted          : 2024-09-22T16:07:22.230Z
Total Memory         : 72379371 kB
Free Memory          : 59331625 kB
--------------------------------------------------
```

///

### Candidate

The `candidate` mode is the mode in which a user performs configuration changes in the candidate datastore. To enter this mode use the `enter` global command and provide the mode as an argument.

```srl title="Enter candidate mode from running mode"
--{ running }--[  ]--
A:leaf1# enter candidate

--{ candidate shared default }--[  ]--
A:leaf1#
```

You can immediately notice how the prompt changed. Now it shows the following information:

* `candidate` - the mode in which the user is in
* `shared` - the type of the candidate datastore is shared[^1]
* `default` - the name of the candidate datastore

We will show you how to perform configuration changes when we get to the [Interfaces](interface.md) section.

### State

The last mode we are going to meet is the `state` mode. This mode is similar to the `running` mode as the user can view configuration, execute operational and show commands.  
But in addition to that, the user can also view the **state** information, that is the values that are non-configurable, but are calculated by the system.

Think about counters, like interface statistics, or the system uptime, or BGP peering state. These are state information and these values are accessible in the `state` mode.

```srl title="Enter candidate mode from running mode"
--{ running }--[  ]--
A:leaf1# enter state

--{ state }--[  ]--
A:leaf1#
```

/// admonition | Changing between CLI modes
    type: subtle-note
Typing `enter <target-mode>` anywhere in the CLI will change the current mode to the target mode.
///

## Navigation and Contexts

Upon logging into SR Linux, you start in the root context, as indicated by the `[  ]` part of prompt. Using the CLI [help](#help) commands, you can explore what commands and contexts are available to you from your current context.

/// admonition | SR Linux is a fully modelled Network OS
    type: subtle-note
Since SR Linux Network OS operates on a 100% YANG-modelled infrastructure, its CLI strictly follows the YANG model and the [YANG model](../yang/index.md) is a tree-like hierarchical structure.
///

As shown in the Help section before, you can list the local commands available in the current context using <kbd>?</kbd> key. For example, in the root context of the running mode you get the following:

--8<-- "docs/get-started/cli.md:local-in-running"

### Entering contexts

What you see in the list of the local commands are **contexts** that you can enter by typing the name of the context. For example, if you want to enter the `interface` context, you can do so by typing `interface`:

-{{ diagram(url='srl-labs/srlinux-getting-started/main/diagrams/get-started.drawio', title='', page=3) }}-

If you click <kbd>TAB</kbd> or <kbd>Space</kbd> after typing `interface` the CLI will prompt you with the `<name>` key, indicating that the `interface` is a list element and you need to provide the interface name as an argument.

-{{ diagram(url='srl-labs/srlinux-getting-started/main/diagrams/get-started.drawio', title='', page=4) }}-

Clicking <kbd>TAB</kbd> again will show you the configured interfaces present in the system in the autosuggestion window:

-{{ diagram(url='srl-labs/srlinux-getting-started/main/diagrams/get-started.drawio', title='', page=5) }}-

Let's select `mgmt0` or type it in and press <kbd>Enter</kbd> to enter the `interface mgmt0` context.

```srl
--{ running }--[  ]--
A:leaf1# interface mgmt0

--{ running }--[ interface mgmt0 ]--
A:leaf1#
```

The prompt changed to show the current context - `[ interface mgmt0 ]`. Recall, that SR Linux CLI is context-aware, therefore using the <kbd>?</kbd> key now will show you the different local commands, as you are standing in a different current context.

```srl
--{ running }--[ interface mgmt0 ]--
A:leaf1# <pressed ? key>
Local commands:
  admin-state*      The configured, desired state of the interface
  description*      A user-configured description of the interface
  ethernet
  lag               Container for options related to LAG
  loopback-mode*    Loopback mode of the port
  mtu*              Port MTU in bytes including ethernet overhead but excluding 4-bytes FCS
  qos
  sflow             Context to configure sFlow parameters
  subinterface      The list of subinterfaces (logical interfaces) associated with a physical interface
  tpid*             Optionally set the tag protocol identifier field (TPID) that
  transceiver
  vlan-tagging*     When set to true the interface is allowed to accept frames with one or more VLAN tags
```

You're again present with a list of local commands, but this time you can spot an asterisk (`*`) next to some of the commands. These are the stub contexts (leafs and leaf-lists) that you can not enter to.

Let's go one level deeper by entering into the `subinterface` context of our `mgmt0` interface.

By typing `subinterface` and pressing <kbd>TAB</kbd> you will see autosuggested subinterface index `0` automatically selected. This is because `mgmt0` interface has only one subinterface configured and it is `0`[^2]. By clicking <kbd>TAB</kbd> after again you will accept the suggestion and hitting <kbd>Enter</kbd> will enter the `subinterface 0` context.

```srl title="Accept suggested subinterface index with TAB key"
--{ running }--[ interface mgmt0 ]--
A:leaf1# subinterface 0
```

Now the prompt changed to show the current context - `[ interface mgmt0 subinterface 0 ]`.

```srl
--{ running }--[ interface mgmt0 subinterface 0 ]--
A:leaf1#
```

### Exiting contexts

To exit from the current context use `exit` command, that takes an optional argument of `to`. Consider the following example where we are in the `interface mgmt0 subinterface 0` context and we want to exit one step above to the `interface mgmt0` context.

```srl title="<code>exit</code> brings you one level up in the context hierarchy"
--{ running }--[ interface mgmt0 subinterface 0 ]--
A:leaf1# exit

--{ running }--[ interface mgmt0 ]--
A:leaf1#
```

If you want to exit to a specific parent context from the current one, you can leverage `exit to` variant:

```srl
--{ running }--[ interface mgmt0 subinterface 0 ]--
A:leaf1# exit to <context>
                  interface
                  root     
```

The autosuggestion window will list all parent contexts (`interface`, `root`) that you can exit to from your current context.

And lastly, you can also navigate to whatever context from any other context by providing the absolute path to the target context. The absolute path starts with `/`. The example below will switch the context from `interface mgmt0 subinterface 0` to `system information`.

```srl
--{ running }--[ interface mgmt0 subinterface 0 ]--
A:leaf1# / system information

--{ running }--[ system information ]--
A:leaf1#
```

### Command scope

When you're in a context, your commands are scoped to that context. For example, if we are currently sitting in the `[ interface mgmt0 subinterface 0 ]` context, then the `tree` command that prints the tree of available child elements will start from our present context:

```srl
--{ running }--[ interface mgmt0 subinterface 0 ]--
A:leaf1# tree
subinterface
+-- type
+-- description
+-- admin-state
+-- ip-mtu
+-- l2-mtu
+-- ipv4
|  +-- admin-state
# clipped
```

If you want to change the context of a given command you provide the context as an argument. Using the same `tree` command we can list the available child elements of the `system information` context by providing the absolute path to the target context:

```srl
--{ running }--[ interface mgmt0 subinterface 0 ]--
A:leaf1# tree /system information
information
+-- contact
+-- location
```

Even `show` commands that we will explore later are context-aware. For example, within our `[ interface mgmt0 subinterface 0 ]` context, the `show version` command that every NOS has will yield the error:

```srl
--{ running }--[ interface mgmt0 subinterface 0 ]--
A:leaf1# show version
Parsing error: Unknown token 'version'.
Options are ['#', '..', '/', '>', '>>', 'all', 'brief', 'detail', 'queue-detail', '|', '}']
```

And that is because in the current context there is no `version` command that `show` can execute. The `version` show report belongs to the root context, so to successfully execute it we need to be in the root context, or provide the fully-qualified-context-path:

```srl
--{ running }--[ interface mgmt0 subinterface 0 ]--
A:leaf1# show / version
-----------------------------------------------------
Hostname             : leaf1
Chassis Type         : 7220 IXR-D2L
Part Number          : Sim Part No.
Serial Number        : Sim Serial No.
# clipped
```

[^1]: For the sake of simplicity, we will not go into the details of the candidate datastore types in the quickstart. Refer to the official documentation for more information.
[^2]: We will cover the interface/subinterface model in more detail later.
