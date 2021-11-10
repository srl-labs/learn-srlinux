# NetOps Development Kit

Nokia SR Linux enables its users to create high-performance applications which run alongside native apps on SR Linux Network OS. These "on-box custom applications" can be deeply integrated with the rest of the SR Linux system and thus can perform tasks which are not possible with traditional management interfaces common for the typical network operating systems.

<figure markdown>
  ![arch](https://gitlab.com/rdodin/pics/-/wikis/uploads/6beed5e008a32cffaeca2f6f811137b2/image.png){ width="640" }
  <figcaption>Custom applications run natively on SR Linux NOS</figcaption>
</figure>


The on-box applications (which we also refer to as "agents") leverage the SR Linux SDK called **NetOps Development Kit** or NDK for short.

Applications developed with SR Linux NDK have a set of unique characteristics which set them aside from the traditional off-box automation solutions:

1. **Native integration with SR Linux system**  
    SR Linux architecture is built in a way that NDK agents look and feel like any other regular application such as bgp or acl. This seamless integration is achieved on several levels:
      1. System integration: when deployed on SR Linux system NDK agent renders itself like any other "standard" application. That makes lifecycle management unified between Nokia provided system apps and custom agents.
      2. CLI integration: every NDK agent automatically becomes a part of the global CLI tree, making it possible to configure the agent and query its state in the same way as with any other configuration region.
      3. Telemetry integration: an NDK agent configuration and state data will automatically become available for Streaming Telemetry consumption.
2. **Programming language neutral**  
    With SR Linux NDK the developers are not forced to use any particular language when writing their apps. As NDK is a gRPC service defined with Protocol Buffers it is possible to use any[^1] programming language for which protobuf compiler is available. 
3. **Deep integration with system components**  
    NDK apps are not constrained to only configuration and state management as often happens with traditional north-bound interfaces. On the contrary, NDK service exposes additional services that enable deep integration with the SR Linux system such as listening to RIB/FIB updates or having direct access to datapath.

With the information outlined in the [NDK Developers Guide](guide/architecture.md) you will learn about NDK architecture and how to develop apps with this kit.

Navigate to the [Apps Catalog](apps/catalog.md) to browse our growing catalog of NDK apps that were written by Nokia or 3rd parties.

[^1]: Which in practice covers all popular programming languages: Python, Go, C#, C, C++, Java, JS, etc.