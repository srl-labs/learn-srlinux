# Greeter application

## Application lifecycle

Let's have a look at how our [`main`][main-go] function ends:

```{.go title="main.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/main.go:main-init-app"
```

We initialize the greeter application struct by passing a logger and the pointer to the bond agent instance, and call the `app.Start(ctx)` function. The `Start` function is a place where we start the application's lifecycle.

```{.go title="greeter/app.go" linenums="1"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/greeter/app.go:app-start"
```

The `Start` function is composed of the following parts:

1. [Start](#__codelineno-1-4) reading from the `a.NDKAgent.Notifications.FullConfigReceived` channel, that Bond agent will write to when the full configuration is received by the agent. It is purely a semaphore signal to the application that the configuration has been received and can be processed in full.
2. When the configuration notification signal is received, proceed with [loading the configuration](#__codelineno-1-7) into the application' internal data structure.
3. [Process the received configuration](#__codelineno-1-9) by computing the `greeting` value
4. [Update application's state](#__codelineno-1-11) with `name` and `greeting` values
5. [Stop](#__codelineno-1-13:14){ data-proofer-ignore } the application when the context is cancelled

When the app is stopped by a user (or even killed with a `SIGKILL`) Bond will gracefully stop the application and de-register it on your behalf. Everything that needs to happen will happen behind the scenes, you don't need to do anything special unless you want to perform some custom cleaning steps.

## Configuration load

Time to have a closer look at why and how we load the application configuration. Starting with the "why" first. When we start the greeter application it doesn't hold any state of its own, besides the desired name. The application configuration is done via any of the SR Linux interfaces - CLI, gNMI, JSON-RPC, etc. Like it should be.  
But then how does the greeter app get to know what a user has configured? Correct, it needs to receive the application configuration from SR Linux somehow. And NDK does provide this function.

First, our application has to have a structure that would hold its configuration and state data. For the `greeter` app the structure that holds this data is named `ConfigState` and it only has two fields - `Name` and `Greeting`. But the more complex the application configuration or state data becomes, the richer your struct would be.

And then

```{.go title="greeter/config.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/greeter/config.go:configstate-struct"
```

And then we need to populate this structure with the configuration that NDK sends our way. Here, again, Bond saves us quite a few cycles by providing us with the full configuration that Bond accumulated in the background via `a.NDKAgent.Notifications.FullConfig` byte slice.  
We just need to unmarshal this byte slice into the `ConfigState` struct and we will receive the full configuration a user passed for our application via any of the SR Linux interfaces.

```{.go title="greeter/config.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/greeter/config.go:load-greeter-cfg"
```

With this little function our application reliably receives its own configuration and can perform its business logic based on the configuration passed to it.

## Application logic

With the configuration loaded, the app can now perform its business logic. The business logic of the `greeter` app is very simple:

1. Take the `name` a user has configured the app with
2. Fetch the last-booted time from the SR Linux state and compute the uptime of the device
3. Use the two values to compose a greeting message

As you can see, the logic is straightforwards, but it is a good example of how the application can use the configured values along the values received from the SR Linux state.

```{.go title="greeter/config.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/greeter/config.go:process-config"
```

## Fetching data with gNMI

As we already mentioned, the `greeter` app uses two data points to create the greeting message. The first one is the `name` a user has configured the app with. The second one is the last-booted time from the SR Linux state. Our app gets the `name` from the configuration, and the last-booted time we need to fetch from the SR Linux state as this is not part of the app's config.

An application developer can choose different ways to fetch data from SR Linux, but since Bond already provides a gNMI client, it might be the easiest way to fetch the data.

```{.go title="greeter/app.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/greeter/app.go:get-uptime"
```

Using the `bond.NewGetRequest` we construct a gNMI Get request by providing a path for the `last-booted` state data. Then `a.NDKAgent.GetWithGNMI(getReq)` sends the request to the SR Linux and receives the response.  
All we have to do is parse the response, extract the last-booted value and calculate the uptime by subtracting the last-booted time from the current time.

Now we have all ingredients to compose the greeting message, which we save in the application' `configState` structure:

```go
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/greeter/config.go:greeting-msg"
```

## Posting app's state

Ok, we've completed 90% of our greeter application. The last 10% is sending the computed greeting value back to SR Linux. This is what we call "updating the application state".

Right now the greeting message is nothing more than a string value in the application's `configState` structure. But SR Linux doesn't know anything about it, only application does. Let's fix it.

Applications can post their state to SR Linux via NDK, this way the application state becomes visible to SR Linux and therefore the data can be fetched through any of the available interfaces. The greeter app has the `updateState` function defined that does exactly that.

```{.go title="greeter/state.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/greeter/state.go:update-state"
```

The updateState logic is rather straightforward. We have to convert the application's `configState` structure into a json-serialized byte slice and then use Bond's `UpdateState` function to post it to SR Linux.  
We provide the application's YANG path (`AppRoot`) and the string formatted json blob of the application's `configState` structure.

This will populate the application's state in the SR Linux state and will become available for query over any of the supported management interfaces.

## Summary

That's it! We have successfully created a simple application that uses SR Linux's [NetOps Development Kit](https://ndk.srlinux.dev) and [srl-labs/bond][bond-repo] library that assists in the development process.

We hope that this guide has helped you understand the high-level steps every application needs to take out in order successfully use NDK to register itself with SR Linux, get its configuration, and update its state. You can now apply the core concepts you learned here to build your own applications that extend SR Linux functionality and tailor it to your needs.

Now let's see how we can package our app and make it installable on SR Linux.

:octicons-arrow-right-24: [Building and packaging the application](../build-and-package.md)

[bond-repo]: https://github.com/srl-labs/bond
[main-go]: https://github.com/srl-labs/ndk-greeter-go/blob/main/main.go
