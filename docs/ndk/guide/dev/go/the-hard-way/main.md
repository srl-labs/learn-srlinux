# Application Entry Point

In Go, the `main()` function is the entry point of the binary application and is defined in the [`main.go`][main-go] file of our application. As in the case of Bond-assisted development, we perform the following same steps

* handling the application's version
* setting up the logger
* creating the context and appending app metadata

## Exit Handler

Here is the first part that we have to manually implement when not using Bond.

In the context of the NDK application life cycle the exit handler is a function that is called when the application receives Interrupt or SIGTERM signals. The exit handler is a good place to perform cleanup actions like closing the open connections, releasing resources, etc.

We execute `exitHandler` function passing it the cancel function of the context:

```go linenums="1"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/main.go:exit-handler"
```

This function is non-blocking as it spawns a goroutine that waits for the registered signals and then execute the `cancel` function of the context. This will propagate the cancellation signal to all the child contexts and our application [reacts](#__codelineno-6-13:15){ data-proofer-ignore } to it.

```go linenums="1" hl_lines="19-21" title="greeter/app.go"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:app-start"
```

We will cover the `func (a *App) Start()` function properly when we get there, but for now, it is important to highlight how cancellation of the main context is intercepted in this function and leading to `a.stop()` call.

The `a.stop()` function is responsible to perform the graceful shutdown of the application.

```go linenums="1" title="greeter/app.go"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:app-stop"
```

Following the [Graceful Exit](../../../operations.md#exiting-gracefully) section we first unregister the agent with the NDK manager and then closing all connections that our app had opened.

## Initializing the Application

In the end, we initializa the app the same way:

```go title="main.go"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/main.go:main-init-app"
```

This is where the application logic starts to kick in. Let's turn the page and start digging into it in the [next chapter](app-instance.md).

[runsh]: https://github.com/srl-labs/ndk-greeter-go/blob/v0.1.0/run.sh
[main-go]: https://github.com/srl-labs/ndk-greeter-go/blob/v0.1.0/main.go
