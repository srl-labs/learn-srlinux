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

-{{youtube(url='https://www.youtube.com/embed/oClamTj4LiY')}}-

**Pydantic SR Linux** is a collection of Pydantic models generated with Pydantify from the SR Linux YANG models. Using this python package a network automation engineer can easily create configuration payloads using strictly typed objects without dropping down to the runtime text templating.

In essence, this allows dealing with configuration management in a more reliable, maintainable and verifiable way.

After we created the Pydantic SR Linux prototype, a few issues popped up around some modelling gaps Pydantify had. In less than two weeks Urs and Dan rectified most of these issues and kicked off Pydantify 0.8.0 release.

With the new Pydantify version I have regenerated the pydantic SR Linux models and created another tutorial that demonstrates how you can progressively enhance your configuration management with Pydantic SR Linux.

Taking it step by step, we first parametrized our script and introduced functions that take care of the narrow parts of the configuration.

Then we added custom classes and convenience methods to make our code more composable.

Finally we added tests and set off to create a bigger automation example that creates the ISIS network with loopback prefix exchange.

-{{youtube(url='https://www.youtube.com/embed/CM3sT55zwt0')}}-

Consider the [examples](https://github.com/srl-labs/pydantic-srlinux/tree/main/example) in the project's repository to see the code in action.

> The Pydantic SR Linux project is an experimental project and we are looking forward to your feedback. If you want to see these models generated automatically for each release - please let us know here in the comments or in our [Discord](https://discord.gg/tZvgjQ6PZf).
