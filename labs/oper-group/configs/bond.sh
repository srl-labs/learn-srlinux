ip link add bond0 type bond mode 802.3ad
ip link set dev bond0 type bond xmit_hash_policy layer3+4
ip link set dev eth1 down
ip link set dev eth2 down
ip link set eth1 master bond0
ip link set eth2 master bond0
ip link set dev eth1 up
ip link set dev eth2 up
ip link set dev bond0 type bond lacp_rate fast
ip link set dev bond0 up