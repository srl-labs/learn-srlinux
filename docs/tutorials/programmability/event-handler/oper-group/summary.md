---
comments: true
---

Event-driven automation is a popular paradigm in the networks field. One practical implementation of that paradigm is [Nokia SR Linux Event Handler framework](https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/Event_Handler_Guide/eh-overview.html) that allows users to programmatically react to events happening in a network OS.

This tutorial covers Event Handler concepts by explaining how they can be used to implement [Operational Group feature](oper-group-intro.md).

Theoretical data is backed by a [containerlab-based lab](lab.md) that we exclusively use throughout the tutorial. Readers can therefore repeat every step in their own time.

Before explaining how to configure an event handler-based oper-group instance, we first explain what [problem](problem-statement.md) oper-group is set to fix.

Once the problem statement is set, we proceed with [configuration steps](oper-group-cfg.md) for the event handler instance.

A key piece of the Event Handler framework is the script that is getting executed every time an event to which users subscribed happens. In the [Script chapter](script.md) we explain how oper-group script is composed.

Finally, it is time to see how the Event Handler instance powered by the oper-group script works. We follow through with the [various scenarios](opergroup-operation.md) and capture the behavior of the fabric.
