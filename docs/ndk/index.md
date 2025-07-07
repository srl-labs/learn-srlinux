---
tags:
  - ndk
hide:
  - toc
---
# NetOps Development Kit (NDK)

Nokia SR Linux enables its users to create high-performance applications that run alongside native apps on SR Linux Network OS. These "on-box custom applications" can deeply integrate with the rest of the SR Linux system and therefore can perform tasks that are not feasible to perform with traditional out-of-the-box automation done via management interfaces.

<figure markdown>
  ![arch](https://gitlab.com/rdodin/pics/-/wikis/uploads/6beed5e008a32cffaeca2f6f811137b2/image.png){.img-shadow width="640" }
  <figcaption>Custom applications run natively on SR Linux NOS</figcaption>
</figure>

The on-box applications (which we also refer to as "agents") leverage the SR Linux software development kit called **NetOps Development Kit** or NDK for short.

Applications developed with SR Linux NDK have a set of unique characteristics which set them aside from the traditional off-box automation solutions:

1. **Native integration with SR Linux system**  
    SR Linux architecture is built in a way that let NDK agents look and feel like any other regular application such as BGP or ACL. This seamless integration is achieved on several levels:
      1. **System** integration: when deployed on SR Linux system, an NDK agent renders itself like any other "standard" application. That makes lifecycle management unified between Nokia-provided system apps and custom agents.
      2. **Management** integration: each NDK app configuration and state model automatically becomes a part of the global SR Linux management tree, making it possible to configure the agent and query its state the same way as for any other configuration region.
      3. **Telemetry** integration: an NDK agent configuration and state data will automatically become available for Streaming Telemetry consumption.
2. **Programming language-neutral**  
    With SR Linux NDK, the developers are not forced to use any particular language when writing their apps. As NDK is based on gRPC, it is possible to use any[^1] programming language that supports protobuf.
3. **Deep integration with system components**  
    NDK apps are not constrained to only configuration and state management, as often happens with traditional north-bound interfaces. On the contrary, the NDK service exposes additional services that enable deep integration with the SR Linux system, such as listening to RIB/FIB updates or having direct access to the datapath.

Developers are welcomed to dig into the [NDK Developers Guide](guide/architecture.md) to learn all about NDK architecture and how to develop apps with this kit.

Browse our [Apps Catalog](apps/index.md) with a growing list of NDK apps that Nokia or 3rd parties published.

## NDK artifacts

A list of links to various NDK artifacts:

* NDK Proto files: [`nokia/srlinux-ndk-protobufs`](https://github.com/nokia/srlinux-ndk-protobufs)
* [Generated NDK Service documentation](https://ndk.srlinux.dev)
* Go bindings for NDK: [`nokia/srlinux-ndk-go`](https://github.com/nokia/srlinux-ndk-go)
* Python bindings for NDK: [`nokia/srlinux-ndk-py`](https://github.com/nokia/srlinux-ndk-py)

[^1]: This in practice covers all popular programming languages: Python, Go, C#, C, C++, Java, JS, etc.
