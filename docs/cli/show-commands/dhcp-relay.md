---
comments: true
title: Show commands for DHCP Relay
---

# DHCP Relay

## DHCP Relay Status

```srl
A:srl-b# info from state interface ethernet-1/1 subinterface 1 ipv4 dhcp-relay
    interface ethernet-1/1 {
        subinterface 1 {
            ipv4 {
                dhcp-relay {
                    admin-state enable
                    oper-state down
                    gi-address 192.168.101.1
                    use-gi-addr-as-src-ip-addr true
                    option [
                        circuit-id
                        remote-id
                    ]
                    server [
                        172.16.32.1
                        172.16.64.1
                    ]
                }
```
