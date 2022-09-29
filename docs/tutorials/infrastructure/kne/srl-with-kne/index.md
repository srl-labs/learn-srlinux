# SR Linux with KNE

|                             |                                                                                                    |
| --------------------------- | -------------------------------------------------------------------------------------------------- |
| **Tutorial name**           | SR Linux with KNE                                                                                  |
| **Lab components**          | 2 Nokia SR Linux nodes                                                                             |
| **Resource requirements**   | :fontawesome-solid-microchip: 2 vCPU <br/>:fontawesome-solid-memory: 4 GB                          |
| **Lab**                     | [openconfig/kne/examples/srlinux/2node-srl-ixr6-with-oc-services.pbtxt][lab]                       |
| **Main ref documents**      | [kne documentation][knedoc]                                                                        |
| **Version information**[^1] | [`kne:631d966`][kne-install], [`srlinux:22.6.4`][srlinux-container], [`kind:0.14.0`][kind-install] |

[kne-install]: https://github.com/openconfig/kne/blob/main/docs/setup.md
[kind-install]: https://kind.sigs.k8s.io/docs/user/quick-start#installation
[lab]: https://github.com/openconfig/kne/blob/main/examples/srlinux/2node-srl-ixr6-with-oc-services.pbtxt
[srlinux-container]: https://github.com/nokia/srlinux-container-image
[knedoc]: https://github.com/openconfig/kne/#readme

For easy-to-spin personal network labs, we have open-sourced [containerlab](https://containerlab.dev) project, which many companies and individuals use with and without SR Linux. The simplicity and user-friendliness of containerlab, while being the key ingredients of its success, also bear some limitations. For example, multi-node topologies are not yet possible with containerlab, which means that your lab size is limited by the resources your containerlab host has.

Today, Kubernetes is often seen as a de facto standard container orchestration system that enables horizontal scaling of applications. Thanks to the [KNE (Kubernetes Network Emulation)][knedoc] project, it is now possible to leverage Kubernetes'es extensibility, programmability, and scalability and deploy networking labs using the Kubernetes backend.

Following this tutorial, you will learn how to deploy the Nokia SR Linux node using KNE in different deployment scenarios.

[^1]: the following versions have been used to create this tutorial. The newer versions might work; please pin the version to the mentioned ones if they don't.
