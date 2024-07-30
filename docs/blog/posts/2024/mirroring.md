---
date: 2024-07-30
tags:
    - mirroring
authors:
    - tweber
    - rdodin
---

# Mirroring in SR Linux

Once in a while you need to take a closer look at the traffic that flows through your network. Be it for troubleshooting, monitoring, or security reasons, you need to be able to capture and analyze the packets.

Doing the packet capture in a virtual lab is a breeze - pick your favorite traffic dumping tool and point it to the virtual interface associated with your data port. But when you need to do the same in a physical network, things get a bit more complicated. Packets that are not destined to the management interface of your device are not visible to the CPU, and hence you can't capture it directly.

That is where the mirroring feature comes in. It allows you to copy the packets from a source interface to a mirror destination, where you would run your packet capture tool. By leveraging the ASIC capabilities, the mirroring feature is hardware-dependent, but luckily, SR Linux container image is built with mirroring support, so we can build a lab and play with mirroring in a close-to-real-world environment.

<!-- more -->

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
