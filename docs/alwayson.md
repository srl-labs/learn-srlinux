# Always-ON SR Linux Instance

<script type="text/javascript" src="https://cdn.jsdelivr.net/gh/hellt/drawio-js@main/embed2.js" async></script>
It is extremely easy and hassle free to run SR Linux, thanks to the [public container image](get-started/lab.md#sr-linux-container-image-and-containerlab) and topology builder tool - [containerlab](https://containerlab.srlinux.dev).

But wouldn't it be nice to have an SR Linux instance running in the cloud open for everyone to tinker with? We think it would, so we created an **Always-ON SR Linux** instance that we invite you to try out.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:1,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/alwayson&quot;}"></div>

## What is Always-ON SR Linux for?

The Always-ON SR Linux instance is an Internet reachable SR Linux container running in the cloud. Although running in the read-only mode, the Always-ON instance can unlock some interesting use cases, which won't require anything but Internet connection from a curious user.

* **getting to know SR Linux CLI**  
    SR Linux offers a modern, extensible CLI with unique features aimed to make Ops teams life easier.  
    New users can make their first steps by looking at the `show` commands, exploring the datastores, running `info from` commands and getting the grips of configuration basics by entering into the configuration mode.

* **YANG browsing**  
    By being a YANG-first Network OS, SR Linux is fully modelled with YANG. This means that by traversing the CLI users are inherently investigating the underlying YANG models that serve the base for all the programmable interfaces SR Linux offers.

* **gNMI exploration**  
    The de-facto king of the Streaming Telemetry - [gNMI](https://github.com/openconfig/reference/blob/master/rpc/gnmi/gnmi-specification.md) - is one of the programmable interfaces of SR Linux.  
    gNMI is enabled on the Always-ON instance, so anyone can stream the data out of the SR Linux and see how it works for themselves.

## Connection details

Always-ON SR Linux instance comes up with the SSH and gNMI management interfaces exposed. The following table summarizes the connection details for each of those interfaces:

| Method       | Details                                                                                                                                                                                                                         |
| :----------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| SSH          | address: `ssh guest@on.srlinux.dev -p 44268`<br/>password: `n0k1asrlinux`<br/><br/>for key-based authentication use [this key](https://gist.github.com/hellt/d2b9f99a2fcfeeb7752d9fe187fbff86) to authenticate the `guest` user |
| gNMI[^1]     | <pre><code>gnmic -a on.srlinux.dev:39010 -u guest -p n0k1asrlinux --skip-verify \<br/>      capabilities</code></pre>                                                                                                           |
| JSON-RPC[^2] | http://http.on.srlinux.dev                                                                                                                                                                                                      |

[^1]: an example of invoking a gNMI Capabilities RPC using [gnmic](https://gnmic.openconfig.net) CLI client.

### gNMI

SR Linux runs a TLS-enabled gNMI server with a certificate already present on the system. The users of the gNMI interface can either skip verification of the node certificate, or they can use this [CA.pem](https://gist.github.com/hellt/f5c1d97a37c86c20e3370a392c073cc0) file to authenticate the node's TLS certificate.

## Guest user

The `guest` user has the following settings applied to it:

1. Read-only mode
2. `bash` and `file` commands are disabled

Although the read-only mode is enforced, the guest user can still enter in the configuration mode and perform configuration actions, it is just that `guest` can't commit them.

## Always-ON sandbox setup

The Always-ON sandbox consists of SR Linux node connected with a LAG interface towards an Nokia SR OS node.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:0,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/learn-srlinux/diagrams/alwayson&quot;}"></div>

### Protocols and Services

We pre-created a few services on the SR Linux node so that you would see a "real deal" configuration- and state-wise.

The underlay configuration consists of the two L3 links between the nodes with eBGP peering built on link addresses. The system/loopback interfaces are advertised via eBGP to enable overlay services.

In the overlay the following services are configured:

1. Layer 2 EVPN with VXLAN dataplane[^1] with `mac-vrf-100` network instance created on SR Linux
2. Layer 3 EVPN with VXLAN dataplane with `ip-vrf-200` network instance created on SR Linux

[^1]: check [this tutorial](tutorials/l2evpn/intro.md) to understand how this service is configured
[^2]: HTTP service running over port 80
