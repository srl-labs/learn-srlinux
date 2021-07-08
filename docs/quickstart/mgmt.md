Nokia SR Linux is equipped with 100% YANG modelled management interfaces.
The supported management interfaces (CLI, JSON-RPC, and gNMI) access the common management API layer via a gRPC interface.  
Since all interfaces act as a client towards a common management API, SR Linux provides complete consistency across all the management interfaces with regards to the capabilities available to each of them.

## SR Linux CLI
The SR Linux CLI is an interactive interface for configuring, monitoring, and maintaining the SR Linux via an SSH or console session.

Throughout the course of this quickstart we will use CLI as our main configuration interface and leave the gNMI and JSON interfaces for the more advanced scenarios. For that reason, we describe CLI interface here in a bit more details than the other interfaces.

### Features
* **Output Modifiers.**  
  Advanced Linux output modifiers `grep`, `more`, `wc`, `head`, and `tail` are exposed directly through the SR Linux CLI.
* **Suggestions & List Completions.**  
  As commands are typed suggestions are provided.  Tab can be used to list options available.
* **Output Format.**  
  When displaying info from a given datastore, the output can be formatted in one of three ways:
    * **Text:** this is the default out, it is JSON-like but not quite JSON.
    * **JSON:** the output will be in JSON format.
    * **Table:** The CLI will try to format the output in a table, this doesn’t work for all data but can be very useful.
* **Aliases.**  
  An alias is used to map a CLI command to a shorter easier to remember command.  For example, if a command is built to retrieve specific information from the state datastore and filter on specific fields while formatting the output as a table the CLI command could get quite long.  
  An alias could be configured so that a shorter string of text could be used to execute that long CLI command.  Alias can be further enhanced to be dynamic which makes them extremely powerful because they are not limited to static CLI commands.



### Accessing the CLI
After the SR Linux device is initialized, you can access the CLI using a console or SSH connection.

Using the connection details provided by containerlab when we deployed the quickstart lab we can connect to any of the nodes via SSH protocol. For example, to connect to `leaf1`:

```
ssh admin@clab-quickstart-leaf1
```
```
Warning: Permanently added 'clab-quickstart-leaf1,2001:172:20:20::8' (ECDSA) to the list of known hosts.
admin@clab-quickstart-leaf1's password: 
Using configuration file(s): []
Welcome to the srlinux CLI.
Type 'help' (and press <ENTER>) if you need any help using this.
--{ running }--[  ]--
A:leaf1#
```

### Prompt
By default, the SR Linux CLI prompt consists of two lines of text, indicating with an asterisk whether the configuration has been modified, the current mode and session type, the current CLI context, and the host name of the SR Linux device, in the
following format:
```
--{ modified? mode_and_session_type }--[ context ]--
hostname#
```

Example:
```
--{ * candidate shared }--[ acl ]--
3-node-srlinux-A#
```

The CLI prompt is configurable and can be changed within the `environment prompt` configuration context.

In addition to the prompt, SR Linux CLI has a bottom toolbar. It appears at the bottom of the terminal window and displays:

* the current mode and session type
* whether the configuration has been modified
* the user name and session ID of the current AAA session
* and the local time

For example:
```
Current mode: * candidate shared     root (36)   Wed 09:52PM
```

## gNMI
The gRPC-based gNMI protocol is used for the modification and retrieval of configuration from a target device, as well as the control and generation of telemetry streams from a target device to a data collection system.

SR Linux can enable a gNMI server that allows external gNMI clients to connect to the device and modify the configuration and collect state information.

Supported gNMI RPCs are:

* Get
* Set
* Subscribe
* Capabilities

## JSON-RPC
The SR Linux provides a JSON-based Remote Procedure Call (RPC) for both CLI commands and configuration. The JSON API allows the operator to retrieve and set the configuration and state, and provide a response in JSON format. This JSON-RPC API models the CLI implemented on the system.

If output from a command cannot be displayed in JSON, the text output is wrapped in JSON to allow the application calling the API to retrieve the output. During configuration, if a TCP port is in use when the JSON-RPC server attempts to bind to it, the commit fails. The JSON-RPC supports both normal paths, as well as XPATHs.