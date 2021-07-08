SR Linux employs a transaction-based configuration management system. That allows for a number of changes to be made to the configuration with an explicit `commit` required to apply the changes as a single transaction.

## Configuration file
The default location for the configuration file is `/etc/opt/srlinux/config.json`.

If there is no configuration file present, a basic configuration file is auto-generated with the following defaults:

* Creation of a management network instance
* Management interface is added to the mgmt network instance
* DHCP v4/v6 is enabled on mgmt interface
* A set of default of logs are created
* SSH server is enabled
* Some default IPv4/v6 CPM filters

## Configuration modes

Configuration modes define how the system is running when transactions are performed. Supported modes are the following:

* **Running:** the default mode when logging in and displays displays the currently running or active configuration.
* **State:** the running configuration plus the addition of any dynamically added data.  Some examples of state specific data are operational state of various elements, counters and statistics, BGP auto-discovered peer, LLDP peer information, etc.
* **Candidate:** this mode is used to modify configuration. Modifications are not applied until the `commit` is performed. When committed, the changes are copied to the running configuration and become
active. The candidate configuration configuration can itself be edited in the following modes:
    * *Shared:* this is the default mode when entering the candidate mode with `enter candidate` command.  This allows multiple users to modify the candidate configuration concurrently. When the configuration is committed, the changes from all of the users are applied.
    * *Exclusive Candidate:* When entering candidate mode with `enter candidate exclusive`, it locks out other users from making changes to the candidate configuration.  
      You can enter candidate exclusive mode only under the following conditions:  
        * The current shared candidate configuration has not been modified.
        * There are no other users in candidate shared mode.
        * No other users have entered candidate exclusive mode.
    * *Private:* A private candidate allows multiple users to modify a configuration; however when a user commits their changes, only the changes from that user are committed.  
      When a private candidate is created, private datastores are created and a snapshot is taken from the running database to create a baseline. When starting a private candidate, a default candidate is defined per user with the name `private-<username>` unless a unique name is defined.

!!!note
    gNMI & JSON-RPC both use an exclusive candidate and an implicit commit when making a configuration change on the device.

## Setting the configuration mode
After logging in to the CLI, you are initially placed in `running` mode. The following table provides commands to enter in a specific mode:

| Candidate mode                             | Command to enter                        |
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

## Committing configuration
Changes made during a configuration modification session do not take effect until a `commit` command is issued. Several options are available for `commit` command, below are the most notable ones:

| Option             | Action                                                                                                                                                                                          |
| :----------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `commit now`       | Apply the changes, exit candidate mode, and enter running mode                                                                                                                                  |
| `commit stay`      | Apply the changes and then remain in candidate mode                                                                                                                                             |
| `commit save`      | Apply the changes and automatically save the commit to the startup configuration                                                                                                                |
| `commit confirmed` | Apply the changes, but requires an explicit confirmation to become permanent. If the explicit confirmation is not issued within a specified time period, all changes are automatically reverted |

## Deleting configuration
Use the `delete` command to delete configurations while in candidate mode.

The following example displays the system banner configuration, deletes the configured banner, then displays the resulting system banner configuration:
```linenums="1"
--{ candidate shared default}--[ ]--
A:leaf1# info system banner
    system {
        banner {
            login-banner "Welcome to SRLinux!"
        }
    }

--{ candidate shared default}--[ ]--
A:leaf1# delete system banner

--{ candidate shared default}--[ ]--
A:leaf1# info system banner
    system {
        banner {
        }
    }
```

## Discarding configuration
You can discard previously applied configurations with the `discard` command.

* To discard the changes and remain in candidate mode with a new candidate session, enter `discard stay`.
* To discard the changes, exit candidate mode, and enter running mode, enter `discard now`.

## Displaying configuration diff
Use the `diff` command to get a comparison of configuration changes. Optional arguments can be used to indicate the source and destination datastore.

The following use rules apply:
* If no arguments are specified, the diff is performed from the candidate to the baseline of the candidate.
* If a single argument is specified, the diff is performed from the current candidate to the specified candidate.
* If two arguments are specified, the first is treated as the source, and the second as the destination.

Global arguments include: `baseline`, `candidate`, `checkpoint`, `factory`, `file`, `from`, `rescue`, `running`, and `startup`.

The diff command can be used outside of candidate mode, but only if used with arguments.

The following shows a basic `diff` command without arguments. In this example, the description and admin state of an interface are changed and the differences shown:
```linenums="1"
--{ candidate shared default }--[ ]--
# interface ethernet-1/1 admin-state disable

--{ * candidate shared default }--[ ]--
# interface ethernet-1/2 description "updated"

--{ * candidate shared default }--[ ]--
# diff
    interface ethernet-1/1 {
+       admin-state disable
    }
+   interface ethernet-1/2 {
+       description updated
+   }
```

## Displaying configuration details
Use the `info` command to display the configuration. Entering the info command from the root context displays the entire configuration, or the configuration for a specified context. Entering the command from within a context limits the display to the configuration under that context.

To display the entire configuration, enter `info` from the root context:
```
--{ candidate shared default}--[ ]--
# info
<all the configuration is displayed>
--{ candidate }--[ ]--
```

To display the configuration for a specific context, enter info and specify the context:
```
--{ candidate shared default}--[ ]--
# info system lldp
    system {
        lldp {
            admin-state enable
            hello-timer 600
            management-address mgmt0.0 {
                type [
                    IPv4
                ]
            }
            interface mgmt0 {
                admin-state disable
            }
        }
    }
```

The following `info` command options are rather useful:

* `as-json` - to display JSON-formatted output
* `detail` - to display values for all parameters, including those not specifically configured
* `flat` -  to display the output as a series of set statements, omitting indentation for any sub-contexts
