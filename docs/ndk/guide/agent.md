As was explained in the [NDK Architecture](architecture.md) section, an agent[^1] is a custom software that can extend SR Linux capabilities by running alongside SR Linux native applications and performing some user-defined tasks.

To deeply integrate with the rest of the SR Linux architecture the agents have to be defined like an application that SR Linux's application manager can take control of. The structure of the agents is the main topic of this chapter.

The main three components of an agent:

1. Agent's executable file
2. YANG module
3. Agent configuration file

## Executable file
An executable file is called when the agent starts running on SR Linux system. It contains the application logic and is typically an executable binary or a script.

The application logic takes care of handling the agents configuration that may be provided via any of the management interfaces (CLI, gNMI, etc), and contains the core logic of interfacing with gRPC based NDK services.

In the subsequent sections of the Developers Guide we will cover how to write the logic of an agent and interact with various NDK services.

An executable file can be placed at `/usr/local/bin` directory.

## YANG module
SR Linux is a fully modelled Network OS. As a result, any native or custom application that is meant to be configurable or to have state is required to have a proper YANG model.

The "cost" associated with requiring users to write YAN
G models for their apps pays off greatly as this

* enables seamless integration of an agent with **all** management interfaces: CLI, gNMI, JSON-RPC.  
    Any agent's configuration knobs that users expressed in YANG will be immediately available in the SR Linux CLI, as if it was part of it from the beginning. Yes, with auto-suggestion of the fields as well.
* provides out-of-the-box Streaming Telemetry (gNMI) support for any config or state data that agent maintains

And secondly, the YANG modules for custom apps are not that hard to write as their data model is typically rather small.

!!!note
    YANG module is only needed if a developer wants their agent to be configurable via any of the management interfaces or to keep state.

YANG files that are related to the particular agent can be placed by the `/opt/$agentName/yang` directory.

## Configuration file
Due to SR Linux modular architecture, each application, be it internal app like `bgp` or a custom NDK agent, needs to have a configuration file. This file contains application parameters which are read by the Application Manager service to onboard the application onto the system.

With agent's config file users define important properties of an application, for example:

* application version
* location of the executable file
* YANG modules related to this app
* lifecycle management policy
* and others

Custom agents must have their config file present by the `/etc/opt/srlinux/appmgr` directory. It is a good idea to name agent config file after the agent name, so if we, say, named our agent `myCoolAgent`, then its config file can be named as `myCoolAgent.yml` under the `/etc/opt/srlinux/appmgr` directory.

Through the subsequent chapters of the Developers Guide we will cover the most important options, but here is a full list of config file parameters:

???info "Full list of config files parameters"
    ```yaml
    # Example configuration file for the applications on sr_linux
    # All valid options are shown and explained
    # The name of the application.
    # This must be unique.
    application-name:
        # [Mandatory] The source path where the binary can be found
        path: /usr/local/bin
        # [Optional, default='./<application-name>'] The command to launch the application.
        # Note these replacement rules:
        #   {slot-num} will be replaced by the slot number the process is running on
        #   {0}, {1}, ... can be replaced by parameters provided in the launch request (launch-by-request: Yes)
        launch-command: "VALUE=2 ./binary_name --log-level debug"
        # [Optional, default='<launch-command>'] The command to search for when checking if the application is running.
        # This will be executed as a prefix search, so if the application was launched using './app-name -loglevel debug'
        # a search-command './app-name' would work.
        # Note: same replacement rules as launch-command
        search-command: "./binary_name"
        # [Optional, default=No] Indicates whether the application needs to be launched automatically
        never-start: No
        # [Optional, default=No] Indicates whether the application can be restarted automatically when it crashes.
        # Applies only when never-start is No (if the app is not started by app_mgr it would not be restarted either).
        # Applications are only restarted when running app_mgr in restart mode (e.g. sr_linux --restart)
        never-restart: No
        # [Optional, default=No] Indicates whether the application will be shown in app manager status
        never-show: No
        # [Optional, default=No] Indicates whether the launch of the application is delayed
        # until any configuration is loaded in the application's YANG modules.
        wait-for-config: No
        # [Optional] Indicates the application is run as 'user' including 'root'
        run-as-user: root
        # [Optional, default=200] Indicates the order in which the application needs to be launched.
        # The applications with the lowest value are launched first.
        # Applications with the same value are launched in an undefined order.
        # By convention, start-order >= 100 require idb.  1 is reserved for device-mgr, which determines chassis type.
        start-order: 123
        # [Optional, default=No] Indicates whether this application is launched via an request (idb only at this point).
        launch-by-request: No
        # [Optional, default=No] Indicates whether this application is launched in a net namespace (launch-by-request
        # must be set to Yes).
        launch-in-net-namespace: No
        # [Optional, default=3] Indicates the number of restarts within failure-window which will trigger the system restart
        failure-threshold: 3
        # [Optional, default=300] Indicates the window in seconds over which to count restarts towards failure-threshold
        failure-window: 400
        # [Optional, default=reboot] Indicates the action taken after 'failure-threshold' failures within 'failure-window'
        failure-action: 'reboot'
        # [Optional, default=Nokia] Indicates the author of the application
        author: 'Nokia'
        # [Optional, default=””] The command for app_mgr to run to read the application version
        version-command: 'snmpd --version'
        # [Optional The operations that may not be manually performed on this application
        restricted-operations: ['start', 'stop', 'restart', 'quit', 'kill']
        # [Optional, default No] app-mgr will wait for app to acknowledge it via oob channel
        oob-init: No
        # [Optional] The list of launch restrictions - if of all of the restrictions of an element in the list are met,
        # then the application is launched.  The restrictions are separated by a ':'.  Valid restrictions are:
        #   'sim' - running in sim mode (like in container env.)
        #   'hw' - running on real h/w
        #   'chassis' - running on a chassis (cpm and imm are running on different processors)
        #   'imm' - runs on the imm
        #   'cpm' - runs on the cpm (default)
        launch-restrictions: ['hw:cpm', 'hw:chassis:imm']
        yang-modules:
            # [Mandatory] The names of the YANG modules to load. This is usually the file-name without '.yang'
            names: [module-name, other-module-name]
            # [Optional] List of enabled YANG features. Each needs to be qualified (e.g. srl_nokia-common:foo)
            enabled-features: ['module-name:foo', 'other-module-name:bar']
            # [Optional] The names of the YANG validation plugins to load.
            validation-plugins: [plugin-name, other-plugin-name]
            # [Mandatory] All the source-directories where we should search for:
            #    - The YANG modules listed here
            #    - any YANG module included/imported in these modules
            source-directories: [/path/one, /path/two]
            # [Optional] The names of the not owned YANG modules to load for commit confirmation purposes.
            not-owned-names: [module-name, other-module-name]
    # [Optional] Multiple applications can be defined in the same YAML file
    other-application-name:
        command: "./other-binary"
        path: /other/path
    ```

## Dependency and other files
Quite often an agent may require additional files for its operation. It can be a specific virtual environment for your Python agent, or some JSON file that your agents reads some data from.

All those auxiliary files can be saved by the `/opt/$agentName/` directory.

[^1]: terms NDK agent and NDK app are used interchangeably