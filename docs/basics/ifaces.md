On the SR Linux, an interface is any physical or logical port through which packets can be sent to or received from other devices.

## Loopback
Loopback interfaces are virtual interfaces that are always up, providing a stable
source or destination from which packets can always be originated or received.
The SR Linux supports up to 256 loopback interfaces system-wide, across all
network instances. Loopback interfaces are named `loN`, where N is 0 to 255.

## System
The system interface is a type of loopback interface that has characteristics that
do not apply to regular loopback interfaces:

- The system interface can be bound to the default network-instance only.
- The system interface does not support multiple IPv4 addresses or multiple
IPv6 addresses.
- The system interface cannot be administratively disabled. Once configured, it is always up.

The SR Linux supports a single system interface named `system0`. When the system interface is bound to the default network-instance, and an IPv4 address is configured for it, the IPv4 address is the default local address for multi-hop BGP sessions to IPv4 neighbors established by the default network-instance, and it is the default IPv4 source address for IPv4 VXLAN tunnels established by the default network-instance.  
The same functionality applies with respect to IPv6 addresses / IPv6 BGP neighbors / IPv6 VXLAN tunnels.

## Network
Network interfaces carry transit traffic, as well as originate and terminate control plane traffic and in-band management traffic.

The physical ports in line cards installed in the SR Linux are network interfaces. A typical line card has a number of front-panel cages, each accepting a pluggable transceiver. Each transceiver may support a single channel or multiple channels, supporting one Ethernet port or multiple Ethernet ports, depending on the transceiver type and its breakout options.

In the SR Linux CLI, each network interface has a name that indicates its type and its location in the chassis. The location is specified with a combination of slot number and port number, using the following formats: `ethernet-slot/port`. For example, interface `ethernet-2/1` refers to the line card in slot 2 of the SR Linux chassis, and port 1 on that line card.

On 7220 IXR-D3 systems, the QSFP28 connector ports (ports `1/3-1/33`) can operate in breakout mode. Each QSFP28 connector port operating in breakout
mode can have four breakout ports configured, each operating at 25G. Breakout ports are named using the following format: `ethernet-slot/port/breakout-port`.

For example, if interface `ethernet 1/3` is enabled for breakout mode, its breakout ports are named as follows:

- `ethernet 1/3/1`
- `ethernet 1/3/2`
- `ethernet 1/3/3`
- `ethernet 1/3/4`

## Management
Management interfaces are used for out-of-band management traffic. The SR Linux supports a single management interface named `mgmt0`. The `mgmt0` interface supports the same functionality and defaults as a network
interface, except for the following:

- Packets sent and received on the mgmt0 interface are processed
completely in software.
- The mgmt0 interface does not support multiple output queues, so there is
no output traffic differentiation based on forwarding class.
- The mgmt0 interface does not support pluggable optics. It is a fixed 10/100/
1000-BaseT copper port.

## Integrated Routing and Bridging (IRB)
IRB interfaces enable inter-subnet forwarding. Network instances of type mac-vrf are associated with a network instance of type ip-vrf via an IRB interface.

## Subinterfaces
On the SR Linux, each type of interface can be subdivided into one or more
subinterfaces. A subinterface is a logical channel within its parent interface.

Traffic belonging to one subinterface can be distinguished from traffic belonging to
other subinterfaces of the same port using encapsulation methods such as 802.1Q
VLAN tags.

While each port can be considered a shared resource of the router that is usable by
all network instances, a subinterface can only be associated with one network
instance at a time. To move a subinterface from one network instance to another, you
must disassociate it from the first network instance before associating it with the
second network instance.

You can configure ACL policies to filter IPv4 and/or IPv6 packets entering or leaving
a subinterface.

The SR Linux supports policies for assigning traffic on a subinterface to forwarding
classes or remarking traffic at egress before it leaves the router. DSCP classifier
policies map incoming packets to the appropriate forwarding classes, and DSCP
rewrite-rule policies mark outgoing packets with an appropriate DSCP value based
on the forwarding class