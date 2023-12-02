# Notification Stream

Recall that our program's entrypoint [finishes](main.md#initializing-the-application) with initializing the app struct and calling the `app.Start(ctx)` function. The `Start` function is a place where we start the application's lifecycle.

```{.go title="greeter/app.go"}
--8<-- "http://172.17.0.1:49080/greeter/app.go:app-start"
```

Largely, the `Start` function can be divided in three parts:

1. [Start](#__codelineno-0-2) the Configuration Notification Stream
2. [Process](#__codelineno-0-6:17) the Configuration Notification Stream responses
3. [Stop](#__codelineno-0-19) the application when the context is cancelled

The application exit procedure has been covered in the [Exit Handler](main.md#exit-handler) section so here we will focus on the first two parts.

## Configuration Notification Stream

In the NDK Operations section about [Subscribing to Notifications][operations-subscr-to-notif] we explained how NDK plays a somewhat "proxy" role for your application when it needs to receive updates from other SR Linux applications.

And you know what, our greeter app is no different, it needs to receive notificatons from the NDK about, but it only needs to receive a particular notification type - its own configuration updates.  
Whenever we configure the `/greeter/name` leaf and commit this configuration, our app needs to receive this update and act on it.

Since our app logic is super simple, all the greeter needs to do is:

1. to receive the configured `name` value
2. query SR Linux state to retrieve the last booted time
3. create the `greeting` message with the two values above

So it all starts with our app requesting the NDK to stream its own configuration updates. And this is exactly what happens in `a.StartConfigNotificationStream(ctx)`. Let's zoom in.

```{.go title="greeter/notification.go"}
--8<-- "http://172.17.0.1:49080/greeter/notification.go:start-cfg-notif-stream"
```

Let's again break down the function into smaller pieces.

## Creating Notification Stream

First, on [ln 2](#__codelineno-1-2), we create a notification stream as explained in the [Creating Notification Stream][operations-create-notif-stream] section.

```{.go title="greeter/notification.go"}
--8<-- "http://172.17.0.1:49080/greeter/notification.go:create-notif-stream"
```

The function tries to create a notification stream for the `greeter` application with a retry timeout and returns the allocated Stream ID when it succeeds. The Stream ID is later used to request notification delivery of a specific type, which is in our case the Config Notification.

## Adding Config Subscription

With the notification stream created, we can now request the NDK to deliver the configuration updates to our app. This is done in the [`a.addConfigSubscription(ctx, streamID)`](#__codelineno-1-8) function.

```{.go title="greeter/notification.go"}
--8<-- "http://172.17.0.1:49080/greeter/notification.go:add-cfg-sub"
```

Passing the [`NotificationRegisterRequest`][notif_reg_req_doc] with the `streamID` received after creating the notification stream allows us to specify the stream we want to receive the notifications on.

The `SubscriptionTypes` set to the `&ndk.NotificationRegisterRequest_Config` value indicates that we would like to subscribe to the configuration updates.

And we pass the empty [`ConfigSubscriptionRequest`][cfg_sub_req_doc] request since we don't want to apply any filtering on the notifications we receive.

Executing `NotificationRegister` function of the `SDKMgrServiceClient` with notification Stream ID and [`NotificationRegisterRequest`][notif_reg_req_doc] effectively tells NDK about our intention to receive `Config` messages.

It is time to start the notification stream.

## Starting Notification Stream

[The last bits](#__codelineno-1-10:14) in the `StartConfigNotificationStream` function create a Go channel[^10] of type [`NotificationStreamResponse`][notif_stream_resp_doc] and pass it to the `startNotificationStream` function that is started in its own goroutine. Here is the `startNotificationStream` function:

```{.go title="greeter/notification.go"}
--8<-- "http://172.17.0.1:49080/greeter/notification.go:start-notif-stream"
```

### Stream Client

The function [starts](#__codelineno-4-12) with creating a Notification Stream Client with `a.getNotificationStreamClient(ctx, req)` function call. This client is a pure gRPC construct, it is automatically generated from the gRPC service proto file and facilitates the streaming nature of the NDK Notification Service.

```{.go title="greeter/notification.go"}
--8<-- "http://172.17.0.1:49080/greeter/notification.go:stream-client"
```

### Receiving Notifications

Coming back to our `startNotificationStream` function, we can see that it [loops](#__codelineno-6-16:37) over the notifications received from the NDK. The `streamClient.Recv()` function call is a blocking call that waits for the next notification to be streamed from the NDK.

```{.go title="greeter/notification.go"}
--8<-- "http://172.17.0.1:49080/greeter/notification.go:start-notif-stream"
```

When the notification is received, it is passed to the `streamChan` channel. On the receiving end of this channel is our app's [`Start`](#__codelineno-0-6:17) function that starts the `handleConfigNotifications` for each received notification.

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

[operations-subscr-to-notif]: ../../operations.md#subscribing-to-notifications
[operations-create-notif-stream]: ../../operations.md#creating-notification-stream
[notif_reg_req_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.NotificationRegisterRequest
[cfg_sub_req_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.ConfigSubscriptionRequest
[notif_stream_resp_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.NotificationStreamResponse
[config_notif_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.ConfigNotification

[^10]: Here is where Go channels come really handy because we can use them to deliver the notifications to our app.
