# Greeter application

## Application lifecycle

Let's have a look at how our [`main`][main-go] function ends:

```{.go title="main.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/use-bond-agent/main.go:main-init-app"
```

We initialize the greeter application struct by passing a logger and the pointer to the bond agent instance, and call the `app.Start(ctx)` function. The `Start` function is a place where we start the application's lifecycle.

```{.go title="greeter/app.go" linenums="1"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/use-bond-agent/greeter/app.go:app-start"
```

The `Start` function is composed of the following parts:

1. [Start](#__codelineno-1-4) reading from the `a.NDKAgent.Notifications.FullConfigReceived` channel, that Bond agent will write to when the full configuration is received by the agent. It is purely a semaphore signal to the application that the configuration has been received and can be processed in full.
2. When the configuration notification signal is received, proceed with [loading the configuration](#__codelineno-1-7) into the application' internal data structure.
3. [Process the received configuration](#__codelineno-1-9) by computing the `greeting` value
4. [Update application's state](#__codelineno-1-11) with `name` and `greeting` values
5. [Stop](#__codelineno-1-13:14){ data-proofer-ignore } the application when the context is cancelled

## Configuration load

Time to have a closer look at why and how we load the application configuration. Starting with the "why" first. When we start the greeter application it doesn't hold any state of its own, besides the desired name. The application configuration is done via any of the SR Linux interfaces - CLI, gNMI, JSON-RPC, etc. Like it should be.  
But then how does the greeter app get to know what a user has configured? Correct, it needs to receive the application configuration from SR Linux somehow. And NDK does provide this function.

First, our application has to have a structure that would hold its configuration and state data. For the `greeter` app the structure that holds this data is named `ConfigState` and it only has two fields - `Name` and `Greeting`. But the more complex the application configuration or state data becomes, the richer your struct would be.

And then

```{.go title="greeter/config.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/use-bond-agent/greeter/config.go:configstate-struct"
```

And then we need to populate this structure with the configuration that NDK sends our way. Here, again, Bond saves us quite a few cycles by providing us with the full configuration that Bond accumulated in the background via `a.NDKAgent.Notifications.FullConfig` byte slice.  
We just need to unmarshal this byte slice into the `ConfigState` struct and we will receive the full configuration a user passed for our application via any of the SR Linux interfaces.

```{.go title="greeter/config.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/use-bond-agent/greeter/config.go:load-greeter-cfg"
```

With this little function our application reliably receives its own configuration and can perform its business logic based on the configuration passed to it.

## Application logic

With the configuration loaded, the app can now perform its business logic. The business logic of the `greeter` app is very simple:

1. Take the `name` a user has configured the app with
2. Fetch the last-booted-time from the SR Linux state
3. Use the two values to compose a greeting message

As you can see, the logic is straightforwards, but it is a good example of how the application can use the configured values along the values received from the SR Linux state.

```{.go title="greeter/config.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/use-bond-agent/greeter/config.go:process-config"
```

## Fetching data with gNMI

As we already mentioned, the `greeter` app uses two data points to create the greeting message. The first one is the `name` a user has configured the app with. The second one is the last-booted-time from the SR Linux state. Our app gets the `name` from the configuration, and the last-booted-time we need to fetch from the SR Linux state as this is not part of the app's config.

An application developer can choose different ways to fetch data from the SR Linux, but Bond provides a gNMI client that can be used to fetch the data.

[main-go]: https://github.com/srl-labs/ndk-greeter-go/blob/use-bond-agent/main.go
