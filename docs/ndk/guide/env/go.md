# Go Development Environment
Although every developer's environment is different and is subject to a personal preference, we will provide recommendations for a [Go](https://go.dev) toolchain setup suitable for the development and build of NDK applications.

## Environment components
The toolchain that can be used to develop and build Go-based NDK apps consists of the following components:

1. [Go programming language](https://golang.org/dl/) - Go compiler, toolchain, and standard library
2. [Go NDK bindings](https://github.com/nokia/srlinux-ndk-go) - generated data access classes for gRPC based NDK service.
3. [Goreleaser](https://goreleaser.com/) - Go-focused build & release pipeline runner. Packages [nFPM](https://nfpm.goreleaser.com/) to produce rpm packages that can be used to [install NDK agents](../agent-install.md).


## Project structure
It is recommended to use [Go modules](https://golang.org/ref/mod) when developing applications with Go. Go modules allow for better dependency management and can be placed outside the `$GOPATH` directory.

Here is an example project structure that you can use for the NDK agent development:

```
.                            # Root of a project
├── app                      # Contains agent core logic
├── yang                     # A directory with agent YANG modules
├── agent.yml                # Agent yml config file
├── .goreleaser.yml          # Goreleaser config file
├── main.go                  # Package main that calls agent logic
├── go.mod                   # Go mod file
├── go.sum                   # Go sum file
```

## NDK language bindings
As explained in the [NDK Architecture](../architecture.md) section, NDK is a gRPC based service. To be able to use gRPC services in a Go program the [language bindings](https://grpc.io/docs/languages/go/quickstart/) have to be generated from the source proto files.

Nokia not only provides the [proto files](https://github.com/nokia/srlinux-ndk-protobufs) for the SR Linux NDK service but also [NDK Go language bindings](https://github.com/nokia/srlinux-ndk-go).

With the provided Go bindings, the NDK can be imported in a Go project like that:

```go
import "github.com/nokia/srlinux-ndk-go/v21/ndk"
```