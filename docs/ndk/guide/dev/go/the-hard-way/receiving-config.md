# Receiving Configuration

For our application to work it needs to receive its own configuration from the SR Linux Management Server. This process is facilitated by the NDK and subscriptions to the configuration notifications.

In the NDK Operations section about [Subscribing to Notifications][operations-subscr-to-notif] we explained how NDK plays a somewhat "proxy" role for your application when it needs to receive updates from other SR Linux applications.

--8<-- "docs/ndk/guide/operations.md:notif-diagram"

Our greeter app is no different, it needs to receive notifications from the NDK, but it only needs to receive a particular notification type - its own configuration updates.  
Whenever we configure the `/greeter/name` leaf and commit the configuration, our app needs to receive updates and act on them.

It all begins in the `Start` function where we called `a.receiveConfigNotifications(ctx)` function.

```{.go title="greeter/app.go" hl_lines="2"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/app.go:app-start"
```

We start this function in a goroutine because we want this function to signal when the full configuration has been received by writing to `receivedCh` channel. We will see how this is used later.

Inside the `receiveConfigNotifications` function we start by creating the Configuration Notification Stream; this is the stream of notifications about greeter's config.

```{.go title="greeter/config.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/config.go:rcv-cfg-notif"
```

Then we start receiving notifications from the stream. For every received [`NotificationStreamResponse`][notif_stream_resp_doc] from the `configStream` channel we handle that notification with `handleConfigNotifications` function.

But first, let's understand how the notification stream is started in the next chapter.

[operations-subscr-to-notif]: ../../../operations.md#subscribing-to-notifications
[notif_stream_resp_doc]: https://ndk.srlinux.dev/doc/sdk#NotificationStreamResponse
