# Application Entry Point

In Go, the `main()` function is the entry point of the binary application and is defined in the [`main.go`][main-go] file of our application:

```{.go linenums="1"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/main.go:pkg-main"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/main.go:pkg-main-vars"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/main.go:main"
```

## Application version

As you can see, the `main` function is rather simple. First, we [handle the `version`](#__codelineno-0-9:16) CLI flag to make sure our application can return its version when asked.

Application config has a [`version-command`](index.md#__codelineno-7-4) field that indicates which command needs to be executed to get the application version. In our case, the `version` field is set to `greeter --version` and we just went through the handler of this flag.

In SR Linux CLI we can get the version of the `greeter` app by executing the `greeter --version` command:

```srl
--{ + running }--[  ]--
A:greeter# show system application greeter
  +---------+------+---------+-------------+--------------------------+
  |  Name   | PID  |  State  |   Version   |       Last Change        |
  +=========+======+=========+=============+==========================+
  | greeter | 4676 | running | dev-a6f880b | 2023-11-29T21:29:04.243Z |
  +---------+------+---------+-------------+--------------------------+
```

/// details | Why the version is `dev-a6f880b`?
Attentive readers might have noticed that the version of the `greeter` app is `dev-a6f880b` instead of `v0.0.0-` following the [`version` and `commit` variables](#__codelineno-8-3:6) values in [`main.go`][main-go] file. This is because we setting the values for these variables at build time using the Go linker flags in the [`run.sh`][runsh] script:

```bash
LDFLAGS="-s -w -X main.version=dev -X main.commit=$(git rev-parse --short HEAD)"
```

These variables are then set to the correct values when we build the application with Goreleaser.
///

## Setting up the Logger

Logging is an important part of any application. It aids the developer in debugging the application and provides valuable information about the application's state for its users.

```go
func main() {
    // snip
    logger := setupLogger()
    // snip
}
```

We create the logger before initializing the application so that we can pass it to the application and use it to log the application's state.

Logging from the NDK application is a separate topic that is covered in the [Logging](logging.md) section of this guide.

## Context, gRPC Requests and Metadata

Moving down the `main` function, we create the [context](https://www.ardanlabs.com/blog/2019/09/context-package-semantics-in-go.html) that will drive the lifecycle of our greeter application.

Once the context is created we attach the [metadata](https://grpc.io/docs/guides/metadata/) to it. The metadata is a map of key-value pairs that will be sent along with the gRPC requests.

The NDK service uses the metadata to identify the application from which the request was sent.

```go
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/main.go:metadata"
```

The metadata **must** be attached to the parent context and it should has the `agent_name` key with the value of the application name. The application name in the metadata doesn't have to match anything, but should be unique among all the applications that are registered with the Application Manager.

## Exit Handler

Another important part of the application lifecycle is the exit handler. In the context of the NDK application life cycle the exit handler is a function that is called when the application receives Interrupt or SIGTERM signals.

The exit handler is a good place to perform cleanup actions like closing the open connections, releasing resources, etc.

We execute `exitHandler` function passing it the cancel function of the context:

```go linenums="1"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/main.go:exit-handler"
```

This function is non-blocking as it spawns a goroutine that waits for the registered signals and then execute the `cancel` function of the context. This will propagate the cancellation signal to all the child contexts and our application [reacts](#__codelineno-6-13:15) to it.

```go linenums="1" hl_lines="19-21" title="greeter/app.go"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/greeter/app.go:app-start"
```

We will cover the `func (a *App) Start()` function properly when we get there, but for now, it is important to highlight how cancellation of the main context is intercepted in this function and leading to `a.stop()` call.

The `a.stop()` function is responsible to perform the graceful shutdown of the application.

```go linenums="1" title="greeter/app.go"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/greeter/app.go:app-stop"
```

Following the [Graceful Exit](../../operations.md#exiting-gracefully) section we first unregister the agent with the NDK manager and then closing all connections that our app had opened.

## Initializing the Application

And finally in the main function we initialize the greeter application and start it:

```go title="main.go"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/main.go:main-init-app"
```

This is where the application logic starts to kick in. Let's turn the page and start digging into it in the [next chapter](app-instance.md).

[greeter-go-repo]: https://github.com/srl-labs/ndk-greeter-go
[runsh]: https://github.com/srl-labs/ndk-greeter-go/blob/main/run.sh
[greeter-yml]: https://github.com/srl-labs/ndk-greeter-go/blob/main/greeter.yml
[main-go]: https://github.com/srl-labs/ndk-greeter-go/blob/main/main.go
[ndk_proto_repo]: https://github.com/nokia/srlinux-ndk-protobufs
[ndk_go_bindings]: https://github.com/nokia/srlinux-ndk-go
[go_package_repo]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk
[cfg_svc_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#ndk%2fconfig_service.proto

[^10]: We use [`./run.sh` runner script][runsh] that is a sane alternative to Makefile. Functions in this file perform actions like building the app, destroying the lab, etc. t with memory safety, garbage collection, structural typing, and CSP-style concurrency.
