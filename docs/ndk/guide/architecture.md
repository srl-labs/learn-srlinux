<script type="text/javascript" src="https://cdn.jsdelivr.net/gh/hellt/drawio-js@main/embed2.js" async></script>

SR Linux provides a Software Development Kit (SDK) to assist operators with developing agents that run alongside SR Linux applications. This SDK is named NetOps Development Kit, or NDK for short.

NDK allows operators to write applications (a.k.a agents) that function similar to other applications provided with SR Linux. This is achieved via NDK gRPC service that allows custom applications to interact with other SR Linux applications via Impart Database (IDB).

In Fig. 1 custom NDK applications `app-1` and `app-2` are able to interact with other subsystems of SR Linux operating system via gRPC-based NDK service.

<figure>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:0,&quot;zoom&quot;:1.5,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/learn-srlinux/site/diagrams/ndk.drawio&quot;}"></div>
  <figcaption>Fig 1. NDK applications integration</figcaption>
</figure>

In addition to traditional tasks of reading and writing configuration, custom NDK applications gain low-level access to the SR Linux system, for example to install FIB routes or listen to LLDP events.

## gRPC & Protocol buffers
NDK uses gRPC - a high-performance open source framework for remote procedure calls. 

gRPC framework by default uses [Protocol buffers](https://developers.google.com/protocol-buffers) as its Interface Definition Language as well as the underlying message exchange format.

!!!info
    Protocol buffers are Google's language-neutral, platform-neutral, extensible mechanism for serializing structured data – think XML, but smaller, faster, and simpler. You define how you want your data to be structured once, then you can use special generated source code to easily write and read your structured data to and from a variety of data streams and using a variety of languages.

In gRPC, a client application can directly call a method on a server application on a different machine as if it were a local object. As in many RPC systems, gRPC is based around the idea of defining a service, specifying the methods that can be called remotely with their parameters and return types.

On the server side, the server implements this interface and runs a gRPC server to handle client calls. On the client side, the client provides the same methods as the server.

<figure>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:2,&quot;zoom&quot;:1,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/learn-srlinux/site/diagrams/ndk.drawio&quot;}"></div>
  <figcaption>Fig 2. gRPC client-server interactions</figcaption>
</figure>

Leveraging gRPC and protobufs provides some substantial benefits for NDK users:

1. Language neutrality: NDK apps can be written in any language for which protobuf compiler exists. Go, Python, C, Java, Ruby and more languages are supported by Protocol buffers enabling SR Linux users to write apps in the language of their choice.
2. High-performance: protobuf encoded messaging is an efficient way to exchange data in a client-server environment. Applications which consume high-volume streams of data (for example route updates) benefit from an efficient and fast message delivery enabled by protobuf.
3. Backwards API compatibility: a protobuf design property of using distinctive IDs for data fields makes it possible to evolve API over time without ever breaking backwards compatibility. Old clients will still be able to consume data stored in the original fields, whereas new clients will benefit from accessing data stored in the new fields.

## NDK Service
NDK provides a collection of [gRPC](https://grpc.io/) services each of which enables custom applications to interact with a certain subsystem on an SR Linux OS delivering a high level of integration and extensibility.

With this architecture, NDK agents act as gRPC clients that execute remote procedure calls (RPC) on a system that implements a gRPC server.

On SR Linux, `ndk_mgr` is the application that runs NDK gRPC server. Fig 3. shows how custom agents interact via gRPC with NDK, and NDK in its turn executes the called procedure and communicates with other system applications through IDB and pub/sub interface to return the result of the RPC to a client.

<figure>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:1,&quot;zoom&quot;:1.5,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/learn-srlinux/site/diagrams/ndk.drawio&quot;}"></div>
  <figcaption>Fig 3. gRPC as an Inter Process Communication (IPC) protocol</figcaption>
</figure>

As a result, custom applications are able to communicate with the native SR Linux apps as if they were shipped with SR Linux OS.

### Proto files
NDK services, underlying RPCs and messages are defined in `.proto` files. These files are used to generate language bindings which are essential in building NDK clients as well as serve as the data modeling language for the NDK itself.

The source `.proto` files for NDK are open and published in [`nokia/srlinux-ndk-protobufs`](https://github.com/nokia/srlinux-ndk-protobufs) repository. Anyone can clone this repository and explore the NDK gRPC services or build language bindings for the programming language of their choice.

### Documentation
Although the source proto files themselves are human readable, it is easier to browse the NDK services using the generated documentation that we keep in the same [`nokia/srlinux-ndk-protobufs`](https://github.com/nokia/srlinux-ndk-protobufs) repo. The HTML document is linked in the readme file that appears when a user selects a tag that matches the NDK release version[^1].

The generated documentation provides the developers with a human readable reference of all the services, messages and types that comprise the NDK service.

### Operations flow
Regardless of a language in which the agents are written, at a high level the following flow of operations applies to all agents when interacting with the NDK service:

<figure>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:3,&quot;zoom&quot;:1.5,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/learn-srlinux/site/diagrams/ndk.drawio&quot;}"></div>
  <figcaption>Fig 4. NDK operations flow</figcaption>
</figure>

1. Establish gRPC channel with NDK manager and instantiate an NDK client
2. Register the agent with the NDK manager
3. Register notification streams for different types of NDK services (config, lldp, interface, etc.)
4. Start streaming notifications
5. Handle the streamed notifications
6. Update agent's state data if needed
7. Exit gracefully if required

To better understand the operations flow that agents use when talking to NDK we will explain each step in a language-abstracted manner, for language specific implementations go to "Developing with NDK" chapter.

#### gRPC Channel and NDK Manager Client
NDK agents communicate with gRPC based NDK service by invoking RPCs and handling responses. An RPC generally takes in a client request message and returns a response message from the server.

To call service methods, a gRPC channel needs to be established prior to communicating with the NDK manager application running on SR Linux[^2]. NDK server runs on port `50053`, hence agents which are installed on SR Linux OS use `localhost:50053` socket to establish gRPC channel.

Once the gRPC channel is setup, an a gRPC client (often called _stub_) needs to be created to perform RPCs. Each gRPC service needs to have its own client. In NDK the [`SdkMgrService`][sdk_mgr_svc_doc] service is the first service that agents interact with, hence first users need to create NDK Manager Client (Mgr Client on diagram) that will be able to call RPCs defined for [`SdkMgrService`][sdk_mgr_svc_doc].

#### Agent registration
Agent must be first registered with SRLinux NDK by calling [`AgentRegister`](https://github.com/nokia/srlinux-ndk-protobufs/blob/protos/ndk/sdk_service.proto#L32) RPC of [`SdkMgrService`][sdk_mgr_svc_doc]. Initial agent state is created during the registration process.

An `AgentRegistrationResponse` is returned back (omitted in the Fig. 4) with the status of the registration process.

#### Registering notifications
Agents interact with other services like Network Instance, Config, LLDP, BFD by subscribing to notification updates from these services.

Before subscribing to a notification stream of a certain service the subscription stream needs to be created. To create it, a client of [`SdkMgrService`][sdk_mgr_svc_doc] calls [`NotificationRegister`][sdk_mgr_svc_doc] RPC with [`NotificationRegistrationRequest`][notif_reg_req_doc] field `Op` set to `Create` and other fields absent.

!!!info
    `NotificationRegistrationRequest` message's field `Op` (for Operation) may have one of the following values:

    - `Create` creates a subscription stream and returns a `StreamId` that is used when adding subscriptions with the `AddSubscription` operation.
    - `Delete` deletes the existing subscription stream that has a particular `SubId`.
    - `AddSubscription` adds a subscription. The stream will now be able to stream notifications of that subscription type (e.g. Intf, NwInst, etc).
    - `DeleteSubscription` deletes the previously added subscription.

When `Op` field is set to `Create`, NDK Manager responds with [`NotificationRegisterResponse`][notif_reg_resp_doc] message with `stream_id` field set to some value. This indicates that the stream has been created and subscriptions now can be added to the created stream.

To subscribe to a certain service notification updates another call of [`NotificationRegister`][sdk_mgr_svc_doc] RPC is made with the following fields set:

* `stream_id` set to an obtained value from the `NotificationRegisterResponse`
* `Op` is set to `AddSubscription`
* one of the [`subscription_types`](https://github.com/nokia/srlinux-ndk-protobufs/blob/protos/ndk/sdk_service.proto#L125) is set according to the desired service notifications. For example, if notifications from the [`Config`][cfg_svc_doc] service are of interest, then `config` field of type [`ConfigSubscriptionRequest`][cfg_sub_req_doc] is set.

[`NotificationRegisterResponse`][notif_reg_resp_doc] message follows the request and contains the same `stream_id` but now also the `sub_id` field - subscription identifier. At this point agent successfully indicated its desire to receive notifications from certain services, but the notification streams haven't been started yet.

#### Streaming notifications
Requesting applications to send notifications is done by interfacing with [`SdkNotificationService`][sdk_notif_svc_doc]. As this is another gRPC service, it requires its own client - Notification client - to be used to execute RPCs.

To initiate streaming of updates based on the agent subscriptions the Notification Client executes [`NotificationStream`][sdk_notif_svc_doc] RPC which has [`NotificationStreamRequest`][notif_stream_req_doc] message with `stream_id` field set to the ID of a stream to be used. This RPC returns a stream of [`NotificationStreamResponse`][notif_stream_resp_doc], which makes this RPC of type "server streaming RPC".

???info "Server streaming RPC"
    A server-streaming RPC is similar to a unary RPC, except that the server returns a stream of messages in response to a client’s request. After sending all its messages, the server’s status details (status code and optional status message) and optional trailing metadata are sent to the client. This completes processing on the server side. The client completes once it has all the server’s messages.

`NotificationStreamResponse` message represents notification stream response that contains one or more notification. The [`Notification`][notif_doc] message contains one of the [`subscription_types`](https://github.com/nokia/srlinux-ndk-protobufs/blob/57386044bacdb4689eda414bc07bd78e17b170c3/ndk/sdk_service.proto#L204) notifications, which will be set in accordance to what notifications were subscribed by the agent.

In our example, we sent `ConfigSubscriptionRequest` inside the `NotificationRegisterRequest`, hence the notifications that we will get back for that `stream_id` will contain [`ConfigNotification`][cfg_notif_doc] messages inside `Notification` of a `NotificationStreamResponse`.

#### Handling notifications
The agent handles the stream of notifications by analyzing which concrete type of notification was read from the stream. The Server streaming RPC will provide notifications till the last one available, the agent then reads out the incoming notifications and handles the messages contained within them.

The handling of notifications is done when the last notification is sent by the server. At this point the agent may perform some work on the received data and, if needed, update the agent's state if it has one.

#### Updating agent's state data
Each agent may keep state and configuration data which is modeled in YANG. When agent needs to set/update its own state data (for example when it made some calculations based on received notifications), it needs to use [`SdkMgrTelemetryService`][sdk_mgr_telem_svc_doc] and a corresponding client.

<figure>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:4,&quot;zoom&quot;:1.5,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/learn-srlinux/site/diagrams/ndk.drawio&quot;}"></div>
  <figcaption>Fig 5. Updating agent's state flow</figcaption>
</figure>

The state that agent intends to have will be available for gNMI telemetry, CLI access and JSON-RPC retrieval, as it essentially becomes part of the SR Linux state.

Updating or initializing agent's state with data is done with [`TelemetryAddOrUpdate`][sdk_mgr_telem_svc_doc] RPC that has a request of type [`TelemetryUpdateRequest`][telem_upd_req_doc] that encloses a list of [`TelemetryInfo`][telem_info_doc] messages. Each `TelemetryInfo` message contains a `key` field that points to a subtree of agent's YANG model that needs to be updated with the JSON data contained within `data` field.

#### Exiting gracefully
When agent needs to stop it's operation and be removed from the SR Linux system, it needs to be Unregistered, by invoking `AgentUnRegister` RPC of the `SdkMgrService`. The gRPC connection to the NDK server needs to be closed.

When unregistered, the agent's state data will be removed from SR Linux system and will no longer be accessible to any of the management interfaces.

[sdk_mgr_svc_doc]: https://raw.githack.com/nokia/srlinux-ndk-protobufs/protos/doc/index.html#ndk.SdkMgrService
[sdk_mgr_svc_proto]: https://github.com/nokia/srlinux-ndk-protobufs/blob/protos/ndk/sdk_service.proto
[sdk_notif_svc_doc]: https://raw.githack.com/nokia/srlinux-ndk-protobufs/protos/doc/index.html#ndk.SdkNotificationService
[sdk_mgr_telemetry_proto]: https://github.com/nokia/srlinux-ndk-protobufs/blob/protos/ndk/telemetry_service.proto
[notif_reg_req_doc]: https://raw.githack.com/nokia/srlinux-ndk-protobufs/protos/doc/index.html#ndk.NotificationRegisterRequest
[notif_reg_resp_doc]: https://raw.githack.com/nokia/srlinux-ndk-protobufs/protos/doc/index.html#ndk.NotificationRegisterResponse
[cfg_svc_doc]: https://raw.githack.com/nokia/srlinux-ndk-protobufs/protos/doc/index.html#ndk%2fconfig_service.proto
[cfg_notif_doc]: https://raw.githack.com/nokia/srlinux-ndk-protobufs/protos/doc/index.html#ndk.ConfigNotification
[cfg_sub_req_doc]: https://raw.githack.com/nokia/srlinux-ndk-protobufs/protos/doc/index.html#ndk.ConfigSubscriptionRequest
[notif_stream_resp_doc]: https://raw.githack.com/nokia/srlinux-ndk-protobufs/protos/doc/index.html#ndk.NotificationStreamRequest
[notif_stream_resp_doc]: https://raw.githack.com/nokia/srlinux-ndk-protobufs/protos/doc/index.html#ndk.NotificationStreamResponse
[notif_doc]: https://raw.githack.com/nokia/srlinux-ndk-protobufs/protos/doc/index.html#ndk.Notification
[sdk_mgr_telem_svc_doc]: https://raw.githack.com/nokia/srlinux-ndk-protobufs/protos/doc/index.html#ndk.SdkMgrTelemetryService
[telem_upd_req_doc]: https://raw.githack.com/nokia/srlinux-ndk-protobufs/protos/doc/index.html#ndk.TelemetryUpdateRequest
[telem_info_doc]: https://raw.githack.com/nokia/srlinux-ndk-protobufs/protos/doc/index.html#ndk.TelemetryInfo

[^1]: For example, [here](https://github.com/nokia/srlinux-ndk-protobufs/tree/v21.6.2) you will find the auto-generated documentation for the latest NDK version at the moment of this writing.
[^2]: `ndk_mgr` is the name of the applications that implements NDK gRPC server side and runs on SR Linux OS.