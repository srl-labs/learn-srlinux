# Developing NDK applications with Go

[**Go**](https://go.dev) is a statically typed, compiled programming language designed at Google by Robert Griesemer, Rob Pike, and Ken Thompson. Go is syntactically similar to C, but with memory safety, garbage collection, structural typing, and CSP-style concurrency.

Go is a solid and popular choice for developing NDK applications because of its simplicity, performance, powerful standard library, and static binary compilation. The latter allows for easy distribution of the NDK applications as a single binary file.

In this chapter we will cover most of the aspects of developing NDK applications with Go. Based on the demo [**`srl-labs/ndk-greeter-go`**][greeter-go-repo] application we will cover everything from the project structure, through the NDK services interacton to the build and release process.

Buckle up for an exciting journey into the world of Go and NDK!

## Development Environment

Although every developer's environment is different and is subject to a personal preference, we will provide recommendations for a [Go](https://go.dev) toolchain setup suitable for the NDK applications development.

The toolchain that can be used to develop and build Go-based NDK apps consists of the following components:

1. [Go programming language](https://golang.org/dl/) - Go compiler, toolchain, and standard library
2. [Go NDK bindings](https://github.com/nokia/srlinux-ndk-go) - generated language bindings for the gRPC-based NDK service.
3. [Goreleaser](https://goreleaser.com/) - Go-focused build & release pipeline runner. Contains [nFPM](https://nfpm.goreleaser.com/) project to craft deb/rpm packages. Deb/RPM packages is the preferred way to [install NDK agents](../../agent-install-and-ops.md).

To continue with this tutorial users should install the Go programming language on their development machine. The installation process is described in the [Go documentation](https://golang.org/doc/install). NDK bindings and Goreleaser can be installed later when we reach a point where we need them.

Clone the [`srl-labs/ndk-greeter-go`][greeter-go-repo] project and let's get started!

```bash
git clone https://github.com/srl-labs/ndk-greeter-go.git && \
cd ndk-greeter-go
```

### Project structure

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
4. Application [configuration file](../../agent.md#application-manager-and-application-configuration-file).
5. Containerlab topology file to assist with the development and testing of the NDK application.
6. Directory with the application log file.
7. Directory with the SR Linux log directory to browse the SR Linux applications logs.
8. Main executable file.
9. [nFPM](https://nfpm.goreleaser.com/) configuration file to build deb/rpm packages locally.
10. Script to orchestrate lab environment and application lifecycle.
11. Directory with the application YANG modules.

### NDK language bindings

As explained in the [NDK Architecture](../architecture.md) section, NDK is a gRPC based service. To be able to use gRPC services in a Go program the [language bindings](https://grpc.io/docs/languages/go/quickstart/) have to be generated from the source proto files.

Nokia not only provides the [proto files](https://github.com/nokia/srlinux-ndk-protobufs) for the SR Linux NDK service but also [NDK Go language bindings](https://github.com/nokia/srlinux-ndk-go).

With the provided Go bindings, the NDK can be imported in a Go project like that:

```go
import "github.com/nokia/srlinux-ndk-go/ndk"
```

[greeter-go-repo]: https://github.com/srl-labs/ndk-greeter-go
