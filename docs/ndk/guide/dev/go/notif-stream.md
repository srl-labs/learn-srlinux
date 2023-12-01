# Notification Stream

Recall that our program's entrypoint finishes with initializing the app struct and calling the `app.Start(ctx)` function. The `Start` function is a place where we start the application's lifecycle.

```{.go title="greeter/app.go"}
--8<-- "http://172.17.0.1:49080/greeter/app.go:app-start"
```

Largely, the `Start` function can be divided in three parts:

1. Start the Configuration Notification Stream
2. Process the Configuration Notification Stream responses
3. Stop the application when the context is cancelled

The application exit procedure has been covered in the [Exit Handler](main.md#exit-handler) section so here we will focus on the first two parts.

## Configuration Notification Stream

In the NDK Operations section about [Subscribing to Notifications][operations-subscr-to-notif] we explained how NDK plays a somewhat "proxy" role for your application when it needs to receive updates from other SR Linux applications.

And you know what, our greeter app is no different, it needs to receive notificatons from the NDK about, but it only needs to receive a particular notification type - its own configuration updates.  
Whenever we configure the `/greeter/name` leaf and commit this configuration, our app needs to receive this update and act on it.

Since our app logic is super simple, all the greeter needs to do is

1. to take the configured `name` value
2. query SR Linux state to retrieve the last booted time
3. create the `greeting` message with the two values above

So it all starts with our app requesting the NDK to stream its own configuration updates back. And this is exactly what happens in `a.StartConfigNotificationStream(ctx)`. Let's zoom in.

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

With the notification stream created, we can now request the NDK to deliver the configuration updates to our app. This is done by crafting a [`NotificationRegisterRequest`][notif_reg_req_doc] on [lines 8-16](#__codelineno-1-8:16).

Note that we use `streamID` we received after creating the notification stream to specify the stream we want to receive the notifications on.

We also set the `SubscriptionTypes` to the `&ndk.NotificationRegisterRequest_Config` value to indicate that we would like to subscribe to the configuration updates.

```{.go title="greeter/notification.go, createNotificationStream func"}
SubscriptionTypes: &ndk.NotificationRegisterRequest_Config{ // config service
        Config: &ndk.ConfigSubscriptionRequest{},
    },
```

We pass the empty [`ConfigSubscriptionRequest`][cfg_sub_req_doc] request since we don't want to apply any filtering on the notifications we receive.

## Starting Notification Stream

With notification Stream ID allocated and [`NotificationRegisterRequest`][notif_reg_req_doc] for `Config` messages created, we can now start the notification stream.

And here is where Go channels come really handy because we can use them to deliver the notifications to our app.

On [lines 18-21](#__codelineno-1-18:21) we create a channel of type [`NotificationStreamResponse`][notif_stream_resp_doc], because this is the type of the messages the NDK will send us, and we pass it to the `StartNotificationStream` function that is started in its own goroutine.

```{.go title="greeter/notification.go"}
--8<-- "http://172.17.0.1:49080/greeter/notification.go:start-notif-stream"
```

[operations-subscr-to-notif]: ../../operations.md#subscribing-to-notifications
[operations-create-notif-stream]: ../../operations.md#creating-notification-stream
[notif_reg_req_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.NotificationRegisterRequest
[cfg_sub_req_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.ConfigSubscriptionRequest
[notif_stream_resp_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.NotificationStreamResponse
