On the SR Linux, you can configure one or more virtual routing instances, known as
network instances. Each network instance has its own interfaces, its own protocol
instances, its own route table, and its own FIB.

When a packet arrives on a subinterface associated with a network instance, it is
forwarded according to the FIB of that network instance. Transit packets are normally
forwarded out another subinterface of the network instance.

SR Linux supports the following types of network instances:

* default
* ip-vrf
* mac-vrf

The initial startup configuration for SR Linux has a single `default` network instance.

By default, there are no ip-vrf or mac-vrf network instances; these must be created
by explicit configuration. The ip-vrf network instances are the building blocks of Layer
3 IP VPN services, and mac-vrf network instances are the building blocks of EVPN
services.

Within a network instance, you can configure BGP, OSPF, and IS-IS protocol options
that apply only to that network instance.

