# NoPorts - SSH & gNMI access with no listening ports

|                          |                                                                                                                                                                                                   |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Description**          | NoPorts agent makes `sshnpd` a native SR Linux feature: operators reach the router over SSH — and gNMI/JSON-RPC via `npt` — with no inbound listening ports open on the management plane              |
| **Components**           | [Nokia SR Linux][srl], [NoPorts][noports], [atProtocol][atsign]                                                                                                                                       |
| **Programming Language** | Go (built with [`srl-labs/bond`][bond])                                                                                                                                                               |
| **Source Code**          | [`atsign-foundation/noports-srlinux`][src]                                                                                                                                                            |
| **Additional resources** | [NoPorts documentation][noports-docs]                                                                                                                                                                 |
| **Authors**              | Colin Constable [:material-github:][auth1_github]                                                                                                                                                    |

## Introduction

Management-plane access normally means an open SSH (and often gNMI) port on
every router — visible to network scans and protected only by ACLs. NoPorts
inverts the model: the router runs a small daemon (`sshnpd`) that keeps only
*outbound* connections to the atProtocol control plane, and sessions are
established end-to-end encrypted via a rendezvous relay. Nothing listens on
the box; there is nothing to scan.

## The agent

The `noports` NDK agent (built with [bond][bond]) makes this a native router
feature rather than a hand-managed daemon:

* **Configuration lives in the SR Linux config tree** — with full
  candidate/commit/rollback semantics, persisted in the startup config and
  streamable over gNMI:

    ```srl
    --{ candidate shared default }--[  ]--
    A:leaf1# set / noports device-atsign @mydevice
    A:leaf1# set / noports access managers [ @noc ]
    A:leaf1# set / noports device name leaf1
    A:leaf1# set / noports admin-state enable
    A:leaf1# commit now
    ```

    On every commit the agent renders NoPorts' own `sshnpd.yaml` config file
    and supervises the daemon inside the `srbase-mgmt` namespace, restarting
    it on config changes or failures.

* **Operational state** (`oper-state`, `pid`, daemon version) is published
  to `/noports/state`:

    ```srl
    A:leaf1# info from state / noports state
        state {
            oper-state running
            pid 4242
            sshnpd-version "Version : 5.15.1"
        }
    ```

* **Device onboarding uses APKAM enrollment**: cryptographic keys are cut
  *on the router* with a one-time passcode and approved from an
  administrator's machine; no key files are ever copied to the device.

* **Locked-down management VRFs**: `set / noports root-server
  proxy:proxy0001.atsign.org:443` collapses all atProtocol control-plane
  traffic to a single host on port 443 for environments with strict egress
  ACLs.

Installation is a single `.deb` package (SR Linux 24.3.1+), and every
release is smoke-tested in CI against the free SR Linux container image in
containerlab — including the full NDK round-trip: CLI commit → config
delivery → agent → state publication.

## Try it

You will need two Atsigns (one for the router, one for you) from
[noports.com][noports], and the NoPorts client on your machine. Grab the
`.deb` (amd64 and arm64) from the [releases page][releases], then on the
router:

```bash
# from the SR Linux CLI, drop to the shell with `bash`
sudo dpkg -i noports-srlinux_*.deb   # postinstall reloads app_mgr
```

Configure from the SR Linux CLI:

```srl
--{ candidate shared default }--[  ]--
A:srl# set / noports device-atsign @mydevice
A:srl# set / noports access managers [ @manager ]
A:srl# set / noports device name srl-1
A:srl# set / noports admin-state enable
A:srl# commit now
```

Onboard the device (keys are cut on the router; nothing is copied to it):

```bash
at_activate otp -a @mydevice                    # on your machine
sudo /opt/noports/onboard-noports.sh <passcode> # on the router (bash)
at_activate approve -a @mydevice --arx noports --drx srl-1  # on your machine
```

The agent detects the keys within ~15 seconds and starts the daemon
(`info from state / noports state` shows `oper-state running`). Connect
from anywhere:

```bash
sshnp -f @manager -t @mydevice -d srl-1 -u admin
```

No router hardware needed: the [repo quickstart][quickstart] has a
containerlab lab and a standalone plain-Docker lab (runs on Apple Silicon
via the multi-arch SR Linux image), plus the verified client flags for
networks that only permit outbound 443.

[srl]: https://www.nokia.com/networks/products/service-router-linux-NOS/
[noports]: https://noports.com
[noports-docs]: https://docs.noports.com
[atsign]: https://atsign.com
[bond]: https://github.com/srl-labs/bond
[src]: https://github.com/atsign-foundation/noports-srlinux
[releases]: https://github.com/atsign-foundation/noports-srlinux/releases
[quickstart]: https://github.com/atsign-foundation/noports-srlinux/blob/trunk/QUICKSTART.md
[auth1_github]: https://github.com/cconstab
