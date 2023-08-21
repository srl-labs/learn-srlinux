#!/bin/bash
ip link set address 00:c1:ab:00:00:21 dev eth1
ip link set address 00:c1:ab:00:00:22 dev eth2
ip link set address 00:c1:ab:00:00:23 dev eth3
ip link add dev vrf-1 type vrf table 1
ip link set dev vrf-1 up
ip link set dev eth1 master vrf-1
ip link add dev vrf-2 type vrf table 2
ip link set dev vrf-2 up
ip link set dev eth2 master vrf-2
ip link add dev vrf-3 type vrf table 3
ip link set dev vrf-3 up
ip link set dev eth3 master vrf-3
ip addr add 192.168.0.21/24 dev eth1
ip addr add 192.168.0.22/24 dev eth2
ip addr add 192.168.0.23/24 dev eth3