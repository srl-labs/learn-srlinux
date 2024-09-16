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

[greeter-go-repo]: https://github.com/srl-labs/ndk-greeter-go

[^1]: Don't mind a little template magic, it is for the debugging capabilities of the `greeter` app.
