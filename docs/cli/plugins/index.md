# CLI Plugins

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>

[SR Linux CLI](../index.md) is an open-source, Python-based, and pluggable engine. This means that you can extend the CLI with your own commands whenever you need to.

Ever wanted to create a CLI command that would make your operational life easier but is too specific to be included in the default CLI command tree? The CLI Plugins is the answer.

The pluggable architecture of our CLI allows you to create your own CLI commands whenever you need it that use the same infrastructure as the commands SR Linux ships with.

The Python-based CLI engine allows a user to create the custom CLI commands in the the following categories:

* **show** commands.  
    These are your much-loved `show` commands that print out the state of the system in a human-readable format, often in sort of a table.
* **global** commands  
    These are operational commands like `ping`, `traceroute`, `file`, `bash`, etc.
* **tools** commands  
    Often represent a run-to-completion task or an operation. Like a reboot or a request to load a configuration from a file.

-{{ diagram(url='srl-labs/uptime-cli-plugin/main/diagrams/cli.drawio', title='CLI engine and its plugin architecture', page=0) }}-

> The configuration commands are not implemented as CLI plugins, they directly modify the candidate configuration datastore and are not subject to customization.

As shown in the diagram above, the CLI plugins infrastructure is used to support both SR Linux native and custom commands. Users can add their own command simply by putting a Python file in one of the directories used in the CLI plugin discovery process.

When SR Linux CLI is started, the available commands (native and user-defined) are loaded by the engine based on the plugin discovery process that scans the known directories for Python files implementing the `CliPlugin` interface.

## Native commands

The native commands, such as `show interface brief`, `diff` or `tools system configuration save`, are plugins implemented in exactly same way as the custom commands the users create. What makes them different is that they are shipped with the SR Linux image and make up the core of the CLI.

The native commands can be found in the following directory:

```
/opt/srlinux/python/virtual-env/lib/python3.11/dist-packages/srlinux/mgmt/cli/plugins
```

The native commands are part of the `srlinux` Python package located in the virtual environment. For brevity, hereafter we will refer to the directory containing the native commands as just `<srl-venv>/srlinux/mgmt/cli/plugins`.

If you list the contents of this directory, you will recognize some commands that are implemented as Python files:

```bash title="An incomplete list of native plugins"
ls -l \
/opt/srlinux/python/virtual-env/lib/python3.11/dist-packages/srlinux/mgmt/cli/plugins
```

<div class="embed-result">
```
-rw-r--r-- 1 root root 27199 Jan 23 23:35 alias.py
-rw-r--r-- 1 root root 16334 Jan 23 23:35 commit.py
-rw-r--r-- 1 root root  1495 Jan 23 23:35 echo.py
-rw-r--r-- 1 root root  4900 Jan 23 23:35 ping.py
drwxr-xr-x 1 root root  8704 Jan 24 01:01 reports
-rw-r--r-- 1 root root  4117 Jan 23 23:35 tools.py
-rw-r--r-- 1 root root  3874 Jan 23 23:35 traceroute.py
-rw-r--r-- 1 root root  7620 Jan 23 23:35 tree.py
```
</div>

You can make an educated guess that the files in the listing are CLI plugins that implement the corresponding functionality.  
The `alias.py` file implements the `alias` command. And the `tools.py` file adds support for the `tools` command.

The only directory in the listing above - `reports`[^1] - contains plugin files that share a common trait - they all implement the relevant `show` commands:

```title="An incomplete list of show plugins"
-rw-r--r-- 1 root root  3330 Jan 23 23:35 acl_reports.py
-rw-r--r-- 1 root root 20324 Jan 23 23:35 bgp_ipv4_exact_route_detail_report.py
-rw-r--r-- 1 root root 61888 Jan 23 23:35 bgp_neighbor_detail_report.py
-rw-r--r-- 1 root root  4251 Jan 23 23:35 interface_reports.py
-rw-r--r-- 1 root root 20812 Jan 23 23:35 ospf_interface_report.py
-rw-r--r-- 1 root root 12257 Jan 23 23:35 platform_reports.py
-rw-r--r-- 1 root root  6476 Jan 23 23:35 power_component_report.py
-rw-r--r-- 1 root root  2968 Jan 23 23:35 redundancy_report.py
-rw-r--r-- 1 root root   569 Jan 23 23:35 system.py
-rw-r--r-- 1 root root  6578 Jan 23 23:35 version.py
```

The `version.py` file contains the code that is called when the `show version` command is executed; the `system.py` implements the `show system` command and its subcommands, and so on.

As a user of SR Linux, you can dive into the code of the native commands and see how they are implemented.

/// admonition | Note
    type: subtle-note
You can even tune the native commands to your liking by modifying the source code, but be aware that the changes made to the existing native commands will be overwritten when you upgrade the SR Linux image.
///

## User-defined commands

The user-defined (aka custom) commands are implemented in the same way as the native commands. The only difference is that they are not part of the SR Linux image, but are created by the user.

There are two paths where the user-defined commands can be located:

1. **System-wide user commands**  
    When a plugin is installed in the the following directory, it is available system-wide:

    ```
    /etc/opt/srlinux/cli/plugins
    ```

    The commands implemented by the plugins in this directory are available to all users of the SR Linux system[^2].

2. **Per-user commands**  
    To make a command available to a specific user, the plugin file should be placed in the user's home directory:

    ```
    /home/<username>/cli/plugins
    ```

The user-defined commands (both with system-wide and per-user scope) are kept intact during the SR Linux image upgrade. Hence, it is important to make sure that the custom plugins are stored in the appropriate directory.

So, what it takes to create a new command? How to setup the environment for the plugin development? And how to test the command? Let us take you on a quick tour of the plugin development process outlined in the Getting Started section.

:octicons-arrow-right-24: [Getting started](getting-started.md)

[^1]: full path to the directory - `/opt/srlinux/python/virtual-env/lib/python3.11/dist-packages/srlinux/mgmt/cli/plugins/reports`
[^2]: plugin access can be narrowed down using the plugin authorization AAA mechanism
