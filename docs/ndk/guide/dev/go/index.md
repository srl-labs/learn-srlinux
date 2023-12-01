# Developing NDK applications with Go

[**Go**](https://go.dev) is a statically typed, compiled programming language designed at Google by Robert Griesemer, Rob Pike, and Ken Thompson. Go is syntactically similar to C, but with memory safety, garbage collection, structural typing, and CSP-style concurrency.

Go is a solid and popular choice for developing NDK applications because of its simplicity, performance, powerful standard library, and static binary compilation. The latter allows for easy distribution of the NDK applications as a single binary file.

In this chapter we will cover most of the aspects of developing NDK applications with Go. Based on the demo [**`srl-labs/ndk-greeter-go`**][greeter-go-repo] application we will cover everything from the project structure, through the NDK services interacton to the build and release process.

Buckle up for an exciting journey into the world of Go and NDK!

## Development Environment

Although every developer's environment is different and is subject to a personal preference, we will provide recommendations for a [Go](https://go.dev) toolchain setup suitable for the NDK applications development.

The toolchain that can be used to develop and build Go-based NDK apps consists of the following components:

1. [Go programming language](https://golang.org/dl/) - Go compiler, toolchain, and standard library  
    To continue with this tutorial users should install the Go programming language on their development machine. The installation process is described in the [Go documentation](https://golang.org/doc/install).

2. [Go NDK bindings](https://github.com/nokia/srlinux-ndk-go) - generated language bindings for the gRPC-based NDK service.  
    As covered in the [NDK Architecture](../../architecture.md) section, NDK is a collection of gRPC-based services. To be able to use gRPC services in a Go program the [language bindings](https://grpc.io/docs/languages/go/quickstart/) have to be generated from the [source proto files](../../architecture.md#proto-files).

    Nokia not only provides the [proto files](https://github.com/nokia/srlinux-ndk-protobufs) for the SR Linux NDK service but also offers [NDK Go language bindings](https://github.com/nokia/srlinux-ndk-go) generated for each NDK release.

    With the provided Go bindings, users don't need to generate them themselves.

3. [Goreleaser](https://goreleaser.com/) - Go-focused build & release pipeline runner. Contains [nFPM](https://nfpm.goreleaser.com/) project to craft deb/rpm packages. Deb/RPM packages is the preferred way to [install NDK agents](../../agent-install-and-ops.md).  
    Goreleaser is optional, but it is a nice tool to build and release Go-based NDK applications in an automated fashion.

## Meet the `greeter`

This tutorial is based on the simple `greeter` NDK app published at [**`srl-labs/ndk-greeter-go`**][greeter-go-repo] GitHub repository. The app is a simple starter kit for developers looking to work with the NDK. It gets a developer through the most common NDK functionality:

* Agent Registration
* Receiving and handling configuration
* Performing "the work" based on the received config
* And finally publishing state

The `greeter` app adds `/greeter` context to SR Linux and allows users to configure `/greeter/name` value. Greeter will greet the user with a message  
`👋 Hello ${provided name}, SR Linux was last booted at ${last-booted-time}`  
and publish `/greeter/name` and `/greeter/greeting` values in the state datastore.

Maybe a quick demo that shows how to interact with `greeter` and get its state over gNMI and JSON-RPC is worth a thousand words:

<div class="iframe-container">
<iframe width="100%" src="https://www.youtube.com/embed/CmYML_ttCjA" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>

## Deploying the lab

Before taking a deep dive into the code, let's deploy the `greeter` app to SR Linux using containerlab and see how it works.

/// details | Containerlab for NDK
When developing NDK applications, it is important to have a lab environment to test the application. The lab environment should be as close as possible to the production environment and also be easy to spin up and tear down.

The [Containerlab](https://containerlab.dev/) tool is a perfect fit for this purpose. Containerlab makes it easy to create a personal lab environment composed of network devices and connected by virtual links. We are going to use Containerlab to create a lab environment for the `greeter` NDK application development down the road.
///

It all starts with cloning the `greeter`[greeter-go-repo] repo:

```bash
git clone https://github.com/srl-labs/ndk-greeter-go.git && \
cd ndk-greeter-go
```

/// note
    attrs: {class: inline end}
[Containerlab v0.48.6](https://containerlab.dev/install) version and SR Linux 23.10.1 are used in this tutorial.
///

And then running the deployment script[^10]:

```bash
./run.sh deploy-all #(1)!
```

1. `deploy-all` is a script that builds the `greeter` app, deploys a containerlab topology file, and installs the app on the running SR Linux node.

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
    greeting "👋 Hello Learn SR Linux Reader, SR Linux was last booted at 2023-11-29T21:28:53.282Z"
```

As advertised, the greeter app greets us with a message that includes the `name` value we've set and the last booted time of the SR Linux node. Should you change the `name` value and commit, you will see the new `greeting` message.

## Project structure

The project structure is a matter of personal preference. There are no strict rules on how to structure a Go project. However, there are some best practices we can enforce making the NDK project structure more consistent and easier to understand.

This is the project structure used in this tutorial:
<!-- --8<-- [start:prj-struct] -->
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
4. Application [configuration file](../../agent.md#application-manager-and-application-configuration-file).
5. Containerlab topology file to assist with the development and testing of the NDK application.
6. Directory with the application log file.
7. Directory with the SR Linux log directory to browse the SR Linux applications logs.
8. Main executable file.
9. [nFPM](https://nfpm.goreleaser.com/) configuration file to build deb/rpm packages locally.
10. Script to orchestrate lab environment and application lifecycle.
11. Directory with the application YANG modules.
<!-- --8<-- [end:prj-struct] -->

Besides short descriptions, we will cover the purpose of each file and directory in the following sections when we start to peel off the layers of the `greeter` NDK application.

## Application Configuration

As was [mentioned before][app-config], in order for the NDK application to be installed on the SR Linux node, it needs to be registered with the Application Manager. The Application Manager is a service that manages the lifecycle of all applications, native and custom ones.

The Application Manager uses the application configuration file to onboard the application. Our greeter app comes with the following [`greeter.yml`][greeter-yml] configuration file:

```yaml
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/greeter.yml:snip"
```

Refer to the [application configuration][app-config] section covered previously to understand better what each field means. Here it is worth mentioning that the Application Manager will look for the `greeter` binary in the `/usr/local/bin/` directory when starting our application.

[greeter-go-repo]: https://github.com/srl-labs/ndk-greeter-go
[app-config]: ../../agent.md#application-manager-and-application-configuration-file
[greeter-yml]: https://github.com/srl-labs/ndk-greeter-go/blob/main/greeter.yml
