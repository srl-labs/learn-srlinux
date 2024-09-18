# Processing Config

Now that our application has its config stored in the `ConfigState` struct, we can use it to perform the application logic. While in the case of `greeter` the app logic is trivial, in real-world applications it might be more complex.

```{.go title="greeter/app.go" hl_lines="9"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:app-start"
```

Greeter' core app logic is to calculate the greeting message that consists of a name and the last-booted time of SR Linux system.

```{.go title="greeter/config.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/config.go:process-config"
```

The `processConfig` function first checks if the `name` field is not an empty string. If it is an empty, it means the config name was either deleted or not configured at all. In this case we set the `ConfigState` struct to an empty value which should result in the empty state in the SR Linux data store.

If `name` is set we proceed with calculating the greeting message. Remember that we need to retrieve the `last-booted` time value from the SR Linux system. We do this by calling the `getUptime` function.

```{.go title="greeter/app.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:get-uptime"
```

[Earlier on](app-instance.md#gnmi-client), we created the gNMI Target and now it is time to use it. We use the **gNMI Get** request to retrieve the `/system/information/last-booted` value from the SR Linux. The `Get` function returns a **gNMI Get Response** from which we extract the `last-booted` value as string.

Now that we have the `name` value retrieved from the configuration notification and `last-booted` value fetched via gNMI, we can compose the greeting message:

```{.go title="greeter/config.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/config.go:greeting-msg"
```

With our `ConfigState` struct populated with the `name` and `greeting` values we have only one step left: to [update the state](updating-state.md) datastore with them.
