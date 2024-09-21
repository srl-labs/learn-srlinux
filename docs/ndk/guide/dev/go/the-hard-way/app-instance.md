# Application Instance

At the end of the [main][main-go] function we create the instance of the greeter application by calling `greeter.NewApp(ctx, &logger)`:

```go title="main.go"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/main.go:main-init-app"
```

The `NewApp` function is defined in the [`greeter/app.go`][app-go] file and instantiates the `App` struct.

```go linenums="1" title="greeter/app.go"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:pkg-greeter"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:app-struct"
```

The `App` struct is the main structure of the greeter application. It is way more complex than the [app struct in the Bond-workflow](../with-bond/app.md), and that is because our app will have to do some leg work, that is done by Bond otherwise.

It holds the application config, state, logger instance, gNMI client and the NDK clients to communicate with the NDK services.

## Creating the App Instance

The `NewApp` function is the constructor of the `App` struct. It takes the context and the logger as arguments and returns the pointer to the `App` struct.

```{.go title="greeter/app.go" .code-scroll-lg}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:new-app"
```

## Connecting to NDK Socket

As stated in the [NDK Operations][operations-ndk-mgr-client], the first thing we need to do is to connect to the NDK socket. This is what we do with the helper `connect` function inside the `NewApp` constructor:

```{.go title="greeter/app.go" hl_lines="4"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:pkg-greeter"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:pkg-greeter-const"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:connect"
```

The connection is made to the NDK manager's unix socket using unsecured transport. The insecure transport is justifiable in this case as the NDK manager is running on the same host as the application.

## Creating NDK Clients

Recall, that NDK is a collection of gRPC services, and each service requires a client to communicate with it.

The `NewApp` function creates the clients for the following services:

* [NDK Manager Client:][operations-ndk-mgr-client] to interact with the NDK manager service.
* [Notification Service Client:][operations-subscr-to-notif] to subscribe to the notifications from the NDK manager.
* [Telemetry Service Client:][operations-handling-state] to update application's state.

Creating clients is easy. We just leverage the [Generated NDK Bindings][srlinux-ndk-go] and the `ndk` package contained in the `github.com/nokia/srlinux-ndk-go` module.

```{.go title="greeter/app.go"}
package greeter

import (
    // snip
    "github.com/nokia/srlinux-ndk-go/ndk"
    // snip
)

func NewApp(ctx context.Context, logger *zerolog.Logger) *App {
    // snip
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:create-ndk-clients"
    // snip
}
```

We pass to each client constructor function the gRPC connection we just created and off we go.

## gNMI Client

The NDK service collection allows your application to receive notifications from different SR Linux apps and services. But when it comes to changing SR Linux configuration or reading it your application needs to utilize one of the management interfaces.

Since it is very common to have the application either reading existing configuration or changing it, we wanted our greeter app to demonstrate how to do it.

/// note
When your application needs to read its own config, it can do so by leveraging the `Config` notifications and NDK Notification Client. It is only when the application needs to configure SR Linux or read the configuration outside of its own config that it needs to use the management interfaces.
///

When the greeter app creates the `greeting` message it uses the following template:

```bash
👋 Hi ${name}, I am SR Linux and my uptime is ${uptime}!
```

Since `name` value belongs to the greeter' application config, we can get this value later with the help of the NDK Notification Client. But the `last-boot-time` value is not part of the greeter app config and we need to get it from the SR Linux configuration. This is where we need greeter to use the management interface.

We opted to use the gNMI interface in this tutorial powered by the awesome [gNMIc][gnmic] project. gNMIc project has lots of subcomponents revolving around gNMI, but we are going to use its API package to interact with the SR Linux's gNMI server.

In the `NewApp` function right after we created the NDK clients we create the gNMI client:

```{.go title="greeter/app.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:create-gnmi-target"
```

The `newGNMITarget` function creates the gNMI Target using the `gnmic` API package. We provide the gRPC server unix socket as the address to establish the connection as well as hardcoded default credentials for SR Linux.

```{.go title="greeter/app.go" hl_lines="3"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:pkg-greeter-const"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:new-gnmi-target"
```

/// details | gNMI Configuration on SR Linux
When you're using Containerlab-based lab environment, the gNMI server is configured to run over the unix socket as well, but when you run the greeter app in a production environment, you will have to make sure the relevant configuration is in place.
///

Once the target is created we create the gNMI client for it and returning the pointer to the target struct.

## Registering the Agent

Next task is to [register the agent][operations-register-agent] with the NDK manager. At this step NDK initializes the state of our agent, creates the IDB tables and assigns an ID to our application.

Registration is carried out by calling the `AgentRegister` function of the NDK manager client.

```{.go title="greeter/app.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:register-agent"
```

We pass the empty ` &ndk.AgentRegistrationRequest{}` as this is all we need to do to register the agent.

The `AgentRegister` function returns the [`AgentRegistrationResponse`][agent-reg-resp-doc] that contains the agent ID assigned by the NDK manager. We store this response in a variable, since we will need it later.

## App Config and State

The last bit is to initialize the structure for our app's config and state. This struct will hold the configured `name`, the computed `greeting` value. Here is how our `ConfigState` struct looks:

```{.go title="greeter/config.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/config.go:configstate-struct"
```

The role of the `receivedCh` channel is explained in the [Receiving Configuration](receiving-config.md) section.

Finally, we return the pointer to the `App` struct from the `NewApp` function with struct fields initialized with the respective values.

```{.go title="greeter/app.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:return-app"
```

1. Storing application ID received from the NDK manager when we [registered](#registering-the-agent) the agent.

## Next Step

Once we initialized the app struct with the necessary clients we go back to the `main` function where `app.Start(ctx)` is called to start our application.

```go title="main.go"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/main.go:main-init-app"
```

Let's see what happens there in the [Notification Stream](notif-stream.md) section.

[main-go]: https://github.com/srl-labs/ndk-greeter-go/blob/v0.1.0/main.go
[app-go]: https://github.com/srl-labs/ndk-greeter-go/blob/v0.1.0/greeter/app.go
[operations-ndk-mgr-client]: ../../../operations.md#creating-ndk-manager-client
[operations-subscr-to-notif]: ../../../operations.md#subscribing-to-notifications
[operations-handling-state]: ../../../operations.md#handling-applications-configuration-and-state
[operations-register-agent]: ../../../operations.md#agent-registration
[srlinux-ndk-go]: https://github.com/nokia/srlinux-ndk-go
[agent-reg-resp-doc]: https://ndk.srlinux.dev/doc/sdk#AgentRegistrationResponse
[gnmic]: https://gnmic.openconfig.net
