---
date: 2024-09-12
tags:
  - arm64
authors:
  - rdodin
---

# SR Linux container image for ARM64

I still remember the day when we announced general availability of the SR Linux container image that everyone could just `docker pull` and start building their dream labs:

<figure><blockquote class="twitter-tweet"><p lang="en" dir="ltr">🚨This is not a drill🚨<br>🥳This day has come and I&#39;m delighted it has happened on my birthday.<br><br>🚀Nokia makes its Data Center NOS - SR Linux - available to everybody without any regwall, paywall, licwall or any other wall typical for a vendor<br><br>It is finally OUT! -&gt;🧵 <a href="https://x.com/ntdvps/status/1420786138009190404">pic.twitter.com/GguERBHGzp</a></p>&mdash; Roman Dodin (@ntdvps) <a href="https://twitter.com/ntdvps/status/1420786138009190404?ref_src=twsrc%5Etfw">July 29, 2021</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script></figure>

The availability of a free, lightweight and fast-to-boot containerized NOS served as a catalyst for the community to start building labs as code and use the image in the CI pipelines as it was easy and quick to run it on the free runners.  
However, the container image was only available for x86_64 architecture, and as a result for a long time we were saying that running SR Linux on macOS, for instance, was a "no-go".

It was not only about macOS, though. The rise of ARM-based server systems also made it hard to say that SR Linux can run on any compute you might have in your possession. I would lie if I say that we had RaspberryPi in mind, but hey, people run all kinds of workloads on rPI, why not networking labs?

And, finally, the day has come! We are happy to announce that the SR Linux container image is now available as a preview for ARM64 architecture, and is ready to be used on any ARM64 system, including devices with Apple M chips.

The first preview release is distributed via the same **ghcr.io/nokia** registry, but as long as we are in the preview cycle, we will use a separate tag for it:

```bash
sudo docker pull ghcr.io/nokia/srlinux:24.7.2-arm-preview
```

There is a lot to be said as to how SR Linux labs powered by [Containerlab](https://containerlab.dev) can be run on ARM64 systems, and to make it more interactive, I recorded a video about it:

<div class="iframe-container">
<iframe width="100%" src="https://www.youtube.com/embed/_BTa-CiTpvI" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>

Put those performance cores to work, and **lfl** (let's *ucking lab)! 🚀
