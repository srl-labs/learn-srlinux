#!/bin/bash
ip link add bond0 type bond mode 802.3ad
ip link set address 00:c1:ab:00:00:11 dev bond0
ip addr add 192.168.0.11/24 dev bond0
ip link set eth1 down 
ip link set eth2 down
ip link set eth1 master bond0
ip link set eth2 master bond0
ip link set eth1 up 
ip link set eth2 up  
ip link set bond0 up