# Developing agents with NDK in Python

This guide explains how to consume the NDK service when developers write the agents using Python[^1].

!!!note
    This guide provides code snippets for several operations that a typical agent needs to perform according to the [NDK Service Operations Flow](../../operations.md) chapter.

    Where applicable, the chapters on this page will refer to the NDK Architecture section to provide more context on the operations.

In addition to the publicly available [protobuf files][ndk_proto_repo], which define the NDK Service, Nokia also provides generated Python bindings for data access classes of NDK the [`nokia/srlinux-ndk-py`][ndk_py_bindings] repo. The generated module enables developers of NDK agents to immediately start writing NDK applications without the need to generate the Python package themselves.

[ndk_proto_repo]: https://github.com/nokia/srlinux-ndk-protobufs
[ndk_py_bindings]: https://github.com/nokia/srlinux-ndk-py

## Establish gRPC channel with NDK manager and instantiate an NDK client

[:octicons-question-24: Additional information](../../operations.md#creating-ndk-manager-client)

To call service methods, a developer first needs to create a gRPC channel to communicate with the NDK manager application running on SR Linux.

This is done by passing the NDK server address - `localhost:50053` - to `grpc.Dial()` as follows:

```python
import grpc

channel = grpc.insecure_channel("localhost:50053")
```

Once the gRPC channel is setup, we need to instantiate a client (often called _stub_) to perform RPCs. The `sdk_common_pb2_grpc.SdkMgrServiceStub` method returns a [`SdkMgrService`][SdkMgrService_docs] object

```python
from ndk.sdk_common_pb2_grpc import SdkMgrServiceStub

sdk_mgr_client = SdkMgrServiceStub(channel)
```

[SdkMgrService_docs]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.1.0/doc/index.html#srlinux.sdk.SdkMgrService

## Register the agent with the NDK manager

[:octicons-question-24: Additional information](../../operations.md#agent-registration)

Agent must be first registered with SR Linux by calling the `AgentRegister` method available on the returned [`SdkMgrService`][SdkMgrService_docs] interface. The initial agent state is created during the registration process.

### Agent's Metadata

During registration, SR Linux will be expecting a list of tuples with the `agent_name` item and value of the agent's name as the other item of the tuple. The agent name is defined in the agent's YAML file.

```python
metadata = [("agent_name", agent_name)]
```

### Agent registration

The [`AgentRegister`][SdkMgrService_docs] method takes two named arguments `request` and `metadata`. The `request` argument takes a [`AgentRegistrationRequest`][AgentRegistrationRequest_docs] object and the metadata argument uses the previously defined metadata.

```python
from ndk.sdk_service_pb2 import AgentRegistrationRequest
from ndk.sdk_common_pb2 import SdkMgrStatus

register_request = AgentRegistrationRequest()
register_request.agent_liveliness = keepalive_interval # Optional
response = sdk_mgr_client.AgentRegister(request=register_request, metadata=metadata)
if response.status == SdkMgrStatus.kSdkMgrSuccess:
    # Agent has been registered successfully
    pass
else:
    # Agent registration failed error string available as response.error_str
    pass
```

The [`AgentRegister`][SdkMgrService_docs] method returns a [`AgentRegistrationResponse`][AgentRegistrationResponse_docs] object containing the status of the request as a [`SdkMgrStatus`][SdkMgrStatus_docs] object, error message (if request failed) as a string and the app id as a integer.

[AgentRegistrationResponse_docs]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.1.0/doc/index.html#srlinux.sdk.AgentRegistrationResponse
[AgentRegistrationRequest_docs]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.1.0/doc/index.html#srlinux.sdk.AgentRegistrationRequest
[SdkMgrStatus_docs]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.1.0/doc/index.html#srlinux.sdk.SdkMgrStatus

## Register notification streams

[:octicons-question-24: Additional information](../../operations.md#creating-notification-stream)

### Create subscription stream

A subscription stream needs to be created first before any of the subscription types can be added.  
[`SdkMgrService`][SdkMgrService_docs] first creates the subscription stream by executing [`NotificationRegister`][SdkMgrService_docs] method with a [`NotificationRegisterRequest`][NotificationRegisterRequest_docs] only field `op` set to a value of `NotificationRegisterRequest.Create`. This effectively creates a stream which is identified with a `stream_id` returned inside the [`NotificationRegisterResponse`][NotificationRegisterResponse_docs].

`stream_id` must be associated when subscribing/unsubscribing to certain types of router notifications.

```python
from ndk.sdk_service_pb2 import NotificationRegisterRequest

request = NotificationRegisterRequest(op=NotificationRegisterRequest.Create)
response = sdk_mgr_client.NotificationRegister(request=request, metadata=metadata)
if response.status == sdk_status.kSdkMgrSuccess:
    # Notification Register successful
    stream_id = response.stream_id
    pass
else:
    # Notification Register failed, error string available as response.error_str
    pass
```

`stream_id` will be used in the [Streaming notifications](#streaming-notifications) section.

[NotificationRegisterRequest_docs]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.1.0/doc/index.html#srlinux.sdk.NotificationRegisterRequest
[NotificationRegisterResponse_docs]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.1.0/doc/index.html#srlinux.sdk.NotificationRegisterResponse

### Add notification subscriptions

Once the `stream_id` is acquired, a client can register notifications of a particular type to be delivered over that stream.

Different types of notifications types can be subscribed to by calling the same [`NotificationRegister`][SdkMgrService_docs] method with a [`NotificationRegisterRequest`][NotificationRegisterRequest_docs] having `op` field set to `NotificationRegisterRequest.AddSubscription` and the correct name argument for the configuration type being added ([`NotificationRegisterRequest`][NotificationRegisterRequest_docs] fields for the named arguments).

In the example below we would like to receive notifications from the [`Config`][config_service_docs] service, hence we specify the `config` argument with a [`ConfigSubscriptionRequest`][ConfigSubscriptionRequest_docs] object.

```python
from ndk.config_service_pb2 import ConfigSubscriptionRequest

request = NotificationRegisterRequest(
    stream_id=stream_id,
    op=NotificationRegisterRequest.AddSubscription,
    config=ConfigSubscriptionRequest(),
)

response = sdk_mgr_client.NotificationRegister(request=request, metadata=metadata)
if response.status == sdk_status.kSdkMgrSuccess:
    # Successful registration
    pass
else:
    # Registration failed, error string available as response.error_str
    pass
```

!!!info
    It is possible to register for multiple different types of notifications at the same time by passing different subscription requests to the same `NotificationRegisterRequest`.

[config_service_docs]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.1.0/doc/index.html#ndk%2fconfig_service.proto
[ConfigSubscriptionRequest_docs]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.1.0/doc/index.html#srlinux.sdk.ConfigSubscriptionRequest

## Streaming notifications

[:octicons-question-24: Additional information](../../operations.md#streaming-notifications)

Actual streaming of notifications is a task for another service - [`SdkNotificationService`][SdkNotificationService_docs]. This service requires developers to create its own client, which is done with `SdkNotificationServiceStub` function.

The returned [`SdkNotificationService`][SdkNotificationService_docs] has a single method `NotificationStream` that is used to start streaming notifications.

`NotificationsStream` is a **server-side streaming RPC** which means that SR Linux (server) will send back multiple event notification responses after getting the agent's (client) request.

The `stream_id` that was returned in the [Create subscription stream](#create-subscription-stream) is used to tell the server to included the notifications that were created between when the [`SdkNotificationService`][SdkNotificationService_docs] was created and when its `NotificationsStream` method is invoked.

```python
stream_request = NotificationStreamRequest(stream_id=stream_id)
stream_response = sdk_notification_client.NotificationStream(
    request=stream_request, metadata=metadata
)

for response in stream_response:
    for notification in response.notification:
        # Handle notifications
        pass
```

[SdkNotificationService_docs]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.1.0/doc/index.html#srlinux.sdk.SdkNotificationService

## Handle the streamed notifications

[:octicons-question-24: Additional information](../../operations.md#handling-notifications)

Handling notifications starts with reading the incoming notification messages and detecting which type this notification is exactly. When the type is known the client reads the fields of a certain notification. Here is a method that checks for all notification types and delegates handling to helper methods.

```python
from ndk.sdk_service_pb2 import Notification

def handle_notification(notification: Notification) -> None:
    # Field names are available on the Notification documentation page
    if notification.HasField("config"):
        handle_ConfigNotification(notification.config)
    if notification.HasField("intf"):
        handle_InterfaceNotification(notification.intf)
    if notification.HasField("nw_inst"):
        handle_NetworkInstanceNotification(notification.nw_inst)
    if notification.HasField("lldp_neighbor"):
        handle_LldpNeighborNotification(notification.lldp_neighbor)
    if notification.HasField("bfd_session"):
        handle_BfdSessionNotification(notification.bfd_session)
    if notification.HasField("route"):
        handle_IpRouteNotification(notification.route)
    if notification.HasField("appid"):
        handle_AppIdentNotification(notification.appid)
    if notification.HasField("nhg"):
        handle_NextHopGroupNotification(notification.nhg)
```

A [`Notification`][Notification_docs] object has a `HasField()` method that allows to check if the field contains a notification. Once it is confirmed that `XXXXX` field is present we can access it as attribute of the notification (`notification.XXXXX`) this will return a notification of the associated type (for example accessing `notification.config` returns a [`ConfigNotification`][ConfigNotification_docs]).

!!!note
    It is essential to verify if the notification has a given field with the `HasField()` method as accessing an invalid field will give an empty notification. The value will not be `None` and the accessing the invalid field will not throw an Exception.

[Notification_docs]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.1.0/doc/index.html#srlinux.sdk.Notification
[ConfigNotification_docs]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.1.0/doc/index.html#srlinux.sdk.ConfigNotification

## Exiting gracefully

Agent needs to handle SIGTERM signal that is sent when a user invokes `stop` command via SR Linux CLI. The following is the required steps to cleanly stop the agent:

1. Remove any agent's state if it was set using [`TelemetryDelete`][SdkMgrTelemetryService_docs] method of a Telemetry client.
2. Delete notification subscriptions stream using [`NotificationRegisterRequest`][NotificationRegisterRequest_docs] with `op` set to [`Delete`][NotificationRegisterRequest_Operation_docs]
3. Invoke use `AgentUnRegister()` method of the [`SdkMgrService`][SdkMgrService_docs] object.
4. Close gRPC channel with the `sdk_mgr` (`channel.close()`).

[SdkMgrTelemetryService_docs]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.1.0/doc/index.html#srlinux.sdk.SdkMgrTelemetryService
[NotificationRegisterRequest_Operation_docs]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.1.0/doc/index.html#srlinux.sdk.NotificationRegisterRequest.Operation

## Logging

To debug an agent, the developers can analyze the log messages that the agent produced. If the agent's logging facility used stdout/stderr to write log messages, then these messages will be found at `/var/log/srlinux/stdout/` directory.

The default SR Linux debug messages are found in the messages directory `/var/log/srlinux/buffer/messages`; check them when something went wrong within the SR Linux system (agent registration failed, IDB server warning messages, etc.).

[^1]: Make sure that you have set up the dev environment as explained on [this page](index.md).
