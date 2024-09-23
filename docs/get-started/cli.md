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

<figure>
  <div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":0,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/srl-labs/srlinux-getting-started/main/diagrams/get-started.drawio"}'></div>
  <figcaption>Default SR Linux prompt</figcaption>
</figure>

The prompt' picture title reads "default", because it is highly customizable. For the purpose of this guide, we will use the default prompt and leave prompt customization for later. The annotations in the picture provide a brief explanation of each part of the prompt, and we provide a more detailed through the rest of this guide.

## Getting around CLI

When you first log into an unknown OS, you want to know what commands are available to you. In SR Linux, there are several contex-aware help commands and key bindings that can help you navigate the CLI.

Hitting the <kbd>?</kbd> in the CLI will list all available **local** commands:

```srl
--{ running }--[  ]--
A:leaf1# <pressed ? character>
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

Local commands are actual configuration elements available in the present working context. See this `[  ]` in the prompt? That means the user is in root context, and local commands that are available in the `running` mode for the root context are listed.

If you press <kbd>?</kbd> again, you will see all available commands, local and global:

```srl
--{ running }--[  ]--
A:leaf1# <pressed ? character> <pressed ? character again>
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

## CLI modes

SR Linux CLI has three main modes that a user can be in:

* running
* candidate (aka configuration)
* state

### Running

When a user logs into SR Linux, they start in the `running` mode. This is the mode in which the user can use operational and show commands, view configuration and perform actions via `/tools` commands, but they cannot perform any configuration changes.

/// admonition | Similar to...
    type: subtle-note
This mode is similar to the enable mode (in Cisco/Arista) or the operational mode (Juniper Junos). The prompt and the toolbar show `running` when the user is in this mode.
///

As said, in this mode a user can execute operational and show commands. To give you a few examples:

/// tab | `ping`

```srl
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

The `candidate` mode is the mode in which the user can perform configuration changes in the candidate datastore. To enter this mode, type `enter candidate`
