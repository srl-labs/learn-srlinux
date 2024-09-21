# Application Entry Point

In Go, the `main()` function is the entry point of the binary application and is defined in the [`main.go`][main-go][^1] file of our application:

```{.go .code-scroll-lg}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/main.go:pkg-main"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/main.go:pkg-main-vars"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/main.go:main"
```

## Application version

As you can see, the `main` function is rather simple. First, we [handle the `version`](#__codelineno-0-9:16){ data-proofer-ignore } CLI flag to make sure our application can return its version when asked.

Application config has a [`version-command`](index.md#__codelineno-7-4) field that indicates which command needs to be executed to get the application version. In our case, the `version` field is set to `greeter --version` and we just went through the handler of this flag.

In SR Linux CLI we can get the version of the `greeter` app by executing the `show system application greeter` command:

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
Attentive readers might have noticed that the version of the `greeter` app is `dev-a6f880b` instead of `v0.0.0-` following the [`version` and `commit` variables](#__codelineno-0-3:6){ data-proofer-ignore } values in [`main.go`][main-go] file. This is because we set the values for these variables at build time using the Go linker flags in the [`run.sh`][runsh] script:

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

## Context

Moving down the `main` function, we create the [context](https://www.ardanlabs.com/blog/2019/09/context-package-semantics-in-go.html) that will control the lifecycle of our greeter application.

```go
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/main.go:metadata"
```

And with the context piece out of the way, we are standing in front of the actual NDK application machinery. Let's turn the page and start digging into it.

:octicons-arrow-right-16: [Creating the Bond agent](bond.md).

[runsh]: https://github.com/srl-labs/ndk-greeter-go/blob/main/run.sh
[main-go]: https://github.com/srl-labs/ndk-greeter-go/blob/main/main.go

[^1]: Imports are omitted for brevity.
