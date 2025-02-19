---
comments: true
title: KNE Topology
---

# KNE Topology

Everything is ready for KNE users to create network topologies when [installation](installation.md) steps are out of the way. KNE offers a declarative way of defining network topologies using a topology file that captures the state of a topology. Topology message in the [`topo.proto`][topo.proto] file defines the schema that the KNE topology follows. Consult with the schema to see which fields a topology can have.

KNE topology file can be provided in the following formats:

1. Prototext[^1] - original format of a KNE topology.
2. YAML file - an additional format supported by KNE which is converted to prototext.

Both prototext and YAML files offer the same functionality; given the dominance of the prototext format in the kne repository, we will use this format in the tutorial.

!!!tip
    The parts of the topology used in this section are taken from the [`2node-srl-ixr6-with-oc-services.pbtxt`][srl-with-oc-topo-file] topology file hosted at the kne repository.

## Topology Name

As with most configuration elements, a network topology is identified by a `name` property that must be unique for each deployed lab, as it will create a namespace lab's resources.

```proto
name: "2-srl-ixr6"
```

The name is an arbitrary string.

## Node

The main constituents of a KNE topology are nodes and links between them. In the topology file, each node is defined as a repeated element of the `nodes` message:

```proto title="nodes definition in a topology file (prototext format)"
nodes: {
    // first node parameters
}

nodes: {
    // second node parameters
}
```

Node definition has quite some parameters[^2]. We will cover the most common of them.

### Name

Each node must have a name, which is a free-formed string:

```proto
nodes: {
    name: "srl1"
    // other node parameters snipped for brevity
}
```

### Vendor

The vendor field is provided to let KNE know which vendor is defined within the node section. KNE supports several vendors; the full list is provided in the [topo.proto](https://github.com/openconfig/kne/blob/v0.1.9/proto/topo.proto#L32) file.

```proto
nodes: {
    vendor: NOKIA // (1)!
    // other node parameters snipped for brevity
}
```

1. Note, the vendor value needs to be provided exactly as defined in the Vendor enum field of the proto file. Without quotes.

!!!note
    Some KNE examples may utilize the `type` parameter with a value of `NOKIA_SRL` or similar. This field will be deprecated in favor of the separate fields: `vendor`/`model`/`os`/`version`.

The vendor field must be set to `NOKIA` when working with Nokia SR Linux nodes.

### Model

With the `model` field a user indicates which particular model of a given Vendor should be used by the node. In the context of Nokia SR Linux, the `model` field drives the hardware variant that an SR Linux container will emulate.

```proto
nodes: {
    model: "ixrd3l"
    // other node parameters snipped for brevity
}
```

### Config

Parameters that configure the way a k8s pod representing a network node is deployed are grouped under the [Config](https://github.com/openconfig/kne/blob/9d835bbaa1e4b26ab03b0d456461a044f2ec9ea0/proto/topo.proto#L112) message.

#### Image

The essential field under the Config block is `image`. It sets the container image name that k8s will use in the pod specification.

```proto
nodes: {
    config:{
        image: "ghcr.io/nokia/srlinux:22.6.4"
    }
    // other node parameters snipped for brevity
}
```

!!!note
    1. In the [`2node-srl-ixr6-with-oc-services.pbtxt`][srl-with-oc-topo-file] the image is omitted, as the intention there to use the latest available image, which is a default value for the `image` field.
    2. When `kind` cluster is used, users might want to [load the container image](installation.md#image-load) before creating the topologies.

#### File

Often it is desired to deploy a node with a specific startup configuration applied. KNE enables this use case by using the `file` parameter of a `Config` message. A path to the startup configuration file is provided using the path relative to the topology file.

```proto
nodes: {
    config:{
        file: "my-startup-config.json"
    }
    // other node parameters snipped for brevity
}
```

In the snippet above, the `my-stratup-config.json` is expected to be found next to the topology file.

For SR Linux nodes, the startup file can be provided in a JSON format (as found in `/etc/opt/srlinux/config.json` on SR Linux filesystem) or in the CLI format[^3].

#### TLS Certificates

KNE lets users indicate if they want the network nodes to generate self-signed certificates upon boot. The following configuration blob instructs a node to generate a self-signed certificate with a name `kne-profile` and a key size of `4096`.

```proto
nodes: {
    config: {
        cert: {
            self_signed: {
                cert_name: "kne-profile",
                key_name: "N/A",
                key_size: 4096,
            }
        }
    }
}
```

Under the hood, SR Linux node will execute the `tools system tls generate-self-signed` command with the appropriate key size and save the TLS artifacts under the TLS server-profile context.

!!!note
    Since on SR Linux it is possible to embed TLS artifacts in the config file itself, you may often see labs where the startup-config files are already populated with the TLS configuration.

### Services

Applications deployed on Kubernetes are not accessible outside the cluster until an Ingress or Load Balancer service is configured to enable that connectivity. Consequently, network elements deployed by KNE have their management services available internally within the cluster, but not from the outside.  
For the users of the virtual network labs, it is imperative to have external connectivity to the management services running on the nodes to manage the virtual network. In KNE external network connectivity is enabled by the [MetalLB](https://metallb.universe.tf) Load Balancer service and a particular configuration block in the Node specification.

```proto
nodes: {
    // other node parameters snipped for brevity
    services:{
        key: 22
        value: {
            name: "ssh"
            inside: 22
            outside: 22
        }
    }
    services:{
        key: 9339
        value: {
            name: "gnmi"
            inside: 57400 // (1)!
            outside: 9339
        }
    }
}
```

1. gNMI service running on port `57400` will be accessible externally by port `9339` as specified in the `outside` field.

The above snippet enables SSH and gNMI services to be available outside the k8s cluster.

The `key` field is a unique integer identifier in the map of services; it is typically set to the outside port of the exposed service.

Within the `value` block, a user specifies the service parameters:

- `name`: a free-formed string describing the service.
- `inside`: a port number that the service is running on a network node.
- `outside`: a port number, which will be configured on a Load Balancer and mapped to the `internal` port. This mapping effectively enables external access to the service.

Courtesy of the MetalLB Load Balancer service, the defined services will be exposed using the IP addresses from your cluster network using the port mappings as defined in the `services` portion of the node specification.

```bash title="Management services exposed by Load Balancer"
❯ kubectl get svc -n 2-srl-ixr6
NAME           TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                        AGE
service-srl1   LoadBalancer   10.96.72.99     172.18.0.50   22:30281/TCP,57400:30333/TCP   2m7s # (1)!
service-srl2   LoadBalancer   10.96.135.142   172.18.0.51   57400:31443/TCP,22:30266/TCP   2m6s
```

1. SSH service of `srl1` node is accessible externally via `172.18.0.50:22`  
    gNMI service of `srl1` node is accessible externally via `172.18.0.50:57400`

### Links

With `links` object of a topology, users wire up the nodes together. The link is defined as a pair `a_node/a_int <--> z_int/z_node`.

```proto
links: {
    a_node: "srl1"
    a_int: "e1-1"
    z_node: "srl2"
    z_int: "e1-1"
}
```

The above `links` object creates a Layer2 virtual wire between the nodes `srl1` and `srl2` using the interface names `e1-1` on both ends.

```console
  a_node                       z_node
 ┌──────┐ a_int          z_int┌──────┐
 │      ├─────┐         ┌─────┤      │
 │ srl1 │e1-1 ├─────────┤e1-1 │ srl2 │
 │      ├─────┘         └─────┤      │
 └──────┘                     └──────┘
```

!!!note
    Pay attention to the interface name specified for SR Linux nodes. Containerized SR Linux node uses `eX-Y` notation for its network interfaces where  
      `X` - linecard number  
      `Y` - port number

    Example: `e1-1` interface is mapped to `ethernet-1/1` interface of SR Linux which is a first port on a first linecard.

### Interfaces

The link name provided in the [links](#links) section of the topology defines a name of a Linux interface created in the network namespace of a particular pod. However, this name rarely matches the interface name used by the Network OS.

For example, for Nokia SR Linux, the Linux interface notation must follow `eX-Y` schema, but when configuring these interfaces over any management protocol, users should use `ethernet-X/Y` form. Since such mapping is different between vendors, KNE users can provide the mapping in the topology file to let external systems know which Linux interface name maps to which internal name.

```proto
nodes: {
    // other node parameters snipped for brevity
    interfaces: {
        key: "e1-1"
        value: {
            name: "ethernet-1/1"
        }
    }
```

!!!note
    It is not mandatory to provide interface mapping information if no external system that needs to know this mapping will be used.

[topo.proto]: https://github.com/openconfig/kne/blob/v0.1.9/proto/topo.proto
[srl-with-oc-topo-file]: https://github.com/openconfig/kne/blob/v0.1.9/examples/nokia/srlinux-services/2node-srl-ixr6-with-oc-services.pbtxt

[^1]: https://developers.google.com/protocol-buffers/docs/text-format-spec
[^2]: full specification of a Node element is contained in the [topology proto file](https://github.com/openconfig/kne/blob/v0.1.9/proto/topo.proto#L46-L84).
[^3]: Support for the CLI-styled configs has been added in https://github.com/srl-labs/srl-controller/pull/37
