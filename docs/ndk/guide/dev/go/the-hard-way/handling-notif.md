# Handling Received Config Notifications

Now that we have a notification stream up and running, we can start receiving and handling Config notifications from the NDK. We are back again in the `receiveConfigNotifications` function where range over the `configStream` channel and receive notifications from the NDK.

```{.go title="greeter/config.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/config.go:rcv-cfg-notif"
```

For every received [`NotificationStreamResponse`][notif_stream_resp_doc] from the `configStream` channel we:

1. Log the incoming notification for debugging purposes.
2. Call the `handleConfigNotifications` function that handles the received notification.

Recall, that our Notification Stream is a gRPC stream. This means that the notifications are streamed from the NDK to our app in real-time. When we talk about the configuration we need to process the full configuration before we can start using it. This is why we have the `receivedCh` channel that we utilize to signal the application when the full configuration has been received.

Check out how the notifications logged when we configure a name for the greeter app and commit it:

```srl
--{ + candidate shared default }--[  ]--
A:greeter# greeter name "show me the stream"

--{ +* candidate shared default }--[  ]--
A:greeter# commit stay
All changes have been committed. Starting new transaction.
```

Upon commit action we receive two separate notifications, first one contains the new `name` value and the second one is a "commit end" marker. The "commit end" marker indicates that the committed config has been streamed in full and we can start using it.

```json
2023-12-02 12:13:51 UTC INF Received notifications:
notification: {
  sub_id: 1
  config: {
    op: Update
    key: {
      js_path: ".greeter"
      js_path_with_keys: ".greeter"
    }
    data: {
      json: "{\n  \"name\": \"show me the stream\"\n}\n"
    }
  }
}

2023-12-02 12:13:51 UTC INF Received notifications:
notification: {
  sub_id: 1
  config: {
    op: Update
    key: {
      js_path: ".commit.end"
      js_path_with_keys: ".commit.end"
    }
    data: {
      json: "{\"commit_seq\":32}"
    }
  }
}
```

While in our example we only had one notification with "actual" config change, there might be many of them, before the "commit end" marker is received. So we need to handle them as they appear and stop only when the "commit end" marker is received.

The `handleConfigNotifications` function is responsible for handling "important" notifications until the "commit end" marker is received. That way we only handle notifications that directly relate to the configuration and discard the marker notifications.

```{.go title="greeter/config.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/config.go:buffer-cfg-notif"
```

Pay attention to the [`cfgNotif := n.GetConfig()`](#__codelineno-4-7) call. Since our [`NotificationStreamResponse`][notif_stream_resp_doc] embeds the [`Notification`][notif_doc] message, we need to extract the `Config` message from it by calling `n.GetConfig()`. In Go bindings, the Notification is the interface, with the `GetXXX` methods being the getters for the underlying message type. The [`GetConfig`][get-config] method returns the [`Config Notification`][config_notif_doc] message if the underlying message is of the `Config` type.

For each notification that is not a "commit end" marker we call the `a.handleGreeterConfig(cfgNotif)` and whenever we receive the "commit end" marker we signal the application that the full configuration has been received.

## Handling Greeter Config

Now that we filtered notifications that only contain config-related information, we can handle them.

By handling the config notifications we mean reading the configuration updates received from the notification stream and updating the application's [`ConfigState`](app-instance.md#app-config-and-state) struct with the received value. Later the `ConfigState` struct is used to update application's state in the state datastore.

The `handleGreeterConfig` function is responsible for handling the received notifications.

```{.go title="greeter/config.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/config.go:handle-greeter-cfg"
```

In this function we consider two cases:

1. Configuration Notification contains the empty `data` field. This means that the config has been deleted/cleared and we need to clear the greeter values in the state data store of SR Linux.
2. Configuration Notification contains the non-empty `data` field. This means that the config has been updated or created, and we need to update the greeter values in the state data store of SR Linux.

### Handling Config Deletion

Let's start with the deletion case. How do we know that the config has been deleted?

There are two options:

1. We can check the `op` field of the [`ConfigNotification`][config_notif_doc] message. If the `op` field is set to `Delete`, then the object has been deleted. This does not apply for non-presence containers, like our [greeter YANG container](../../../agent.md#yang-module), since they are always present.
2. We can have a look at the `data` field of the [`ConfigNotification`][config_notif_doc] message that contains the embedded [ConfigData][config_data_doc] message. The `ConfigData` message has the `json` field that contains the JSON representation of the config[^10] and if the json string is an empty json object, then the config has been deleted/emptied.  
    This applies to non-presence containers.

Since our `greeter` container is a non-presence conatainer, in our code we use the 2nd method and check if the data field is empty in the received notification:

```{.go title="greeter/config.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/config.go:delete-case"
```

An empty config means that we need to erase the `name` and `greeting` values of the [`ConfigState`](app-instance.md#app-config-and-state) struct. The empty values will then be populated in the state datastore.

### Handling Config Update

If the config is not empty, this means that it has been updated or created. In this case we need to update the [`ConfigState`](app-instance.md#app-config-and-state) struct our App struct uses to store the greeter values.

```{.go title="greeter/config.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/config.go:non-delete-case"
```

We unmarshal the received configuration update to the [`ConfigState`](app-instance.md#app-config-and-state) struct. This will update the struct fields with the values from the received notification.

## Signalling Config Received

As we mentioned earlier, we need to signal the application when the full configuration has been received. We do this by sending a message to the `receivedCh` channel and this is done when we receive a config notification [with the ".commit.end" key](#__codelineno-3-21:29){ data-proofer-ignore } as part of the message.

This indicates that the full commit set has been streamed and we can start using the configuration.

The receiving end of the `receivedCh` channel is all the way back in the `Start` function after receiving the message from this channel indicates that we can start [processing the config](processing-config.md).

```{.go title="greeter/app.go" hl_lines="6"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:app-start"
```

[notif_stream_resp_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.NotificationStreamResponse
[notif_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.Notification
[config_notif_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.ConfigNotification
[get-config]: https://github.com/nokia/srlinux-ndk-go/blob/main/ndk/sdk_service.pb.go#L958
[config_data_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.ConfigData

[^10]: The `ConfigData` message also has the `bytes` field, but it is not used by the NDK and is reserved for internal SR Linux applications.
