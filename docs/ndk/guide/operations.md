<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>

# NDK Operations

When NDK application is [installed](./agent-install-and-ops.md) on SR Linux it interfaces with the NDK service via gRPC. Regardless of programming language the agent is written in, every application will perform the following basic NDK operations (as shown in Fig. 1):

1. Establish gRPC channel with NDK manager and instantiate an NDK client
2. Register the agent with the NDK manager
3. Register notification streams for different types of NDK services (config, lldp, interface, etc.)
4. Start streaming notifications
5. Handle the streamed notifications
6. Perform some work based on the received notifications
7. Update agent's state data if required
8. Exit gracefully by unregistering the agent

<figure>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":3,"zoom":1.5,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/ndk.drawio"}'></div>
  <figcaption>Fig 1. NDK operations flow</figcaption>
</figure>

To better understand the steps an agent undergoes, we will explain them in a language-neutral manner. For language-specific implementations, read the "Developing with NDK" chapter.

## Creating NDK Manager Client

NDK agents communicate with gRPC-based NDK service by means of remote procedure calls (RPC). An RPC generally takes in a client request message and returns a response message from the server.

First, a gRPC channel must be established with the NDK manager application running on SR Linux[^10]. By default, NDK server listens for connections on a unix socket `unix:///opt/srlinux/var/run/sr_sdk_service_manager:50053`[^20] and doesn't require any authentication. NDK app is expected to connect to this socket to establish gRPC.

```mermaid
sequenceDiagram
    participant N as NDK app
    participant S as NDK Manager

    N->>S: Open gRPC channel
    Note over N,S: gRPC channel established
    create participant MC as NDK Manager Client
    N-->>MC: Create NDK Manager Client
    activate MC
    Note over MC: NDK Manager Client<br/>interacts with SdkMgrService
```

Once the gRPC channel is set up, a gRPC client (often called _the stub_) needs to be created to perform RPCs. In gRPC, each service requires its own client and in NDK the [`SdkMgrService`][sdk_mgr_svc_doc] service is the first service that agents interact with.  
Therefore, users first need to create the NDK Manager Client (_Mgr Client_ in Fig. 1) that will be able to call RPCs of [`SdkMgrService`][sdk_mgr_svc_doc].

/// tip
In the proto files and the generated NDK documentation the NDK services have `Sdk` in their name. While in fact NDK is a fancy name for an SDK, we would like to call the client of the `SdkMgrService` the NDK Manager Client.
///

## Agent registration

With the gRPC channel set up and the NDK Manager Client created, we can start using the NDK service. The first mandatory step is the agent registration with the NDK Manager. At this step NDK initializes the state of our agent, creates the IDB tables and assigns an ID to our application.

```mermaid
sequenceDiagram
    participant NMC as NDK Manager Client
    participant SDK as SDK Manager Service
    NMC->>SDK: AgentRegister
    SDK-->>NMC: AgentRegistrationResponse
```

The registration process is carried out by calling [`AgentRegister`](https://github.com/nokia/srlinux-ndk-protobufs/blob/protos/ndk/sdk_service.proto#L32) RPC of the [`SdkMgrService`][sdk_mgr_svc_doc]. A [`AgentRegistrationResponse`][agent_reg_resp_doc] is returned (omitted in Fig. 1) with the status of the registration process and application ID assigned to the app by the NDK.

## Subscribing to notifications

Remember we said that NDK Agents can interact with other native SR Linux apps? The interaction is done by subscribing to notifications from other SR Linux applications with NDK Manager acting like a gateway between your application and the messaging bus that all SR Linux applications communicate over.

For example, an NDK app can get information from Network Instance, Config, LLDP, BFD and other applications by requesting subscription to notification updates from these applications:

```mermaid
sequenceDiagram
    participant App as NDK App
    participant NDK as NDK Service
    participant IDB as Messaging bus<br/>IDB
    participant LLDP as LLDP Manager
    App->>NDK: I want to receive LLDP notifications
    NDK->>IDB: Subscribing to LLDP notifications
    LLDP-->>IDB: LLDP event
    IDB-->>NDK: LLDP event
    NDK-->>App: LLDP event
```

Let's have a closer look at what it takes to subscribe to notifications from other SR Linux applications.

### Creating notification stream

Prior to subscribing to any application's notifications a subscription stream needs to be created. A client of [`SdkMgrService`][sdk_mgr_svc_doc] calls `NotificationRegister` RPC providing [`NotificationRegistrationRequest`][notif_reg_req_doc] message with only the `op` field set to `Create` and other fields absent.

/// details
`NotificationRegistrationRequest` message's field `op` (short for "operation") may have one of the following values:

- `Create` creates a subscription stream and returns a `StreamId` that is used when adding subscriptions with the `AddSubscription` operation.
- `Delete` deletes the existing subscription stream that has a particular `SubId`.
- `AddSubscription` adds a subscription. The stream will now be able to stream notifications of that subscription type (e.g., Intf, NwInst, etc).
- `DeleteSubscription` deletes the previously added subscription.
///

When `Op` field is set to `Create`, NDK Manager responds with [`NotificationRegisterResponse`][notif_reg_resp_doc] message with `stream_id` field set to some value. The stream has been created, and the subscriptions can be added to the created stream.

To subscribe to a certain service notification updates another call of [`NotificationRegister`][sdk_mgr_svc_doc] RPC is made with the following fields set:

- `stream_id` set to an obtained value from the `NotificationRegisterResponse`
- `Op` is set to `AddSubscription`
- one of the [`subscription_types`](https://github.com/nokia/srlinux-ndk-protobufs/blob/protos/ndk/sdk_service.proto#L125) is set according to the desired service notifications. For example, if notifications from the [`Config`][cfg_svc_doc] service are of interest, then `config` field of type [`ConfigSubscriptionRequest`][cfg_sub_req_doc] is set.

[`NotificationRegisterResponse`][notif_reg_resp_doc] message follows the request and contains the same `stream_id` but now also the `sub_id` field - subscription identifier. At this point agent successfully indicated its desire to receive notifications from certain services, but the notification streams haven't been started yet.

## Streaming notifications

Requesting applications to send notifications is done by interfacing with [`SdkNotificationService`][sdk_notif_svc_doc]. As this is another gRPC service, it requires its own client - Notification client.

To initiate streaming of updates based on the agent subscriptions the Notification Client executes [`NotificationStream`][sdk_notif_svc_doc] RPC which has [`NotificationStreamRequest`][notif_stream_req_doc] message with `stream_id` field set to the ID of a stream to be used. This RPC returns a stream of [`NotificationStreamResponse`][notif_stream_resp_doc], which makes this RPC of type "server streaming RPC".

???info "Server-streaming RPC"
    A server-streaming RPC is similar to a unary RPC, except that the server returns a stream of messages in response to a client's request. After sending all its messages, the server's status details (status code and optional status message) and optional trailing metadata are sent to the client. This completes processing on the server side. The client completes once it has all the server's messages.

`NotificationStreamResponse` message represents a notification stream response that contains one or more notifications. The [`Notification`][notif_doc] message contains one of the [`subscription_types`](https://github.com/nokia/srlinux-ndk-protobufs/blob/57386044bacdb4689eda414bc07bd78e17b170c3/ndk/sdk_service.proto#L204) notifications, which will be set in accordance to what notifications were subscribed by the agent.

In our example, we sent `ConfigSubscriptionRequest` inside the `NotificationRegisterRequest`, hence the notifications that we will get back for that `stream_id` will contain [`ConfigNotification`][cfg_notif_doc] messages inside `Notification` of a `NotificationStreamResponse`.

## Handling notifications

The agent handles the stream of notifications by analyzing which concrete type of notification was read from the stream. The Server streaming RPC will provide notifications till the last available one; the agent then reads out the incoming notifications and handles the messages contained within them.

The handling of notifications is done when the last notification is sent by the server. At this point, the agent may perform some work on the received data and, if needed, update the agent's state if it has one.

## Updating agent's state data

Each agent may keep state and configuration data modeled in YANG. When an agent needs to set/update its own state data (for example, when it made some calculations based on received notifications), it needs to use [`SdkMgrTelemetryService`][sdk_mgr_telem_svc_doc] and a corresponding client.

<figure>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":4,"zoom":1.5,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/ndk.drawio"}'></div>
  <figcaption>Fig 5. Updating agent's state flow</figcaption>
</figure>

The state that an agent intends to have will be available for gNMI telemetry, CLI access, and JSON-RPC retrieval, as it essentially becomes part of the SR Linux state.

Updating or initializing agent's state with data is done with [`TelemetryAddOrUpdate`][sdk_mgr_telem_svc_doc] RPC that has a request of type [`TelemetryUpdateRequest`][telem_upd_req_doc] that encloses a list of [`TelemetryInfo`][telem_info_doc] messages. Each `TelemetryInfo` message contains a `key` field that points to a subtree of agent's YANG model that needs to be updated with the JSON data contained within `data` field.

## Exiting gracefully

When an agent needs to stop its operation and be removed from the SR Linux system, it needs to be unregistered by invoking `AgentUnRegister` RPC of the `SdkMgrService`. The gRPC connection to the NDK server needs to be closed.

When unregistered, the agent's state data will be removed from SR Linux system and will no longer be accessible to any of the management interfaces.

[sdk_mgr_svc_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.SdkMgrService
[sdk_mgr_svc_proto]: https://github.com/nokia/srlinux-ndk-protobufs/blob/protos/ndk/sdk_service.proto
[sdk_notif_svc_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#ndk.SdkNotificationService
[sdk_mgr_telemetry_proto]: https://github.com/nokia/srlinux-ndk-protobufs/blob/protos/ndk/telemetry_service.proto
[notif_reg_req_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.NotificationRegisterRequest
[notif_reg_resp_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#ndk.NotificationRegisterResponse
[cfg_svc_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#ndk%2fconfig_service.proto
[cfg_notif_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#ndk.ConfigNotification
[cfg_sub_req_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#ndk.ConfigSubscriptionRequest
[notif_stream_req_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#ndk.NotificationStreamRequest
[notif_stream_resp_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#ndk.NotificationStreamResponse
[notif_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#ndk.Notification
[sdk_mgr_telem_svc_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#ndk.SdkMgrTelemetryService
[telem_upd_req_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#ndk.TelemetryUpdateRequest
[telem_info_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#ndk.TelemetryInfo
[agent_reg_resp_doc]: https://rawcdn.githack.com/nokia/srlinux-ndk-protobufs/v0.2.0/doc/index.html#srlinux.sdk.AgentRegistrationResponse

[^10]: `sdk_mgr` is the name of the application that implements NDK gRPC server and runs on SR Linux OS.
[^20]: The server is also available on a TCP socket `localhost:50053`.
