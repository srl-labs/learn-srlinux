
# Developing agents with NDK in Go

This guide explains how to consume the NDK service when developers write the agents in a Go[^1] programming language.

!!!note
    This guide provides code snippets for several operations that a typical agent needs to perform according to the [NDK Service Operations Flow](../architecture.md#operations-flow) chapter.

    Where applicable, the chapters on this page will refer to the NDK Architecture section to provide more context on the operations.

In addition to the publicly available [protobuf files][ndk_proto_repo], which define the NDK Service, Nokia also provides generated Go bindings for data access classes of NDK in a [`nokia/srlinux-ndk-go`][ndk_go_bindings] repo.

The [`github.com/nokia/srlinux-ndk-go`][go_package_repo] package provided in that repository enables developers of NDK agents to immediately start writing NDK applications without the need to generate the Go package themselves.

[ndk_proto_repo]: https://github.com/nokia/srlinux-ndk-protobufs
[ndk_go_bindings]: https://github.com/nokia/srlinux-ndk-go
[go_package_repo]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk

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

Once the gRPC channel is setup, we need to instantiate a client (often called _stub_) to perform RPCs. The client is obtained using the [`NewSdkMgrServiceClient`][sdk_mgr_svc_client_godoc] method provided.

```go
import "github.com/nokia/srlinux-ndk-go/v21/ndk"

client := ndk.NewSdkMgrServiceClient(conn)
```

[sdk_mgr_svc_client_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#NewSdkMgrServiceClient

## Register the agent with the NDK manager:

[:octicons-question-24: Additional information](../architecture.md#agent-registration)

Agent must be first registered with SR Linux by calling the `AgentRegister` method available on the returned [`SdkMgrServiceClient`][sdk_mgr_svc_client_godoc] interface. The initial agent state is created during the registration process.

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

[`AgentRegister`][sdk_mgr_svc_client_godoc] method takes in the context `ctx` that is by now has agent name as its metadata and an [`AgentRegistrationRequest`][agent_reg_req_godoc].

[`AgentRegistrationRequest`][agent_reg_req_godoc] structure can be passed in with its default values for a basic registration request.

```go
import "github.com/nokia/srlinux-ndk-go/v21/ndk"

r, err := client.AgentRegister(ctx, &ndk.AgentRegistrationRequest{})
if err != nil {
    log.Fatalf("agent registration failed: %v", err)
}
```

[`AgentRegister`][agent-reg-go] method returns [`AgentRegistrationResponse`][agent_reg_req_resp_godoc] and an error. Response can be additionally checked for status and error description.

[agent_reg_req_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#AgentRegistrationRequest
[agent_reg_go]: https://github.com/nokia/srlinux-ndk-go/blob/0b020753e0eee6c89419aaa647f1c84ced92e2d0/ndk/sdk_service_grpc.pb.go#L43
[agent_reg_req_resp_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#AgentRegistrationResponse

## Register notification streams
[:octicons-question-24: Additional information](../architecture.md#registering-notifications)

### Create subscription stream

A subscription stream needs to be created first before any of the subscription types can be added.  
[`SdkMgrServiceClient`][sdk_mgr_svc_client_godoc] first creates the subscription stream by executing [`NotificationRegister`][sdk_mgr_svc_client_godoc] method with a [`NotificationRegisterRequest`][notif_reg_req_godoc] only field `Op` set to a value of `const NotificationRegisterRequest_Create`. This effectively creates a stream which is identified with a `StreamID` returned inside the [`NotificationRegisterResponse`][notif_reg_resp_godoc].

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
}
```
    
[notif_reg_req_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#NotificationRegisterRequest
[notif_reg_resp_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#NotificationRegisterResponse

### Add notification subscriptions

Once the `StreamId` is acquired, a client can register notifications of a particular type to be delivered over that stream.

Different types of notifications types can be subscribed to by calling the same [`NotificationRegister`][sdk_mgr_svc_client_godoc] method with a [`NotificationRegisterRequest`][notif_reg_req_godoc] having `Op` field set to `NotificationRegisterRequest_AddSubscription` and certain `SubscriptionType` selected.

In the example below we would like to receive notifications from the [`Config`][cfg_svc_doc] service, hence we specify `NotificationRegisterRequest_Config` subscription type.

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

[cfg_svc_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.1.0/doc/index.html#ndk%2fconfig_service.proto

## Streaming notifications

[:octicons-question-24: Additional information](../architecture.md#streaming-notifications)

Actual streaming of notifications is a task for another service - [`SdkNotificationService`][sdk_notif_svc_doc]. This service requires developers to create its own client, which is done with [`NewSdkNotificationServiceClient`][NewSdkNotificationServiceClient] function.

The returned [`SdkNotificationServiceClient`][sdk_notif_svc_client_godoc] interface has a single method `NotificationStream` that is used to start streaming notifications.

`NotificationsStream` is a **server-side streaming RPC** which means that SR Linux (server) will send back multiple event notification responses after getting the agent's (client) request.

To tell the server to start streaming notifications that were subscribed to before the [`NewSdkNotificationServiceClient`][NewSdkNotificationServiceClient] executes `NotificationsStream` method where [`NotificationStreamRequest`][NotificationStreamRequest] struct has its `StreamId` field set to the value that was obtained at subscription stage.

```go
req := &ndk.NotificationStreamRequest{
    StreamId: resp.GetStreamId(),
}
streamResp, err := notifClient.NotificationStream(ctx, req)
if err != nil {
    log.Fatal("Agent failed to create stream client with error: ", err)
}
```
[sdk_notif_svc_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.1.0/doc/index.html#ndk.SdkNotificationService
[NewSdkNotificationServiceClient](https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#NewSdkNotificationServiceClient)
[sdk_notif_svc_client_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#SdkNotificationServiceClient
[NotificationStreamRequest]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#NotificationStreamRequest

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

`NotificationStream` method of the [`SdkNotificationServiceClient`][sdk_notif_svc_client_godoc] interface will return a stream client [`SdkNotificationService_NotificationStreamClient`][notif_stream_client_godoc].

[notif_stream_client_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#SdkNotificationService_NotificationStreamClient

`SdkNotificationService_NotificationStreamClient` contains a `Recv()` to retrieve notifications one by one. At the end of a stream `Rev()` will return `io.EOF`.

`Recv()` returns a [`*NotificationStreamResponse`][notif_stream_resp_godoc] which contains a slice of [`Notification`][notif_godoc].

[`Notification`][notif_godoc] struct has `GetXXX()` methods defined which retrieve the notification of a specific type. For example: [`GetConfig`][GetConfig] returns [`ConfigNotification`][conf_notif_godoc].

!!!note
    `ConfigNotification` is returned **only if** `Notification` struct has a certain subscription type set for its `SubscriptionType` field. Otherwise, `GetConfig` returns `nil`.


Once the specific `XXXNotification` has been extracted using the `GetXXX()` method, users can access the fields of the notification and process the data contained within the notification using `GetKey()` and `GetData()` methods.

[notif_stream_resp_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#NotificationStreamResponse
[notif_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#NotificationStreamResponse
[GetConfig](https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#Notification.GetConfig)
[conf_notif_godoc]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#ConfigNotification

## Exiting gracefully

Agent needs to handle SIGTERM signal that is sent when a user invokes `stop` command via SR Linux CLI. The following is the required steps to cleanly stop the agent:

1. Remove any agent's state if it was set using [`TelemetryDelete`][TelemetryDelete] method of a Telemetry client.
2. Delete notification subscriptions stream [`NotificationRegister`][sdk_mgr_svc_client_godoc] method with `Op` set to `NotificationRegisterRequest_Delete`.
3. Invoke use `AgentUnRegister()` method of a [`SdkMgrServiceClient`][sdk_mgr_svc_client_godoc] interface.
4. Close gRPC channel with the `sdk_mgr`.

[TelemetryDelete]: https://pkg.go.dev/github.com/nokia/srlinux-ndk-go@v0.1.0/ndk#SdkMgrTelemetryServiceClient

## Logging

To debug an agent, the developers can analyze the log messages that the agent produced. If the agent's logging facility used stdout/stderr to write log messages, then these messages will be found at `/var/log/srlinux/stdout/` directory.

The default SR Linux debug messages are found in the messages directory `/var/log/srlinux/buffer/messages`; check them when something went wrong within the SR Linux system (agent registration failed, IDB server warning messages, etc.).

[logrus](https://github.com/sirupsen/logrus) is a popular structured logger for Go that can log messages of different levels of importance, but developers are free to choose whatever logging package they see fit.

[^1]: Make sure that you have set up the dev environment as explained on [this page](../env/go.md). Readers are also encouraged to first go through the [gRPC basic tutorial](https://grpc.io/docs/languages/go/basics/) to get familiar with the common gRPC workflows when using Go.
