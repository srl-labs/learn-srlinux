# Satellite Tracker

|                          |                                                                                                   |
| ------------------------ | ------------------------------------------------------------------------------------------------- |
| **Description**          | A fun and inspirational SR Linux agent displays current ISS[^1] coordinates on an ASCII world map |
| **Components**           | [Nokia SR Linux][srl]                                                                             |
| **Programming Language** | Python                                                                                            |
| **Source Code**          | [`KTodts/srl-satellite-tracker`][src]                                                             |
| **Authors**              | [Kevin Todts][auth1]                                                                              |

## Description

![pic](https://raw.githubusercontent.com/KTodts/srl-satellite-tracker/main/img/header.jpg){: .img-shadow}

With SR Linux we provide a NetOps Development Kit (NDK) for writing your own on-box applications which we refer to as agents. This protobuf-based gRPC framework allows users to interact with the NOS on a whole new level: directly installing routes or MPLS routes in the FIB, receiving notifications when state changes for interfaces, BFD sessions or LLDP neighborships.

Or, you make an application that can track the international space station location. But why on earth would you make such application for a router you may ask? Just because we can 😎

## Satellite tracker

The Satellite Tracker app is a nice little [NDK][ndk] app that introduces the NDK concepts and bridges it with a pinch of CLI programmability topping. The app provides a fun way to learn how NDK apps can communicate with the Internet services by switching to the management network namespace and firing up HTTP requests towards the public ISS tracking services.

In addition to showcasing the interaction with external services, the app touches on our programmable CLI by creating a custom output plugin that displays the ISS coordinates on an ASCII app.

![animation](https://raw.githubusercontent.com/KTodts/srl-satellite-tracker/main/img/satellite-cli.gif){: .img-shadow}

ISS coordinates are populated into the SR Linux'es state datastore and can be retrieved via any available interface (CLI, gNMI, JSON-RPC).

![state](https://raw.githubusercontent.com/KTodts/srl-satellite-tracker/main/img/satellite-state.gif){: .img-shadow}

[^1]: International Space Station
[srl]: https://www.nokia.com/networks/products/service-router-linux-NOS/
[src]: https://github.com/KTodts/srl-satellite-tracker
[ndk]: ../index.md
[auth1]: https://www.linkedin.com/in/kevin-todts/
