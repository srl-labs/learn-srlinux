# 2. CLI interface
The CLI is an interface for configuring, monitoring, and maintaining the SR Linux. This chapter describes basic features of the CLI and how to use them.

## 2.1. Accessing and using the CLI
### 2.1.1. Accessing the CLI
After the SR Linux device is initialized, you can access the CLI using a console or SSH connection. See the SR Linux hardware documentation for information about establishing a console connection and enabling and connecting to an SSH server.

Use the following command to connect to the SR Linux and open the CLI using SSH:
```
ssh admin@<IP Address>
```

**Example:**
```
$ ssh admin@172.16.0.3
Hello admin,
Welcome to the srlinux CLI.
Type 'help' (and press <ENTER>) if you need any help using this.
--{ running }--[ ]--
```

### 2.1.2. Using the CLI help functions
The CLI help functions (? and help) can assist in understanding command usage and indicate which configuration mode you are in.

Enter a question mark (?) after a command to display the command usage. For example, entering a question mark after the command network-instance, shows its usage.

Example 1:
```
# network-instance ?
usage: network-instance <name>
Network instances configured on the local system
Positional arguments:
  name              [string] A unique name identifying the network instance
--{ running }--[  ]-- 
```

Example 2:

Enter help at the top level to show the current configuration mode and details on other configuration modes. For more information about configurations, see Configuration modes.
```
# help
--------------------------------------------------------------------------------
You are now in the running mode.
Here you can navigate and query the running configuration.
This configuration has been validated, committed and send to the applications.
There are multiple modes you can enter while using the CLI.
Each mode offers its own set of capabilities:
    - running mode: Allows traversing and inspecting of the running configuration.
    - state mode: Allows traversing and inspecting of the state.
    - candidate mode: Allows editing and inspecting of the configuration.
    - show mode: Allows traversing and executing of custom show routines.
To switch mode use 'enter <mode-name>', e.g. 'enter candidate'
To navigate around, you can simply type the node name to enter a context, while
'exit [all]' is used to navigate up.
'{' and '}' are an alternative way to enter and leave contexts.
'?' can be used to see all possible commands, or alternatively,
'<TAB>' can be used to trigger auto-completion.
'tree' displays the tree of possible nodes you can enter.
--------------------------------------------------------------------------------
--{ * running }--[  ]--
```

### 2.1.3. Using the CLI auto-complete function
To reduce keystrokes or aid in remembering a command name, use the CLI auto-complete function.

Enter a tab at any mode or level to auto-complete the next command level. If multiple options are available, a popup will appear.

- When a command is partially entered, the remainder of the command appears ahead of the prompt in lighter text. Press the Tab key to complete the command.  
    ![pic1](https://infocenter.nokia.com/public/SRLINUX213R1A/topic/com.srlinux.interfaceconfig/html/graphics/tab-nopopup.jpg)
- When the Tab key is pressed and there are multiple options, the options are shown:
    ![pic2](https://infocenter.nokia.com/public/SRLINUX213R1A/topic/com.srlinux.interfaceconfig/html/graphics/tab-wpopup.jpg)

### 2.1.4. Using the CLI
Use shortcuts to move the cursor on the command line, complete commands, and recall commands previously entered. Shortcuts can also make syntax correction easier. Table 3 lists common shortcuts.

Table 3:  CLI keyboard shortcuts  

<table>
<thead>
  <tr>
    <th>Task</th>
    <th>Keystroke</th>
  </tr>
</thead>
<tbody>

  <tr>
    <td>Move cursor to the beginning of the line</td>
    <td><kbd>Ctrl+A</kbd></td>
  </tr>

  <tr>
    <td>Move cursor to the end of the line</td>
    <td><kbd>Ctrl+E</kbd></td>
  </tr>

  <tr>
    <td>Move cursor one character to the right</td>
    <td><kbd>Ctrl+F</kbd> or Right arrow key</td>
  </tr>

  <tr>
    <td>Move cursor one character to the left</td>
    <td><kbd>Ctrl+B</kbd> or Left arrow key</td>
  </tr>

  <tr>
    <td>Move cursor forward one word</td>
    <td><kbd>Esc F</kbd></td>
  </tr>

  <tr>
    <td>Move cursor back one word</td>
    <td><kbd>Esc B</kbd></td>
  </tr>

  <tr>
    <td>Transpose the character to the left of the cursor with the character the cursor is placed on</td>
    <td><kbd>Ctrl+T</kbd></td>
  </tr>


  <tr>
    <td>Complete a partial command</td>
    <td>Enter the first few letters, then press the <kbd>Tab</kbd> key</td>
  </tr>

  <tr>
    <td>Recall previous entry in the buffer</td>
    <td><kbd>Page Up</kbd></td>
  </tr>

  <tr> 
    <td>Navigate one level up within a context. For example:
        <pre>
<code>--{running}--[interface ethernet-1/1 subinterface 1]--

# exit

--{running}--[interface ethernet-1/1]--</code>
        </pre>
    </td>
    <td>Type <code>exit</code></td>
  </tr>

  <tr> 
    <td>Return to the root context. For example:
        <pre>
<code>--{running}--[interface ethernet-1/1 subinterface 1]--

# exit all

--{running}--[ ]--</code>
        </pre>
    </td>
    <td>Type <code>exit all</code></td>
  </tr>
</tbody>
</table>

### 2.2.2. Setting the configuration mode
After logging in to the CLI, you are initially placed in running mode. Table 4 describes the commands to change between modes.

Table 4:    Commands to change configuration mode

| To enter this mode:                        | Type this command:                      |
| :----------------------------------------- | :-------------------------------------- |
| Candidate shared                           | `enter candidate`                       |
| Candidate mode for named shared candidate  | `enter candidate name <name>`           |
| Candidate private                          | `enter candidate private`               |
| Candidate mode for named private candidate | `enter candidate private name <name>`   |
| Candidate exclusive                        | `enter candidate exclusive`             |
| Exclusive mode for named candidate         | `enter candidate exclusive name <name>` |
| Running                                    | `enter running`                         |
| State                                      | `enter state`                           |
| Show                                       | `enter show`                            |

