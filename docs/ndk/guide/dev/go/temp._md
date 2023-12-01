## Establish gRPC channel with NDK manager and instantiate an NDK client

[:octicons-question-24: Additional information](../architecture.md#grpc-channel-and-ndk-manager-client)

To call service methods, a developer first needs to create a gRPC channel to communicate with the NDK manager application running on SR Linux.

This is done by passing the NDK server address - `localhost:50053` - to `grpc.Dial()` as follows:

```go
import (
    "google.golang.org/grpc"
)

conn, err := grpc.Dial("localhost:50053", grpc.WithInsecure())
if err != nil {
  ...
}
defer conn.Close()
```

Once the gRPC channel is setup, we need to instantiate a client (often called _stub_) to perform RPCs. The client is obtained using the [`NewSdkMgrServiceClient`][NewSdkMgrServiceClient_godoc] method provided.

```go
import "github.com/nokia/srlinux-ndk-go/v21/ndk"

client := ndk.NewSdkMgrServiceClient(conn)
```

[NewSdkMgrServiceClient_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#NewSdkMgrServiceClient

## Register the agent with the NDK manager

[:octicons-question-24: Additional information](../architecture.md#agent-registration)

Agent must be first registered with SR Linux by calling the `AgentRegister` method available on the returned [`SdkMgrServiceClient`][NewSdkMgrServiceClient_godoc] interface. The initial agent state is created during the registration process.

### Agent's context

Go [context](https://pkg.go.dev/context) is a required parameter for each RPC service method. Contexts provide the means of enforcing deadlines and cancellations as well as transmitting metadata within the request.

During registration, SR Linux will be expecting a key-value pair with the `agent_name` key and a value of the agent's name passed in the context of an RPC. The agent name is defined in the agent's YAML file.

!!!warning
    Not including this metadata in the agent `ctx` would result in an agent registration failure. SR Linux would not be able to differentiate between two agents both connected to the same NDK manager.

```go
ctx, cancel := context.WithCancel(context.Background())
defer cancel()
// appending agent's name to the context metadata
ctx = metadata.AppendToOutgoingContext(ctx, "agent_name", "ndkDemo")
```

### Agent registration

[`AgentRegister`][NewSdkMgrServiceClient_godoc] method takes in the context `ctx` that is by now has agent name as its metadata and an [`AgentRegistrationRequest`][AgentRegistrationRequest_godoc].

[`AgentRegistrationRequest`][AgentRegistrationRequest_godoc] structure can be passed in with its default values for a basic registration request.

```go
import "github.com/nokia/srlinux-ndk-go/v21/ndk"

r, err := client.AgentRegister(ctx, &ndk.AgentRegistrationRequest{})
if err != nil {
    log.Fatalf("agent registration failed: %v", err)
}
```

[`AgentRegister`][AgentRegister_godoc] method returns [`AgentRegistrationResponse`][AgentRegistrationResponse_godoc] and an error. Response can be additionally checked for status and error description.

[AgentRegistrationRequest_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#AgentRegistrationRequest
[AgentRegister_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#UnimplementedSdkMgrServiceServer.AgentRegister
[AgentRegistrationResponse_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#AgentRegistrationResponse

## Register notification streams

[:octicons-question-24: Additional information](../architecture.md#registering-notifications)

### Create subscription stream

A subscription stream needs to be created first before any of the subscription types can be added.  
[`SdkMgrServiceClient`][NewSdkMgrServiceClient_godoc] first creates the subscription stream by executing [`NotificationRegister`][NewSdkMgrServiceClient_godoc] method with a [`NotificationRegisterRequest`][NotificationRegisterRequest_godoc] only field `Op` set to a value of `const NotificationRegisterRequest_Create`. This effectively creates a stream which is identified with a `StreamID` returned inside the [`NotificationRegisterResponse`][NotificationRegisterResponse_godoc].

`StreamId` must be associated when subscribing/unsubscribing to certain types of router notifications.

```go
req := &ndk.NotificationRegisterRequest{
    Op: ndk.NotificationRegisterRequest_Create,
}
 
resp, err := client.NotificationRegister(ctx, req)
if err != nil {
    log.Fatalf("Notification Register failed with error: %v", err)
} else if resp.GetStatus() == ndk.SdkMgrStatus_kSdkMgrFailed {
    r.log.Fatalf("Notification Register failed with status %d", resp.GetStatus())
}

log.Debugf("Notification Register was successful: StreamID: %d SubscriptionID: %d", resp.GetStreamId(), resp.GetSubId())
```

[NotificationRegisterRequest_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#NotificationRegisterRequest
[NotificationRegisterResponse_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#NotificationRegisterResponse

### Add notification subscriptions

Once the `StreamId` is acquired, a client can register notifications of a particular type to be delivered over that stream.

Different types of notifications types can be subscribed to by calling the same [`NotificationRegister`][NewSdkMgrServiceClient_godoc] method with a [`NotificationRegisterRequest`][NotificationRegisterRequest_godoc] having `Op` field set to `NotificationRegisterRequest_AddSubscription` and certain `SubscriptionType` selected.

In the example below we would like to receive notifications from the [`Config`][config_service_docs] service, hence we specify `NotificationRegisterRequest_Config` subscription type.

```go
subType := &ndk.NotificationRegisterRequest_Config{ // This is unique to each notification type (Config, Intf, etc.).
    Config: &ndk.ConfigSubscriptionRequest{},
}
req := &ndk.NotificationRegisterRequest{
    StreamId:          resp.GetStreamId(), // StreamId is retrieved from the NotificationRegisterResponse
    Op:                ndk.NotificationRegisterRequest_AddSubscription,
    SubscriptionTypes: subType,
}
resp, err := r.mgrStub.NotificationRegister(r.ctx, req)
if err != nil {
    log.Fatalf("Agent could not subscribe for config notification")
} else if resp.GetStatus() == ndk.SdkMgrStatus_kSdkMgrFailed {
    log.Fatalf("Agent could not subscribe for config notification with status  %d", resp.GetStatus())
}
log.Infof("Agent was able to subscribe for config notification with status %d", resp.GetStatus())
```

[config_service_docs]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.1.0/doc/index.html#ndk%2fconfig_service.proto

## Streaming notifications

[:octicons-question-24: Additional information](../architecture.md#streaming-notifications)

Actual streaming of notifications is a task for another service - [`SdkNotificationService`][SdkNotificationService_doc]. This service requires developers to create its own client, which is done with [`NewSdkNotificationServiceClient`][NewSdkNotificationServiceClient_godoc] function.

The returned [`SdkNotificationServiceClient`][SdkNotificationServiceClient_godoc] interface has a single method `NotificationStream` that is used to start streaming notifications.

`NotificationsStream` is a **server-side streaming RPC** which means that SR Linux (server) will send back multiple event notification responses after getting the agent's (client) request.

To tell the server to start streaming notifications that were subscribed to before the [`NewSdkNotificationServiceClient`][NewSdkNotificationServiceClient_godoc] executes `NotificationsStream` method where [`NotificationStreamRequest`][NotificationStreamRequest_godoc] struct has its `StreamId` field set to the value that was obtained at subscription stage.

```go
req := &ndk.NotificationStreamRequest{
    StreamId: resp.GetStreamId(),
}
streamResp, err := notifClient.NotificationStream(ctx, req)
if err != nil {
    log.Fatal("Agent failed to create stream client with error: ", err)
}
```

[SdkNotificationService_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.1.0/doc/index.html#srlinux.sdk.SdkNotificationService
[NewSdkNotificationServiceClient_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#NewSdkNotificationServiceClient
[SdkNotificationServiceClient_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#SdkNotificationServiceClient
[NotificationStreamRequest_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#NotificationStreamRequest

## Handle the streamed notifications

[:octicons-question-24: Additional information](../architecture.md#handling-notifications)

Handling notifications starts with reading the incoming notification messages and detecting which type this notification is exactly. When the type is known the client reads the fields of a certain notification. Here is the pseudocode that illustrates the flow:

```go
func HandleNotifications(stream ndk.SdkNotificationService_NotificationStreamClient) {
    for { // loop until stream returns io.EoF
        notification stream response (nsr) := stream.Recv()
        for notif in nsr.Notification { // nsr.Notification is a slice of `Notification`
            if notif.GetConfig() is not nil {
                1. config notif = notif.GetConfig()
                2. handle config notif
            } else if notif.GetIntf() is not nil {
                1. intf notif = notif.GetIntf()
                2. handle intf notif
            } ... // Do this if statement for every notification type the agent is subscribed to
        }
    }
}
```

`NotificationStream` method of the [`SdkNotificationServiceClient`][SdkNotificationServiceClient_godoc] interface will return a stream client [`SdkNotificationService_NotificationStreamClient`][NotificationStreamClient_godoc].

`SdkNotificationService_NotificationStreamClient` contains a `Recv()` to retrieve notifications one by one. At the end of a stream `Rev()` will return `io.EOF`.

`Recv()` returns a [`*NotificationStreamResponse`][NotificationStreamResponse_godoc] which contains a slice of [`Notification`][NotificationStreamResponse_godoc].

[`Notification`][NotificationStreamResponse_godoc] struct has `GetXXX()` methods defined which retrieve the notification of a specific type. For example: [`GetConfig`][GetConfig_godoc] returns [`ConfigNotification`][ConfigNotification_godoc].

!!!note
    `ConfigNotification` is returned **only if** `Notification` struct has a certain subscription type set for its `SubscriptionType` field. Otherwise, `GetConfig` returns `nil`.

Once the specific `XXXNotification` has been extracted using the `GetXXX()` method, users can access the fields of the notification and process the data contained within the notification using `GetKey()` and `GetData()` methods.

[NotificationStreamClient_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#SdkNotificationService_NotificationStreamClient
[NotificationStreamResponse_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#NotificationStreamResponse
[GetConfig_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#Notification.GetConfig
[ConfigNotification_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#ConfigNotification

## Exiting gracefully

Agent needs to handle SIGTERM signal that is sent when a user invokes `stop` command via SR Linux CLI. The following is the required steps to cleanly stop the agent:

1. Remove any agent's state if it was set using [`TelemetryDelete`][SdkMgrTelemetryServiceClient_godoc] method of a Telemetry client.
2. Delete notification subscriptions stream [`NotificationRegister`][NewSdkMgrServiceClient_godoc] method with `Op` set to `NotificationRegisterRequest_Delete`.
3. Invoke use `AgentUnRegister()` method of a [`SdkMgrServiceClient`][NewSdkMgrServiceClient_godoc] interface.
4. Close gRPC channel with the `sdk_mgr`.

[SdkMgrTelemetryServiceClient_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#SdkMgrTelemetryServiceClient

## Logging

To debug an agent, the developers can analyze the log messages that the agent produced. If the agent's logging facility used stdout/stderr to write log messages, then these messages will be found at `/var/log/srlinux/stdout/` directory.

The default SR Linux debug messages are found in the messages directory `/var/log/srlinux/buffer/messages`; check them when something went wrong within the SR Linux system (agent registration failed, IDB server warning messages, etc.).

[Logrus](https://github.com/sirupsen/logrus) is a popular structured logger for Go that can log messages of different levels of importance, but developers are free to choose whatever logging package they see fit.