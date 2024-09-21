# Updating State

When `processConfig` function finished processing the configuration, we need to update the state datastore with the new values. We do this by calling the `updateState` function.

```{.go title="greeter/app.go" hl_lines="11"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:app-start"
```

In SR Linux, the state data store contains both configuration and read-only elements, so we need to update the state datastore with the `ConfigState` struct that contains both the `name` and `greeting` values.

```{.go title="greeter/state.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/state.go:state-const"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/state.go:update-state"
```

The `updateState` function first marshals the `ConfigState` struct to JSON and then calls `telemetryAddOrUpdate` function to post these changes to the state datastore.

Let's see what's inside the `telemetryAddOrUpdate`:

```{.go title="greeter/state.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/state.go:telemetry-add-or-update"
```

As we covered in the [Handling application's configuration and state](../../../operations.md#handling-applications-configuration-and-state) section, NDK's [Telemetry service][sdk_mgr_telem_svc_doc] provides the RPCs to add/update and delete data from SR Linux's state data store. We initialized the Telemetry service client when we [created](app-instance.md#creating-ndk-clients) the application's instance at the very beginning of this tutorial, and now we use it to modify the state data.

First we craft the [`TelemetryUpdateRequest`][sdk_mgr_telem_upd_req_doc] that has `TelemetryInfo` message nested in it, which contains the `TelemetryKey` and `TelemetryData` messages. The `TelemetryKey` message contains the `path` field that specifies the path to the state data element we want to update. The `TelemetryData` message contains the `json` field that contains the JSON representation of the data we want to add/update.

Our `ConfigState` struct was already marshaled to JSON, so we just need to set the `json` field of the `TelemetryData` message to the marshaled JSON and call `TelemetryAddOrUpdate` function of the Telemetry service client.

This will update the state data store with the new values.

Congratulations :partying_face:! You have successfully implemented the greeter application with bare NDK Go bindings and reached the end of this tutorial. Using bare NDK Go bindings without the [srl-labs/bond][bond-repo] helper package is not an easy task, therefore most likely you will use Bond to implement your applications.

[sdk_mgr_telem_svc_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.SdkMgrTelemetryService
[sdk_mgr_telem_upd_req_doc]:https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.TelemetryUpdateRequest
[bond-repo]: https://github.com/srl-labs/bond
