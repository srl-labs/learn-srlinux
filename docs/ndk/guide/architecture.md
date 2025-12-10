---
comments: true
---
<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>

SR Linux provides a Software Development Kit (SDK) to assist operators with developing agents that run alongside SR Linux applications. This SDK is named **NetOps Development Kit**, or **NDK** for short.

NDK allows operators to write applications (a.k.a agents) that deeply integrate[^10] with other native SR Linux applications. The deep integration is the courtesy of the NDK gRPC service that enables custom applications to interact with other SR Linux applications via Impart Database (IDB).

Fig. 1 shows how custom NDK applications `app-1` and `app-2` interact with other SR Linux subsystems via gRPC-based NDK service that offers access to IDB. SR Linux native apps, like `bgp`, `lldp`, and others also interface with IDB to read and write configuration and state data.

<figure>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":1.5,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/ndk.drawio"}'></div>
  <figcaption>Fig 1. NDK applications integration</figcaption>
</figure>

In addition to the traditional tasks of reading and writing configuration, NDK-based applications gain low-level access to the SR Linux system. For example, these apps can install FIB routes or listen to LLDP events.

## gRPC & Protocol buffers

NDK leverages [gRPC](https://grpc.io) - a high-performance, open-source framework for remote procedure calls - to enable communication between custom applications and SR Linux system.

gRPC framework by default uses [Protocol buffers](https://developers.google.com/protocol-buffers) as its Interface Definition Language as well as the underlying message exchange format.

!!!info
    Protocol buffers are Google's language-neutral, platform-neutral, extensible mechanism for serializing structured data – think XML, but smaller, faster, and simpler. You define how you want your data to be structured once, then you can use special generated source code to easily write and read your structured data to and from a variety of data streams and using a variety of languages.

In gRPC, a client application can directly call a method on a server application on a different machine as if it were a local object. As in many RPC systems, gRPC is based around the idea of defining a service, specifying the methods that can be called remotely with their parameters and return types.

On the server side, the server implements this interface and runs a gRPC server to handle client calls. On the client side, the client provides the same methods as the server.

<figure>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":1,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/ndk.drawio"}'></div>
  <figcaption>Fig 2. gRPC client-server interactions</figcaption>
</figure>

Leveraging gRPC and protobufs provides some substantial benefits for NDK users:

1. **Language neutrality**: NDK apps can be written in any language for which protobuf compiler exists. Go, Python, C, Java, Ruby, and more languages are supported by Protocol buffers enabling SR Linux users to write apps in the language of their choice.
2. **High-performance**: protobuf-encoded messaging is an efficient way to exchange data in a client-server environment. Applications that consume high-volume streams of data (for example, route updates) benefit from an efficient and fast message delivery enabled by protobuf.
3. **Backwards API compatibility**: a protobuf design property of using IDs for data fields makes it possible to evolve API over time without ever breaking backward compatibility. Old clients will still be able to consume data stored in the original fields, whereas new clients will benefit from accessing data stored in the new fields.

## NDK Service

NDK is composed of a collection of gRPC services, each of which enables custom applications to interact with a particular subsystem on an SR Linux NOS, delivering a high level of integration and extensibility.

/// note
Starting with SR Linux 25.3.1, the NDK service is disabled by default. Users should enable it by configuring the `system ndk-server admin-state enable` leaf in the system configuration.
///

With this architecture, NDK applications act as gRPC clients that execute remote procedure calls (RPC) on a system that runs a gRPC server.

On SR Linux, `ndk_mgr` is the application that runs the NDK gRPC server. Fig 3. shows how custom agents interact via gRPC with NDK, and NDK facilitates communication between custom apps and the rest of the system via IDB's pub/sub interface.

<figure>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":2,"zoom":1,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/ndk.drawio"}'></div>
  <figcaption>Fig 3. gRPC as an Inter Process Communication (IPC) protocol</figcaption>
</figure>

As a result, custom applications are able to communicate with the native SR Linux apps as if they were shipped with SR Linux OS.

### Proto files

NDK services, underlying RPCs, and messages are defined in `.proto` files. These files are used to generate language bindings essential for the NDK apps development process and serve as the data modeling language for the NDK itself.

The source `.proto` files for NDK are available at [`nokia/srlinux-ndk-protobufs`](https://github.com/nokia/srlinux-ndk-protobufs) GitHub repository. Anyone can clone this repository and explore the NDK gRPC services or build language bindings for the programming language of their choice.

Additionally, users can find the NDK proto files on the SR Linux file system by the `/opt/srlinux/protos/ndk` path[^20].

### Documentation

Although the proto files are human-readable, it is easier to browse the NDK services using the generated documentation that we keep in the same [`nokia/srlinux-ndk-protobufs`](https://github.com/nokia/srlinux-ndk-protobufs) repo. The HTML document is linked in the [repository structure](https://github.com/nokia/srlinux-ndk-protobufs#repository-structure) section of the readme[^30].

The generated documentation provides the developers with a human-readable reference of all the services, messages, and types that comprise the NDK service.

[^10]: See [NDK Introduction](../index.md) for more details on what level do NDK apps integrate with the rest of SR Linux NOS.
[^20]: starting from 23.7.1 release.
[^30]: For example, [here](https://github.com/nokia/srlinux-ndk-protobufs/tree/v0.1.0) you will find the auto-generated documentation for the latest NDK version at the moment of this writing.
