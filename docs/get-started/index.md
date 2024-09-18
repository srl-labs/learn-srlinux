---
comments: true
---

# Get started with Nokia SR Linux

SR Linux packs a lot of unique features that the IP and data center networking teams can get excited about. Some of the features are truly new to the networking domain and make the Network OS a perfect fit for the new generation of deployments.

To make SR Linux answer the requirements of the highly dynamic and programmable networks we had to adopt the modern software development practices and architectures. The clean slate in front of us allowed us to build a modern software platform without carrying the legacy baggage of the previous generations.

At the same time, the new concepts and paradigms implemented in SR Linux might feel, well, _new_, to a seasoned network engineer knowing nothing better than an _industry-standard_ CLI. To help newcomers to get started with SR Linux we have created this getting started guide that walks you through the basics of SR Linux Network Operating System (NOS) in an interactive and practical way.

The journey starts with deploying a small lab environment that we will use to get familiar with SR Linux CLI, and learn the core configuration and operational tasks.

:octicons-arrow-right-24: [Deploying a lab](lab.md)

## Documentation

This portal does not substitute but augments the official SR Linux documentation. You can find official docs using one of the following links:

1. SR Linux documentation collection - https://documentation.nokia.com/srlinux
2. Short and sweet URLs with the release version being part of the URL
    1. https://doc.srlinux.dev/22-11 for the main documentation pages of SR Linux 22.11 release.
    2. https://doc.srlinux.dev/rn22-11-2 for a direct link to Release Notes.
3. Network Infrastructure documentation collection - https://bit.ly/iondoc

## My DCF Learning Labs

More than just a lab service, **My DCF Learning Labs** offers lab exercises complete with inline instructions and solutions, giving you everything you need in one easy-to-use browser-based application - access multiple lab types and exercises to develop your SR Linux skills.

[Learn more](https://www.nokia.com/networks/training/dcf/my-dcf-learning-labs/?utm_source=Learn+SR+Linux) about My DCF Learning Labs and [watch a tutorial](https://www.youtube.com/watch?v=ycDNLoYrdko), or [request your free access now](https://forms.office.com/e/x8d1P1rdNt).

[^1]: Centos 7.3+ has a 3.x kernel and won't be able to run SR Linux container images newer than v22.11.
[^2]: for example [gnmic](https://gnmic.openconfig.net)
[^3]: The labs referenced on this site are deployed with containerlab unless stated otherwise
[^4]: Prior to SR Linux v23.3 users had to mount a topology file for a container to start.
