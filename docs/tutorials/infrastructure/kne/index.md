---
tags:
  - kne
  - openconfig
---

# SR Linux with KNE

For easy-to-spin personal network labs, we have open-sourced [containerlab](https://containerlab.dev) project, which many companies and individuals use with and without SR Linux. The simplicity and user-friendliness of containerlab, while being the key ingredients of its success, also bear some limitations. For example, multi-node topologies are not yet possible with containerlab, which means that your lab size is limited by the resources your containerlab host has.

Today, Kubernetes is often seen as a de facto standard container orchestration system that enables horizontal scaling of applications. Thanks to the [KNE (Kubernetes Network Emulation)][knedoc] project, it is now possible to leverage Kubernetes'es extensibility, programmability, and scalability and deploy networking labs using the Kubernetes backend.

Following this tutorial, you will learn how to deploy the Nokia SR Linux node using KNE in different deployment scenarios.

[knedoc]: https://github.com/openconfig/kne/#readme
