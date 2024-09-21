# Application Start

Recall that our program's entrypoint [finishes](main.md#initializing-the-application) with initializing the app struct and calling the `app.Start(ctx)` function. The `Start` function is a place where we start the application's lifecycle.

```{.go title="greeter/app.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:app-start"
```

The `Start` function is composed of the following parts:

1. [Start](#__codelineno-0-2) receiving configuration notifications with `receiveConfigNotifications` function. In this function we:
    1. Start Configuration Stream
    2. Receive notifications from the stream
    3. When the configuration notification is received, unmarshal received config into the `ConfigState` struct
    4. Upon "commit.end" marker seen in the config notification, signal that the whole config set has been read by sending a message to the `receivedCh` channel
2. [Process the configuration](#__codelineno-0-9) by computing the `greeting` value
3. [Update application's state](#__codelineno-0-11) by with `name` and `greeting` values
4. [Stop](#__codelineno-0-13:15){ data-proofer-ignore } the application when the context is cancelled

Here the major difference with the Bond-based approach is that we have to manually handle the configuration notifications.

Time to have a closer look at the first part of the `Start` function - receiving configuration notifications with `go a.receiveConfigNotifications(ctx)` function.
