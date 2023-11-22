---
comments: true
title: Show commands for TACACS
---

# TACACS

## TACACS Status

```srl
A:leaf1# show system aaa authentication session
+----+-------+-------------+----------------+----------+-------+-------------+--------
| ID | User  | Service     | Authentication | Priv-lvl | TTY   | Remote  | Login time 
+====+=======+=============+================+==========+=======+=========+===========|
| 4  | bob   | srlinux-cli | tacacs         | 15       | pts/1 | 2.1.0.2 | 2021-12-06T21:24:07.80Z | 
| 11 | user* | srlinux-cli | local          |          | pts/4 |         | 2021-12-07T04:06:06.93Z | 
+----+-------+-------------+----------------+----------+-------+---------+------------
```

## Active sessions on the router
```srl
A:leaf1# show system aaa authentication session
  +----+-----------+--------------+-----------------------+----------+-----+-------------------+--------------------------+------+
  | ID | User name | Service name | Authentication method | Priv-lvl | TTY |    Remote host    |        Login time        | Role |
  +====+===========+==============+=======================+==========+=====+===================+==========================+======+
  | 11 | admin*    | sshd         | local                 |          | ssh | 2001:172:20:20::1 | 2023-11-22T15:20:42.610Z |      |
  +----+-----------+--------------+-----------------------+----------+-----+-------------------+--------------------------+------+
```
