---
date: 2022-12-08
tags:
  - sr linux
  - json-rpc
  - ansible
authors:
  - rdodin
---

# Using Ansible with SR Linux's JSON-RPC Interface

A few days after we fleshed out our [:material-book: JSON-RPC Basics](../../../tutorials/programmability/json-rpc/basics.md) tutorial, and we are releasing another one. While basics tutorial is essential to read to understand how the interface works, the `curl` utility we used in the examples there is not something you would like to automate your network with.

Quite a lot of network ops teams we've been talking to used Ansible to manage their infra, and they wanted to keep using it for network automation as well. While this is a questionable tactic, we still can give you the "fishing rod".

Please welcome - **[:material-book: Using Ansible with SR Linux's JSON-RPC Interface](../../../tutorials/programmability/ansible/using-nokia-srlinux-collection.md)** tutorial, which puts our JSON-RPC interface to work under Ansible command through a set of task-oriented exercises.
