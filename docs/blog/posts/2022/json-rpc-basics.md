---
date: 2022-12-06
tags:
  - sr linux
  - json-rpc
authors:
  - rdodin
---

# JSON-RPC Management Interface

Nokia SR Linux Network OS architecture has been built on strong principles of model-driven APIs and interfaces. Not a single thing in SR Linux datastores can get away without having a matching YANG module describing it.

The ground-up model-driven approach allowed us to build management interfaces that don't have shortness of sight as every interface, in essence, uses the common API layer presented by the management server. One of such interfaces - JSON-RPC - that SR Linux offers has been in the shade of a cool-kid gNMI, though JSON-RPC has lots to offer.

We are glad to present you with an in-depth tutorial on SR Linux's JSON-RPC interface - **[:material-book: JSON-RPC Basics](../../../tutorials/programmability/json-rpc/basics.md)**.

In this tutorial, we explain the JSON-RPC capabilities and provide practical examples for every method this interface offers. Be it retrieval of state, model-driven configuration using JSON, or pushing CLI-styled commands - JSON-RPC has you covered.
