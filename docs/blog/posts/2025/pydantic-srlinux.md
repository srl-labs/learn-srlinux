---
date: 2025-01-30
tags:
  - pydantify
  - api
  - automation
authors:
  - rdodin
---

# Pydantic SR Linux - Pydantic models for SR Linux Network OS

It may feel sometime that network automation always catches up with the developments in the wider IT industry. While managing services with structured APIs and Infrastructure as Code is a common practice in IT, the network industry is still largely sending hand-made CLI commands over the command line interfaces, dealing with prompts and terminal width wrapping issues.

Many network automation engineers acknowledge that the reason they have to deal with decades old network management interfaces is rooted in the old(ish) NOS software, incomplete APIs when compared to CLI and lack of tools and libraries using the modern model-driven APIs.

When designing the SR Linux we wanted to set an example of what a modern network OS should look like. Delivering the state of the art management interfaces and fully modelled management stack.

When it comes to the tools and libraries, we have to rely on the open source community, as tools are seldom developed by a single vendor. And in the YANG-based network automation ecosystem there is, without doubt, a shortage of maintained and up-to-date tools one can pick from.

Today we wanted to share the results of a recent collaboration between the SR Linux and [Pydantify](https://pydantify.github.io/pydantify/) teams that led to the creation of the [Pydantic SR Linux](https://github.com/srl-labs/pydantic-srlinux/) experimental project.

-{{youtube(url='https://www.youtube.com/watch?v=oClamTj4LiY')}}-

**Pydantic SR Linux** is a collection of Pydantic models generated with Pydantify from the SR Linux YANG models. Using this python package a network automation engineer can easily create configuration payloads using strictly typed objects without dropping down to the runtime text templating.

In essence, this allows dealing with configuration management in a more reliable, maintainable and verifiable way. Consider the [examples](https://github.com/srl-labs/pydantic-srlinux/tree/main/example) in the project's repository to see how it works.

The Pydantic SR Linux project is an experimental project and we are looking forward to your feedback. If you want to see these models generated automatically for each release - please let us know here in the comments or in our [Discord](https://discord.gg/tZvgjQ6PZf).
