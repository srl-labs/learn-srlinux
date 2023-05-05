---
comments: true
tags:
  - yang
---

# SR Linux & YANG

<script type="text/javascript" src="https://cdn.jsdelivr.net/gh/hellt/drawio-js@main/embed2.js" async></script>
Model-driven (MD) interfaces are becoming essential for robust and modern Network OSes. The changes required to create fully model-driven interfaces can not happen overnight - it is a long and tedious process that requires substantial R&D effort.  
Traditional Network OSes often had to take an evolutionary route with adding MD interfaces on top of the existing internal infrastructure.

<figure markdown>
  ![yang1](https://gitlab.com/rdodin/pics/-/wikis/uploads/e691b456b77a70b4166a5fe343ff0c4e/yang_vis.webp){: class="img-shadow"}
  <figcaption>SR Linux ground-up support for YANG</figcaption>
</figure>

Unfortunately, bolting on model-driven interfaces while keeping the legacy internal infrastructure layer couldn't fully deliver on the promises of MD interfaces. In reality, those new interfaces had visibility discrepancies[^1], which often led to a situation where users needed to mix and match different interfaces to achieve some configuration goal. Apparently, without adopting a fully modeled universal API, it is impossible to make a uniform set of interfaces offering the same visibility level into the NOS.

Nokia SR Linux was ground-up designed with YANG[^2] data modeling taking a central role. SR Linux makes extensive use of structured data models with each application regardless if it's being provided by Nokia or written by a user has a YANG model that defines its configuration and state.

<figure markdown>
  ![yang1](https://gitlab.com/rdodin/pics/-/wikis/uploads/93cdee33ad7c14000ca6de203dc8459d/CleanShot_2021-11-12_at_12.00.40_2x.png)
  <figcaption>Both Nokia and customer's apps are modeled in YANG</figcaption>
</figure>

SR Linux exposes the YANG models to the supported management APIs. For example, the command tree in the CLI is derived from the SR Linux YANG models loaded into the system, and a gNMI client uses RPCs to configure an application based on its YANG model. When a configuration is committed, the SR Linux management server validates the YANG models and translates them into protocol buffers for the impart database (IDB).

With this design, there is no way around YANG; the data model is defined first for any application SR Linux has, then the CLI, APIs, and show output formats derived from it.

[rfc6020]: https://datatracker.ietf.org/doc/html/rfc6020
[rfc7950]: https://datatracker.ietf.org/doc/html/rfc7950

## SR Linux YANG Models

As YANG models play a central role in SR Linux NOS, it is critical to have unobstructed access. With that in mind, we offer SR Linux users many ways to get ahold of SR Linux YANG models:

1. Download modules from SR Linux NOS itself.
    The models can be found at `/opt/srlinux/models/*` location.
2. Fetch modules from [`nokia/srlinux-yang-models`](https://github.com/nokia/srlinux-yang-models) repo.
3. Use SR Linux YANG Browser to consume modules in a human-friendly way

SR Linux employs a uniform mapping between a YANG module name and the CLI context, making it easy to correlate modules with CLI contexts.

<figure>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:0,&quot;zoom&quot;:1.5,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/yang.drawio&quot;}"></div>
  <figcaption>YANG modules and CLI aligned</figcaption>
</figure>

The structure of the Nokia SR Linux native models may look familiar to the OpenConfig standard, where different high-level domains are contained in their modules.

Source `.yang` files are great for YANG-based automation tools such as [ygot](https://github.com/openconfig/ygot) but are not so easy for a human's eye. For living creatures, we offer a [YANG Browser](browser.md) portal. We suggest people use it when they want to consume the models in a non-programmable way.

[^1]: indicated by the blue color on the diagram and explained in detail in [NFD25 talk](https://youtu.be/yyoZk9hqptk?t=65).
[^2]: [RFC 6020][rfc6020] and [RFC 7950][rfc7950]
