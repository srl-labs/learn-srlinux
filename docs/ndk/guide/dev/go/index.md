# Developing NDK applications with Go

[**Go**](https://go.dev) is a statically typed, compiled programming language designed at Google by Robert Griesemer, Rob Pike, and Ken Thompson. Go is syntactically similar to C, but with memory safety, garbage collection, structural typing, and CSP-style concurrency.

Go is a solid and popular choice for developing NDK applications because of its simplicity, performance, powerful standard library, and static binary compilation. The latter allows for easy distribution of the NDK applications as a single binary file.

In this guide we will introduce you to the Go-based NDK application development, covering everything from the project structure, through the NDK API interaction towards the build and release process. Buckle up for an exciting journey into the world of Go and NDK!

## Development Environment

Although every developer's environment is different and is subject to a personal preference, we will provide recommendations for a [Go](https://go.dev) toolchain setup suitable for the NDK applications development.

The toolchain that can be used to develop and build Go-based NDK apps consists of the following components:

1. [Go programming language](https://golang.org/dl/) - Go compiler, toolchain, and standard library  
    To continue with this tutorial users should install the Go programming language on their development machine. The installation process is described in the [Go documentation](https://golang.org/doc/install).

2. [srl-labs/bond][bond-repo] package - a helper Go package that abstracts the low-level NDK API and assists in the development of the NDK applications.  
    Using bond is optional, but can drastically reduce the amount of boilerplate code required to interact with the NDK services.

3. [Go NDK bindings](https://github.com/nokia/srlinux-ndk-go) - generated language bindings for the gRPC-based NDK service.  
    As covered in the [NDK Architecture](../../architecture.md) section, NDK is a collection of gRPC-based services. To be able to use gRPC services in a Go program the [language bindings](https://grpc.io/docs/languages/go/quickstart/) have to be generated from the [source proto files](../../architecture.md#proto-files).

    /// admonition | Nokia-provided Go bindings
        type: subtle-note
    Nokia not only provides the [proto files](https://github.com/nokia/srlinux-ndk-protobufs) for the SR Linux NDK service but also offers [NDK Go language bindings](https://github.com/nokia/srlinux-ndk-go) generated for each NDK release.

    With the provided Go bindings, users don't need to generate them themselves.
    ///

5. [Goreleaser](https://goreleaser.com/) - Go-focused build & release pipeline runner. Contains [nFPM](https://nfpm.goreleaser.com/) project to craft deb/rpm packages. Deb/RPM packages is the preferred way to [install NDK agents](../../agent-install-and-ops.md).  
    Goreleaser is optional, but it is a nice tool to build and release Go-based NDK applications in an automated fashion.

## Bond or no Bond?
<!-- --8<-- [start:bond-intro] -->
The [**`srl-labs/bond`**][bond-repo] package is a helper Go [package][bond-pkg] that abstracts the low-level NDK API and assists in the development of the NDK applications. It is a wrapper around the NDK gRPC services with utility functions that were designed to provide a more pleasant development experience.

Bond takes care of the following tasks:

* registering the NDK agent with the NDK server
* creation of NDK gRPC clients for the NDK services
* creation of gNMI client to interact with SR Linux gNMI server and providing the GetWithGNMI method to
* receiving the notifications from the NDK services
* aggregating configuration notifications and forwarding the aggregated config to the NDK application
* handling of the NDK application graceful shutdown

<!-- --8<-- [end:bond-intro] -->
Since using `bond` is optional, we provide two documentation sets for a basic NDK app development:

1. With Bond - a development workflow that leverages [bond][bond-repo] package.
2. The Hard Way - a development workflow that uses NDK Go bindings directly, where a developer is responsible for all low level NDK API interactions.

We will show how both of these workflows can be used to develop a simple [`srl-labs/ndk-greeter-go`][greeter-go-repo] application,

## Meet the `greeter`

This tutorial is based on the simple `greeter` NDK app published at [`srl-labs/ndk-greeter-go`][greeter-go-repo] GitHub repository. The app serves a simple introduction for the developers working with the NDK for the first time.

The apps logic is intentionally simple, as the goal is introduce the developers to the NDK, without focusing on the application business logic. The app gets a developer through the most common NDK functionality:

* Creating the app's YANG schema
* Onboarding the app on SR Linux
* Agent Registration
* Receiving and handling configuration
* Performing "the work" based on the received config
* And finally publishing state back to SR Linux datastore

The `greeter` app adds the `/greeter` context to the SR Linux YANG schema and allows users to configure the `/greeter/name` value. Greeter application will greet the user with a message:  
> `👋 Hi ${provided name}, I am SR Linux and my uptime is 108h23m52s!`

and publishes the `/greeter/name` and the `/greeter/greeting` values in the SR Linux' state datastore.

Maybe a quick demo that shows how to interact with `greeter` and get its state over gNMI and JSON-RPC is worth a thousand words:

<div class="iframe-container">
<iframe width="100%" src="https://www.youtube.com/embed/CmYML_ttCjA" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>

Let's see how we can develop this app using the `bond` package.

:octicons-arrow-right-24: [Continue with Bond](with-bond/index.md)

[greeter-go-repo]: https://github.com/srl-labs/ndk-greeter-go

[bond-repo]: https://github.com/srl-labs/bond
[bond-pkg]: https://pkg.go.dev/github.com/srl-labs/bond
