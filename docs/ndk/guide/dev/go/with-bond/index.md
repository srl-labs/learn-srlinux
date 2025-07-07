# Developing Go NDK applications with Bond

The [**`srl-labs/bond`**][bond-repo] package is a helper Go package that abstracts the low-level NDK API and assists in the development of the NDK applications. It is a wrapper around the NDK gRPC services with utility functions that were designed to provide a more pleasant development experience.

We recommend users to develop their apps with the `bond` package and resort to the barebones NDK API only when the `bond` package is not sufficient.

The development environment that we will use in this tutorial is [covered in the introduction](../index.md#development-environment) to the Go NDK development guide.

## Deploying the lab

Before taking a deep dive into the code, let's deploy the [`greeter`][greeter-go-repo] app to SR Linux using [containerlab][clab-home] and see how it works.

/// details | Containerlab for NDK
    type: subtle-note
When developing NDK applications, it is important to have a lab environment to test the application. The lab environment should be as close as possible to the production environment and also be easy to spin up and tear down.

The [Containerlab][clab-home] tool is a perfect fit for this purpose. Containerlab makes it easy to create a personal lab environment composed of network devices and connected by virtual links. We are going to use Containerlab to create a lab environment for the `greeter` NDK application development down the road.
///

It all starts with cloning the [`srl-labs/ndk-greeter-go`][greeter-go-repo] repo:

```bash
git clone https://github.com/srl-labs/ndk-greeter-go.git && \
cd ndk-greeter-go
```

/// note
    attrs: {class: inline end}
[Containerlab v0.68.0](https://containerlab.dev/install) version, `srl-labs/bond` v0.3.0 and SR Linux 25.3 are used in this tutorial. Users are advised to use these version to have the same outputs as in this tutorial.

Newer versions of Containerlab and SR Linux should work as well, but the outputs might be slightly different.
///

And then running the deployment script:

```bash
./run.sh deploy-all #(1)!
```

1. `deploy-all` script builds the `greeter` app, deploys a containerlab topology file, and installs the app on the running SR Linux node.

It won't take you longer than 30 seconds to get the `greeter` app up and running on a freshly deployed lab. Type `ssh greeter` and let's configure our greeter app:

```bash
❯ ssh greeter #(1)!
Warning: Permanently added 'greeter' (ED25519) to the list of known hosts.

Welcome to the srlinux CLI.
Type 'help' (and press <ENTER>) if you need any help using this.

--{ running }--[  ]--
A:greeter#
```

1. Containerlab injects host routes and SSH config on your system to allow you to connect to the lab nodes using only its name.

Once connected to the `greeter` SR Linux node, let's configure the app:

```srl
--{ running }--[  ]--
A:greeter# enter candidate

--{ candidate shared default }--[  ]--
A:greeter# greeter

--{ candidate shared default }--[ greeter ]--
A:greeter# name "Learn SR Linux Reader"

--{ * candidate shared default }--[ greeter ]--
A:greeter# commit stay
All changes have been committed. Starting new transaction.
```

Now that we've set the `name` value, let's verify that the name is indeed set in the candidate configuration and running datastore:

```srl
--{ + candidate shared default }--[ greeter ]--
A:greeter# info from running
    name "Learn SR Linux Reader"
```

Look at that, the `greeting` value is not there. That's because the `greeting` is a state leaf, it is only present in the state datastore. Let's check it out, while we're in the `/greeter` context we can use `info from state` command to get the state of the current context:

```srl
--{ + candidate shared default }--[ greeter ]--
A:greeter# info from state
    name "Learn SR Linux Reader"
    greeting "👋 Hi Learn SR Linux Reader, I am SR Linux and my uptime is 108h33m7s!"
```

As advertised, the greeter app greets us with a message that includes the `name` value we've set, and the uptime of the SR Linux node. Should you change the `name` value and commit the configuration, you will see the new `greeting` message.

Now let's go and see how this app is written, starting with the project structure.

## Project structure

The project structure is a matter of personal preference. There are no strict rules on how to structure a Go project. However, there are some best practices we can enforce making the NDK project structure more consistent and easier to understand.

This is the project structure used in this tutorial:

```bash
❯ tree
.
├── LICENSE
├── README.md
├── build #(1)!
├── go.mod
├── go.sum
├── goreleaser.yml #(2)!
├── greeter #(3)!
├── greeter.yml #(4)!
├── lab
│   └── greeter.clab.yml #(5)!
├── logs
│   ├── greeter #(6)!
│   └── srl #(7)!
├── main.go #(8)!
├── nfpm.yml #(9)!
├── run.sh #(10)!
└── yang #(11)!
    └── greeter.yang
```

1. Directory to store build artifacts. This directory is ignored by Git.
2. [Goreleaser](https://goreleaser.com/) config file to build and publish the NDK application. Usually run via CI/CD pipeline.
3. Directory to store the `greeter` package source code. This is where the application logic is implemented.
4. Application [configuration file](../../../agent.md#application-manager-and-application-configuration-file).
5. Containerlab topology file to assist with the development and testing of the NDK application.
6. Directory with the application log file.
7. Directory with the SR Linux log directory to browse the SR Linux applications logs.
8. Main executable file.
9. [nFPM](https://nfpm.goreleaser.com/) configuration file to build deb/rpm packages locally.
10. Script to orchestrate lab environment and application lifecycle.
11. Directory with the application YANG modules.

Besides short descriptions, we will cover the purpose of each file and directory in the following sections when we start to peel off the layers of the `greeter` NDK application.

## Application Configuration

As was [mentioned before][app-config], in order for the NDK application to be installed on the SR Linux node, it needs to be registered with the Application Manager. The Application Manager is a service that manages the lifecycle of all applications, native and custom ones.

The Application Manager uses the application configuration file to onboard the application. Our greeter app comes with the following [`greeter.yml`][greeter-yml] configuration file[^1]:

```yaml
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/greeter.yml.go.tpl:snip"
```

Refer to the [application configuration][app-config] section to better understand what each field means. Application Manager will look for the `greeter` binary in the `/usr/local/bin/` directory when starting our application.

## Application YANG

Every SR Linux application needs its own schema, this is what makes SR Linux a 100% modelled system. Even the custom, user-defined application must have a schema so that it can be onboarded to the SR Linux NOS.

We have covered the YANG module structure in the [architecture section](../../../agent.md#yang-module), here is the resulting YANG module of our `greeter` application.

```{.yang title="yang/greeter.yang"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/yang/greeter.yang"
```

With this YANG module loaded in SR Linux, we will extend SR Linux schema with the following nodes:

```
module: greeter
  +--rw greeter
     +--rw name     string
     +--r  greeting string
```

Now that we have our YANG module and the application config file, we can start looking into the application's entrypoint - the `main` function.

:octicons-arrow-right-16: [Main function](main.md)

[greeter-go-repo]: https://github.com/srl-labs/ndk-greeter-go
[app-config]: ../../../agent.md#application-manager-and-application-configuration-file
[greeter-yml]: https://github.com/srl-labs/ndk-greeter-go/blob/main/greeter.yml.go.tpl
[bond-repo]: https://github.com/srl-labs/bond
[clab-home]: https://containerlab.dev

[^1]: Don't mind a little template magic, it is for the debugging capabilities of the `greeter` app.
