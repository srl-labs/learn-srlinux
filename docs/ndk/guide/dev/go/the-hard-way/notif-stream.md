# Notification Stream

In the previous chapter we looked at `receiveConfigNotifications` function that is responsible for receiving configuration notifications from the NDK. We saw that it starts with creating the notification stream - by calling `a.StartConfigNotificationStream(ctx)` - and then starts receiving notifications from it.

Let's see how the notification stream is created and how we receive notifications from it.

```{.go title="greeter/notification.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/notification.go:start-cfg-notif-stream"
```

The `StartConfigNotificationStream` performs three major tasks:

1. Create the notification stream and associated Stream ID
2. Add the `Config` subscription to the allocated notification stream
3. Creates the streaming client and starts sending received notifications to the `streamChan` channel

Wouldn't hurt to have a look at each of these tasks in more detail.

## Creating Notification Stream

First, on [line 2](#__codelineno-0-2), we create a notification stream as explained in the [Creating Notification Stream][operations-create-notif-stream] section.

```{.go title="greeter/notification.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/notification.go:create-notif-stream"
```

The function tries to create a notification stream for the `greeter` application with a retry timeout and returns the allocated Stream ID when it succeeds. The Stream ID is later used to request notification delivery of a specific type, which is in our case the [Config Notification][config_notif_doc].

## Adding Config Subscription

With the notification stream created, we now request the NDK to deliver updates of our app's configuration. These are the updates made to the config tree of the greeter app, and it has only one configurable field - `name` leaf.

This is done in the [`a.addConfigSubscription(ctx, streamID)`](#__codelineno-0-8) function.

```{.go title="greeter/notification.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/notification.go:add-cfg-sub"
```

To indicate that we want to receive config notifications over the created notification stream we have to craft the [`NotificationRegisterRequest`][notif_reg_req_doc]. We populate it with the `streamID` received after creating the notification stream to specify the stream we want to receive the notifications on.

The `SubscriptionTypes` set to the `&ndk.NotificationRegisterRequest_Config` value indicates that we would like to receive updates of this specific type as they convey configuration updates.

And we pass the empty [`ConfigSubscriptionRequest`][cfg_sub_req_doc] request since we don't want to apply any filtering on the notifications we receive.

Executing `NotificationRegister` function of the `SDKMgrServiceClient` with notification Stream ID and [`NotificationRegisterRequest`][notif_reg_req_doc] effectively tells NDK about our intention to receive `Config` messages.

It is time to start the notification stream.

## Starting Notification Stream

[The last bits](#__codelineno-0-10:14){ data-proofer-ignore } in the `StartConfigNotificationStream` function create a Go channel[^10] of type [`NotificationStreamResponse`][notif_stream_resp_doc] and pass it to the `startNotificationStream` function that is started in its own goroutine. Here is the `startNotificationStream` function:

```{.go title="greeter/notification.go" .code-scroll-lg}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/notification.go:start-notif-stream"
```

Let's have a look at the two major parts of the function - creating the streaming client and receiving notifications.

### Stream Client

The function [starts](#__codelineno-3-14) with creating a Notification Stream Client with `a.getNotificationStreamClient(ctx, req)` function call. This client is a pure gRPC construct, it is automatically generated from the gRPC service proto file and facilitates the streaming of notifications.

```{.go title="greeter/notification.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/notification.go:stream-client"
```

### Receiving Notifications

Coming back to our `startNotificationStream` function, we can see that it [loops](#__codelineno-5-16:37){ data-proofer-ignore } over the notifications received from the NDK until the parent context is cancelled. The `streamClient.Recv()` function call is a blocking call that waits for the next notification to be streamed from the NDK.

```{.go title="greeter/notification.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/v0.1.0/greeter/notification.go:start-notif-stream"
```

When the notification is received, it is passed to the `streamChan` channel. On the receiving end of this channel is our app's [`Start`](#__codelineno-0-6:17){ data-proofer-ignore } function that starts the `aggregateConfigNotifications` function for each received notification.

/// details | Stream Response Type

If you wonder what type the notifications are, it solely depends on the type of subscriptions we added on the notification stream. In our case, we only [added](#adding-config-subscription) the `Config` subscription, so the notifications we receive will be backed by the [`ConfigNotification`][config_notif_doc] type.

Since the Notification Client can transport notifications of different types, the notification type is hidden behind the [`NotificationStreamResponse`][notif_stream_resp_doc] type. The `NotificationStreamResponse` embeds the `Notification` message that can be one of the following types:

```proto
message Notification
{
    uint64 sub_id                              = 1;  /* Subscription identifier */
    oneof subscription_types
    {
        InterfaceNotification intf             = 10;  // Interface details
        NetworkInstanceNotification nw_inst    = 11;  // Network instance details
        LldpNeighborNotification lldp_neighbor = 12;  // LLDP neighbor details
        ConfigNotification config              = 13;  // Configuration notification
        BfdSessionNotification bfd_session     = 14;  // BFD session details
        IpRouteNotification route              = 15;  // IP route details
        AppIdentNotification appid             = 16;  // App identification details
        NextHopGroupNotification nhg           = 17;  // Next-hop group details
    }
}
```

See the `ConfigNotification` type? This is what we expect to receive in our app.
///

Now our configuration notifications are streamed from the NDK to our app. Let's see how we process them to update the app's configuration.

[operations-create-notif-stream]: ../../../operations.md#creating-notification-stream
[notif_reg_req_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.NotificationRegisterRequest
[cfg_sub_req_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.ConfigSubscriptionRequest
[notif_stream_resp_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.NotificationStreamResponse
[config_notif_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.ConfigNotification

[^10]: Here is where Go channels come really handy because we can use them to deliver the notifications to our app.
