# Get started with CLI plugin development

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>

As custom CLI plugins use the same infrastructure as the native commands, they get the same superpowers as the native commands. But with great power comes... some complexity.

This Getting Started guide will introduce you to the main concepts of CLI plugins development, and the rest of the documentation will help you nail down the details.

/// admonition | Prerequisites
    type: subtle-note

To follow along, you will need the following tools installed on your machine:

* [Containerlab](https://containerlab.dev/install/#quick-setup) v0.64.0 or later
* `git`
///

Learning CLI programmability by developing your own CLI plugin is the way to go. Today we will be building a simple **`show uptime`** command that will display the uptime of an SR Linux device and the UTC time it was last booted.

```srl
--{ running }--[  ]--
A:srl# show uptime
--------------------------------------------------------------------------
Uptime     : 1 days 0 hours 29 minutes 48 seconds
Last Booted: 2025-02-15T16:23:47.956Z
--------------------------------------------------------------------------
```

Nothing sophisticated, yet it provides a good starting point for you to get familiar with the most important building blocks of the CLI plugin development. The full code is available in the [uptime-cli-plugin](https://github.com/srl-labs/uptime-cli-plugin) repository.

/// details | Video tutorial
    type: subtle-note
For the fans of the video format:

-{{youtube(url='https://www.youtube.com/embed/NtBnldprxLE')}}-
///

## Setting up the environment

Spending some time on setting up the dev environment will greatly simplify code navigation and debugging. To assist you with the environment setup, our repo features a small script with some helper functions.  
Start with cloning the [uptime-cli-plugin](https://github.com/srl-labs/uptime-cli-plugin) project:

```
git clone https://github.com/srl-labs/uptime-cli-plugin.git
cd uptime-cli-plugin
```

Once in the project directory, checkout the `get-started` branch that contains just the blank project template:

```
git checkout get-started
```

Once checked out, you will find the following important directories and files:

* `run` - a bash script that contains helper functions to orchestrate various steps of the development process
* `cli.clab.yml` - a containerlab topology file that will be used to deploy the virtual lab
* `uptime` - a directory where we will put the source code of our CLI plugin
* `pyproject.toml` and `uv.lock` - project-specific configuration files for the Python project

Now it is time to create the dev environment. The `run` script runner has a one-shot command to create the environment:

```bash
./run setup-dev-env #(1)!
```

1. This commands does a few things:

    * ensures [uv](https://docs.astral.sh/uv/)[^1] is installed
    * creates a virtual lab with a single SR Linux node
    * installs Python and a few dependencies that match the virtual environment of the SR Linux node
    * copies the SR Linux package from the lab node to the `./private/srlinux` directory to make sure import paths are resolved in the IDE

In under 30 seconds, you will have a running SR Linux node and a fully functional Python development environment.

/// admonition | `.env` file
    type: tip

In the repo root you will find a `.env` file that contains the universal environment variables that ensure that the local `.venv` virtual environment is used during the development.

Load the environment variables by sourcing the `.env` file:

```bash
source .env
```

Now running `which python` will show the path to the Python executable in the virtual environment.

```
❯ which python
.venv/bin/python
```

///

And that's it! You are ready to write your first CLI plugin!

## Plugin structure

Now open the [`uptime/uptime.py`](https://github.com/srl-labs/uptime-cli-plugin/blob/get-started/uptime/uptime.py) file in your favorite IDE and let's have a look at what makes an empty CLI plugin:

```python
from srlinux.mgmt.cli import CliPlugin #(1)!


class Plugin(CliPlugin):
    """
    Adds `show uptime` command.

    Example output:

        --{ running }--[  ]--
        A:srl# show uptime
        ----------------------------------------------------------------------
        Uptime     : 0 days 6 hours 0 minutes 25 seconds
        Last Booted: 2024-10-24T03:31:50.561Z
        ----------------------------------------------------------------------
    """

    def load(self, cli, arguments):
        pass
```

1. As part of the dev env setup, we copy out the `srlinux` package from the SR Linux node to the `private/srlinux` directory. This is done to make sure that the import paths are resolved correctly in the IDE.

The CLI template only needs to have a class called `Plugin` that inherits from the `CliPlugin` with a `load` public method. The SR Linux CLI engine scans the user [directories](index.md#user-defined-commands) and loads all the plugins that match this signature.

All our dev work will be done in the `load` method, as this is the enclosing method that is called by the CLI engine.

## The `load` method

The `load` method of the `Plugin` class is the entry point for the CLI plugin. It is where you add your new CLI command to one of the CLI modes - `show`, `global` or `tools`.  
Since we want to create a `show uptime` command, we are going to "mount" our command to the `show` mode.

The `load` method signature is as follows:

```python
def load(self, cli, arguments)
```

where the `cli` argument is a `CliLoader` object that allows you to add your new command to the CLI tree. Here is how we add a command to the `show` mode:

```python
class Plugin(CliPlugin):
    # ...
    def load(self, cli, arguments):
        cli.show_mode.add_command(
            syntax=self._syntax(),
            schema=self._schema(),
            callback=self._print,
        )
```

The `add_command` method of the CLI mode receives the command definition arguments such as:

* `syntax` - how the command is structured syntactically
* `schema` - what schema defines the data that the command operates on
* `callback` - what function to call when the command is executed

Let's have a look at each of these arguments in more detail.

## Syntax

The command's syntax defines the command representation - its name, help strings and the arguments it accepts. To define a command syntax, we need to create an object of the `Syntax` class; this is what the `_syntax` method does:

```python
from srlinux.syntax import Syntax #(1)!

class Plugin(CliPlugin):
    # ...
    def _syntax(self):
        return Syntax(
            name="uptime",
            short_help="⌛ Show platform uptime",
            help="⌛ Show platform uptime in days, hours, minutes and seconds.",
            help_epilogue="📖 It is easy to wrap up your own CLI command. Learn more about SR Linux at https://learn.srlinux.dev",
        )
```

1. Do not forget to import the `Syntax` class from the `srlinux.syntax` module.

For our `show uptime` command we just define the command name and the help text in different flavors in the Syntax object.

/// details | Want to try out what we have so far?
    type: subtle-note
If you want to try the plugin in its current state, you need to comment out the two methods that we haven't defined yet.

```python
from srlinux.mgmt.cli import CliPlugin
from srlinux.syntax import Syntax


class Plugin(CliPlugin):
    def load(self, cli, arguments):
        cli.show_mode.add_command(
            syntax=self._syntax(),
            # schema=self._schema(),
            # callback=self._print,
        )

    def _syntax(self):
        return Syntax(
            name="uptime",
            short_help="⌛ Show platform uptime",
            help="⌛ Show platform uptime in days, hours, minutes and seconds.",
            help_epilogue="📖 It is easy to wrap up your own CLI command. Learn more about SR Linux at https://learn.srlinux.dev",
        )

```

Now save the changes in the `uptime/uptime.py` file and ssh into the SR Linux node:

```
ssh srl
```

Now, start typing `show upt` and you will see how CLI will autocomplete the command `show uptime` for you based on the syntax you defined. After you hit Tab and autocomplete the full command, hit <kbd>?</kbd> to see the help text:

```
--{ running }--[  ]--
A:srl# show uptime
usage: uptime

⌛ Show platform uptime in days, hours, minutes and seconds.

📖 It is easy to wrap up your own CLI command. Learn more about SR Linux at https://learn.srlinux.dev
```

Hey, that's what we wanted!

///

The syntax alone is not enough to make the command work. We need to define the schema and the callback.

## Schema

You might be wondering, what is a schema and why do we need it for such a simple thing as a CLI command?

For a given `show` command the schema **describes the data** that the command intends to print out. As per our intent, the `show uptime` command should print out two things

* the uptime of the SR Linux system
* and the last booted time.

But, still, why do we need a schema to print values? Can't we just use `print` and go about our day?

```python
print(f"Uptime: {uptime}")
```

The answer is that **a schema makes it possible to have multiple output formats** without implementing the logic for each of them. Have a look at all these formats that our `show uptime` command gets for free:

/// tab | default (tag/value)

```srl
--{ running }--[  ]--
A:srl# show uptime
--------------------------------------------------------------------------
Uptime     : 1 days 0 hours 29 minutes 48 seconds
Last Booted: 2025-02-15T16:23:47.956Z
--------------------------------------------------------------------------
```

///
/// tab | table

```srl
--{ running }--[  ]--
A:srl# show uptime | as table
+-----------------------------------+-----------------------------------+
|              Uptime               |            Last Booted            |
+===================================+===================================+
| 1 days 0 hours 32 minutes 29      | 2025-02-15T16:23:47.956Z          |
| seconds                           |                                   |
+-----------------------------------+-----------------------------------+
```

///
/// tab | json

```srl
--{ running }--[  ]--
A:srl# show uptime | as json
{
  "uptime": {
    "Uptime": "1 days 0 hours 30 minutes 56 seconds",
    "Last Booted": "2025-02-15T16:23:47.956Z"
  }
}
```

///

/// tab | yaml

```srl
--{ running }--[  ]--
A:srl# show uptime | as yaml
---
uptime:
  Uptime: 1 days 0 hours 30 minutes 42 seconds
  Last Booted: '2025-02-15T16:23:47.956Z'
```

///
/// tab | xml

```srl
--{ running }--[  ]--
A:srl# show uptime | as xml
<uptime xmlns="">
  <Uptime>1 days 0 hours 31 minutes 15 seconds</Uptime>
  <Last Booted>2025-02-15T16:23:47.956Z</Last Booted>
</uptime>
```

///

Without having a schema-modeled data structure, we would have to implement the logic for each of the output formats ourselves, which is quite some work.

Since our command has only two fields to display - uptime and last booted time - the schema can be defined simply as a container with two fields:

```
+-- uptime         (container)
  +-- uptime       (field)
  +-- last booted  (field)
```

Here is how we define the schema in our Python code:

```python hl_lines="8"
from srlinux.schema import FixedSchemaRoot #(1)!

class Plugin(CliPlugin):
    # ...
    def load(self, cli, arguments):
        cli.show_mode.add_command(
            syntax=self._syntax(),
            schema=self._schema(),
            callback=self._print,
        )

    def _schema(self):
        root = FixedSchemaRoot()
        root.add_child(
            "uptime",
            fields=[
                "Uptime",
                "Last Booted",
            ],
        )
        return root
```

1. Do not forget to add a new import statement for the `FixedSchemaRoot` function.

The creation of the schema in the `_schema` method consists of two parts:

1. The `FixedSchemaRoot` function creates a new schema root object.
2. The `add_child` method adds a new child to the schema root.
    In the `add_child` method, we can add either a list or a container element as a child. For the uptime command we don't have a use case for a list element, so we created a container named `uptime` with two fields inside of it.

Visually this process can be depicted as follows:

-{{ diagram(url='srl-labs/uptime-cli-plugin/main/diagrams/cli.drawio', title='Schema for the uptime command', page=1) }}-

## Callback

We described the syntax of the `show uptime` command and defined the schema for the data it operates on. The final task is to create the callback function - the one that gets called when the command is executed and does all the useful work.

We provide the callback function as the third argument to the `add_command` method and it is up to us how we call it. Most often the show commands will have the callback function named `_print`, as show commands print out some data to the output.

```python hl_lines="7"
class Plugin(CliPlugin):
    # ...
    def load(self, cli, arguments):
        cli.show_mode.add_command(
            syntax=self._syntax(),
            schema=self._schema(),
            callback=self._print,
        )
```

The signature of the callback function is rather uncomplicated:

```python
class Plugin(CliPlugin):
    # ...
    def _print(self, state, output, arguments, **_kwargs):
```

The `state` argument gives you access to the entire state engine. We will use it later to query the state data from the SR Linux system.

The `output` argument is a CLI output object which we will use to print out the data.

And the `arguments` contains the arguments that were passed to the command. The one argument that we care about is the `schema` argument that we supplied to the `add_command` method a few steps ago.

Almost every callback function of a show command performs these high-level steps:

1. Query the state data from the SR Linux system that is necessary for the command to build the desired output.
2. Populate the data structure modelled by the schema with the data retrieved from the state engine in step 1.
3. Set output styling for different parts of the schema elements so that a composite output may be displayed in the best possible way.
4. And finally print the output to the CLI.

Our simple `show uptime` command callback function has these steps exactly, with each method performing one of the steps.

```python
class Plugin(CliPlugin):
    # ...
    def _print(self, state, output, arguments, **_kwargs):
        self._fetch_state(state)
        data = self._populate_data(arguments)
        self._set_formatters(data)
        output.print_data(data)
```

### Fetching state

Our show command needs to display the uptime of the SR Linux system. To calculate the uptime, we need to find a leaf in the SR Linux state tree that contains the last booted time information. Using the last booted time, we can calculate the uptime by subtracting the last booted time from the current time.

You can find the leaf that contains the last booted time by browsing the SR Linux state tree in the following ways:

1. Using the CLI

    /// tab | `tree flat from state` with `grep`
    An efficient way to find the needed leaf if you know some keywords is to use the `info flat from state` command and pipe it to `grep`.  
    Since we know that we are looking for the time when the SR Linux system was last booted, we could use something like this:

    ```srl hl_lines="16"
    --{ running }--[  ]--
    A:srl# tree flat from state | grep last | grep boot
    platform chassis last-boot-type
    platform chassis last-booted
    platform chassis last-booted-reason
    platform control last-booted
    platform control last-booted-reason
    platform fan-tray last-booted
    platform fan-tray last-booted-reason
    platform linecard last-booted
    platform linecard last-booted-reason
    platform linecard forwarding-complex last-booted
    platform linecard forwarding-complex last-booted-reason
    platform power-supply last-booted
    platform power-supply last-booted-reason
    system information last-booted
    ```

    The path that contains the last booted time is `/ system information last-booted`.

    ///
    /// tab | Interactively with `enter state`
    You can also interactively browse the state of the SR Linux system using the `enter state` command.

    ```srl hl_lines="11"
    --{ running }--[  ]--
    A:srl# enter state

    --{ state }--[  ]--
    A:srl# system information

    --{ state }--[ system information ]--
    A:srl# info flat
    / system information description "SRLinux-v24.10.2-357-ga1dd6e02b5 7220 IXR-D2L Copyright (c) 2000-2020 Nokia. Kernel 6.12.13-orbstack-00304-gede1cf3337c4 #60 SMP Wed Feb 12 20:25:12 UTC 2025"
    / system information current-datetime "2025-02-17T10:58:16.579Z (now)"
    / system information last-booted "2025-02-17T10:50:35.471Z (7 minutes ago)"
    / system information version v24.10.2-357-ga1dd6e02b5
    ```

    ///

2. Using [YANG Browser](../../yang/browser.md)  
    SR Linux YANG Browser offers a very efficient and user-friendly way to browse the configuration and state of the SR Linux system. You may opt to use the Path Browser functionality and provide keywords, or open up the Tree Browser and explore the branches of the state tree until you find the needed leaf.

Regardless of the way you choose to browse the state tree, you will find the path to the last booted time leaf, which is `system information last-booted`.

Knowing the path to query, we can use it in the `_fetch_state` method like this:

```python
from srlinux.location import build_path #(1)!

class Plugin(CliPlugin):
    # ...
    def _fetch_state(self, state):
        last_booted_path = build_path("/system/information/last-booted")

        try:
            self._last_booted_data = state.server_data_store.get_data(
                last_booted_path, recursive=False
            )
        except ServerError:
            self._last_booted_data = None
```

1. Do not forget to add a new import statement for the `build_path` function.

Using the imported `build_path` function, we can convert the path to the object representation that SR Linux server expects.

Then we make use of the `state` argument that we passed to the method and query the state data from the SR Linux system by providing the path object to it.

We store the returned value (the last booted time of the system) in a private variable `_last_booted_data` as we will need it in the next steps.

### Populating data

Now that we acquired the last booted time information, we need to create a data structure modeled after the schema we defined earlier and fill it with the data we want to display.

This is how we do it in the `_populate_data` method:

```python
from srlinux.data import Data

class Plugin(CliPlugin):
    # ...
    def _populate_data(self, arguments):
        data = Data(schema=arguments.schema)

        uptime_container = data.uptime.create()

        uptime_container.last_booted = (
            self._last_booted_data.system.get().information.get().last_booted
        )

        uptime_container.uptime = _calculate_uptime(uptime_container.last_booted)

        return data
```

To create the data structure, we use the `Data` class from the `srlinux.data` module. The constructor of this class takes in a schema and returns an empty Data object that is modeled after the schema. Once we created the Data object from a schema, we need to instantiate the `uptime` container that encloses our fields. We do this with the `create` method like so:

This two-step process is visualized in the following diagram:

-{{ diagram(url='srl-labs/uptime-cli-plugin/main/diagrams/cli.drawio', title='Creating the Data object and initializing the container', page=2) }}-

What we want now is to populate the `uptime_container` Data object fields with the values:

1. The last booted time as fetched from the SR Linux state.
2. The uptime string value calculated as the difference between the current time and the last booted time.

Recall, that we stored the last booted time in the `_last_booted_data` private variable of our plugin object, but it is being kept not as scalar value, but as a Data object. To get access to the value, we need to use the `get` method and traverse the data structure:

Here is a visual aid for this process:

-{{ diagram(url='srl-labs/uptime-cli-plugin/main/diagrams/cli.drawio', title='Accessing fields of the Data object', page=3) }}-

Note, that when we queried the state engine for the `/system information last-booted` leaf, we got the Data object back with the `last-booted` field nested under its parent containers. Hence, we needed to traverse this path using attribute accessors to retrieve the data. The attributes we used to reach the `last-booted` leaf match the names of the containers in the YANG schema of SR Linux.

After we got our `last-booted` value, we can use it to calculate the uptime value:

```python
class Plugin(CliPlugin):
    # ...
    def _populate_data(self, arguments):
        # ...
        uptime_container.uptime = _calculate_uptime(uptime_container.last_booted)
```

The `_calculate_uptime` function we write ourselves and are free to choose the representation of the uptime value. For example, we chose to display the uptime as a human-readable string - e.g. "0 days 1 hours 16 minutes 4 seconds".

> The function itself is irrelevant for this tutorial, feel free to check it out in the [repository](https://github.com/srl-labs/uptime-cli-plugin).

The calculated value we write to the `uptime_container` object and in the end return the `data` object that we initialized in the beginning of this function.

```python
from srlinux.data import Data

class Plugin(CliPlugin):
    # ...
    def _populate_data(self, arguments):
        data = Data(schema=arguments.schema)
        # ...
        return data
```

### Adding formatters

Once the data object is populated with the computed and fetched data, we need to specify what format we want this data to be printed in. This is the task for the formatters.

Formatters drive the way each container or list of the Data object is printed. There are several types of formatters that are available to the user:

1. **Tag/value formatter**  
    Print the data as simple tag/value (or key/value) pairs. Typically used for simple, flat data structures. For example, `show version` uses this formatter.
2. **Table formatter**  
    Print the data in a tabular format. Speaks for itself, an example is `show interfaces brief`.
3. **Custom formatter**  
    For more elaborated output, you can define your own formatter that prints the data in a way you want while still using the schema and benefitting from the automated format conversion to various output flavors. See `show interface` command implementation for an example.

> Keep an eye on the documentation updates; we will add a detailed guide for the custom formatters.

```python hl_lines="8"
from srlinux.data import Border, Data, TagValueFormatter

class Plugin(CliPlugin):
    # ...
    def _print(self, state, output, arguments, **_kwargs):
        self._fetch_state(state)
        data = self._populate_data(arguments)
        self._set_formatters(data)
        output.print_data(data)

    def _set_formatters(self, data):
        data.set_formatter(
            schema="/uptime",
            formatter=Border(TagValueFormatter(), Border.Above | Border.Below),
        )
```

The formatters are set using the `set_formatter` method of the Data object. The first argument is the path to the schema node that we want to bind a formatter to. The second argument is the formatter object.  
We will use a simple `TagValueFormatter` function that prints the data as tag/value pairs and we will wrap it with borders using the `Border` decorator.

This will give us the desired output:

```
--------------------------------------------------------------------------
Uptime     : 1 days 0 hours 29 minutes 48 seconds
Last Booted: 2025-02-15T16:23:47.956Z
--------------------------------------------------------------------------
```

> Note, that we apply the formatter to either a container or list element. In our case, it is the `uptime` container that we defined in our schema.

### Printing output

The last step is the simplest one. We wanted to print our Data object with the formatter we added earlier. All it takes is to use the `output` argument that is passed by the CLI engine to the callback function:

```python hl_lines="7"
class Plugin(CliPlugin):
    # ...
    def _print(self, state, output, arguments, **_kwargs):
        self._fetch_state(state)
        data = self._populate_data(arguments)
        self._set_formatters(data)
        output.print_data(data)
```

And that's it! If you followed along, you will see you uptime data printed to the screen.

## Summary

We have created a simple CLI plugin that prints the uptime of the system and added it to the CLI as if it was a built-in command.

/// admonition | What about the types?
    type: subtle-note
You may have noticed that we did not use type hinting/annotations when explaining the project' code. This was on purpose, as we wanted to focus on the concepts.

But we strongly suggest you use type hinting in your code, as we did in the [`upstream.py`](https://github.com/srl-labs/uptime-cli-plugin/blob/main/uptime/uptime.py) file. The non-type hinted code that we used in this tutorial is saved as [`uptime_simple.py`](https://github.com/srl-labs/uptime-cli-plugin/blob/main/uptime/uptime_simple.py) file.
///

Our command uses the same plugin infrastructure as SR Linux's native commands, and used the state engine to query the state of the system to get the last booted time value that is used in the uptime calculation function.

The CLI Plugin infrastructure allows you to create commands that make operational sense to you whenever you want it, without any vendor involvement. It provides the full visibility into the system and makes it easy to get the data with all the output formats SR Linux supports - text, table, json, yaml, xml, etc.

The `show uptime` is obviously a very simple example used for introduction purposes, you can explore [existing show commands](index.md#native-commands) to have an idea of what it takes to create a more complex and feature rich commands.

[^1]: `uv` is a modern tool to manage python virtual environments and packages.
