---
date: 2024-01-06
tags:
  - ssh
  - terrapin
  - security
authors:
  - rdodin
---

# SSH Terrapin Attack and Network Operating Systems

<small> Discussions: [:material-twitter:][twitter-discuss] · [:material-linkedin:][linkedin-discuss]</small>

> [Terrapin][terrapin] is a prefix truncation attack targeting the SSH protocol. More precisely, Terrapin breaks the integrity of SSH's secure channel.

Pretty scary stuff, innit? Any Network Engineer/Admin understands the importance of SSH in their daily work. It's the most common way to access network devices, and it's the most secure way to do so. Is it now?

On December 18th 2023, a group of researchers from the Ruhr University Bochum publicly disclosed a new attack ([CVE-2023-48795: General Protocol Flaw][cve]) on SSH protocol, called [Terrapin][terrapin]. Targeting the very best SSH Binary Packet Protocol researchers proved that an attacker can remove an arbitrary amount of messages sent by the client or server at the beginning of the secure channel without the client or server noticing it.

But what does it mean to us, Network Engineers? Do we need to rush the vendors patching the SSH servers in their NOSes? Let's figure it out.

<!-- more -->

///warning | Disclaimer

1. This is **not** an official Nokia alert or security response to the CVE-2023-48795. This is merely a practical exercise to identify the scope of the vulnerability when applied to some popular Network Operating Systems.
2. I'm not a security expert, and I'm not a cryptographer.

///

With the disclaimer above, I feel obliged to start with the references to the materials written by people who are way more experienced in the field of cryptography and security than I am. I highly recommend reading the following articles/papers to get a better/deeper understanding of the attack:

1. [Terrapin Attack Website][terrapin]
2. [Terrapin Attack pre-print Paper][terrapin-paper]
3. [SSH protocol flaw – Terrapin Attack CVE-2023-48795: All you need to know][jfrog] by JFrog
4. [RedHat Security Bulletin for CVE-2023-48795][redhat]
5. [SSH protects the world’s most sensitive networks. It just got a lot weaker][ars] by ArsTechnica

## Attack Requirements and Impact

TLDR; Terrapin attack requires:

1. An Attacker establishing a MitM position in the network tcp/ip layer to intercept SSH session negotiation.
2. SSH server and client to negotiate either `chacha20-poly1305` cipher mode or any encrypt-then-mac variants (generic EtM) as only these modes are vulnerable to the attack.

With these requirements satisfied, the attacker can delete consecutive messages on the secure channel; However, deleting most messages at this protocol stage prevents user authentication from proceeding, leading to a stalled connection.

The most significant identified impact is that it enables a MITM to delete the SSH2_MSG_EXT_INFO message sent before authentication begins. This allows the attacker to disable a subset of keystroke timing obfuscation features. However, there is no other observable impact on session secrecy or session integrity.[^1]

As you can see, the requirements are pretty much substantial. The attacker needs to be in the middle of the SSH session negotiation and if the attacker is in the middle of your management network, you have bigger problems than Terrapin attack. Still, it is a valid concern, and most SSH servers were fast to release patches to close the vulnerability. This strict requirements contributed to the medium severity score of 5.9.

### Cipher Modes Selection

What about the requirement for a client and server to negotiate either `chacha20-poly1305` cipher mode or any encrypt-then-mac variants (generic EtM) as only these modes are vulnerable to the attack? If you think the chances of this happening are slim, you are about to be surprised.

Most recent OpenSSH versions offer `chacha20-poly1305` as the first cipher mode in the list of supported ciphers. The client sends the list of supported ciphers to the server during the SSH session negotiation. The server then selects the first cipher mode from the list that is also supported by the server. So, chances are very high that your client and server will end up using `chacha20-poly1305` cipher mode.

For example, here is a list of ciphers that client and server exchange during the SSH session negotiation between my SSH client (OpenSSH_9.0p1, LibreSSL 3.3.6) on MacOS 13.6.3 and OpenSSH server (OpenSSH_8.9p1 Ubuntu-3ubuntu0.6, OpenSSL 3.0.2 15 Mar 2022) on Ubuntu 22.04 LTS:

```
$ ssh -vv -n nesc_ce78_devbox1 2>&1 | grep chacha

debug2: ciphers ctos: chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com
debug2: ciphers stoc: chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com
debug2: ciphers ctos: chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com
debug2: ciphers stoc: chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com
debug1: kex: server->client cipher: chacha20-poly1305@openssh.com MAC: <implicit> compression: none
debug1: kex: client->server cipher: chacha20-poly1305@openssh.com MAC: <implicit> compression: none
```

As you can see, the first cipher mode in the list is `chacha20-poly1305` which is vulnerable to the attack being selected (as it should).

## Network Operating Systems and Terrapin Attack

Ok, OK, but what about Network Operating Systems? Are they affected by the attack? It is not hard to imagine that most NOSes use OpenSSH as their SSH server, so they are likely to be affected by the attack. Let's check.

To keep it practical, I used Containerlab to spin up a few popular NOSes on my server and tested them for vulnerability using the [terrapin-scanner][scanner].

///details | Containerlab topology

```yaml
name: mv

topology:
  nodes:
    srlinux:
      kind: nokia_srlinux
      image: ghcr.io/nokia/srlinux:23.10.1

    ceos:
      kind: arista_ceos
      image: registry.srlinux.dev/pub/ceos:4.30.3M

    xrd:
      kind: cisco_xrd
      image: registry.srlinux.dev/pub/xrd/xrd-control-plane:7.8.1

    sros:
      kind: nokia_sros
      license: sros23.key
      image: registry.srlinux.dev/pub/vr-sros:23.10.R1

    junos_evo:
      kind: juniper_vjunosevolved
      image: registry.srlinux.dev/pub/vr-vjunosevolved:23.2R1-S1.8-EVO

    junos_switch:
      kind: juniper_vjunosswitch
      image: registry.srlinux.dev/pub/vr-vjunosswitch:23.2R1.14

    # VMX is EOL, should we bother?
    # vmx:
    #   kind: juniper_vmx
    #   image: registry.srlinux.dev/pub/vr-vmx:22.2R1.9

    vqfx:
      kind: juniper_vqfx
      image: registry.srlinux.dev/pub/vr-vqfx:20.2R1.10

    iosxr:
      kind: cisco_xrv9k
      image: registry.srlinux.dev/pub/vr-xrv9k:7.10.1

    aoscx:
      kind: aruba_aoscx
      image: registry.srlinux.dev/pub/vr-aoscx:10.07.0010
    ros:
      kind: mikrotik_ros
      image: registry.srlinux.dev/pub/vr-ros:7.13

  links:
    - endpoints: ["iosxr:eth1", "host:xr-eth1"]
```

///

| NOS                    | Version         | Vulnerable? | ChaCha20[^2]       | EtM[^3]            | Notes                                  |
| ---------------------- | --------------- | ----------- | ------------------ | ------------------ | -------------------------------------- |
| Nokia SR Linux         | 23.10.1         | **Yes**     | :white_check_mark: | :no_entry:         | SSH-2.0-OpenSSH_9.2p1 Debian-2+deb12u1 |
| Nokia SR OS            | 23.10.R1        | No          | :no_entry:         | :no_entry:         | SSH-2.0-OpenSSH_8.9                    |
| Arista cEOS            | 4.30.3M         | No          | :no_entry:         | :no_entry:         | SSH-2.0-OpenSSH_7.8                    |
| Cisco XRd              | 7.8.1           | **Yes**     | :white_check_mark: | :no_entry:         | SSH-2.0-OpenSSH_8.0 PKIX[12.1]         |
| Cisco IOS XRv9k        | 7.10.1          | **Yes**     | :no_entry:         | :white_check_mark: | SSH-2.0-Cisco-2.0                      |
| Juniper vJunos Evolved | 23.2R1-S1.8-EVO | **Yes**     | :white_check_mark: | :no_entry:         | SSH-2.0-OpenSSH_7.5                    |
| Juniper vJunos Switch  | 23.2R1.14       | **Yes**     | :white_check_mark: | :no_entry:         | SSH-2.0-OpenSSH_7.5                    |
| Juniper vQFX           | 20.2R1.10       | **Yes**     | :white_check_mark: | :no_entry:         | SSH-2.0-OpenSSH_7.5                    |
| Aruba AOS-CX           | 10.07.0010      | **Yes**     | :white_check_mark: | :no_entry:         | SSH-2.0-OpenSSH_8.0 PKIX[Portable]     |
| Mikrotik RouterOS      | 7.13            | No          | :no_entry:         | :no_entry:         | SSH-2.0-ROSSSH                         |

As you can see, most NOSes are affected by the attack as most of the server implementations are based on OpenSSH and offer `chacha20-poly1305` cipher mode. Systems with old or supposedly custom/proprietary SSH server implementations are not affected by the attack, but they may not be immune to other vulnerabilities.

The vulnerability check was performed using the following script that leverages the official scanner tool:

```bash
#!/bin/bash

# list of systems to test
arr=(
"clab-mv-srlinux"
"clab-mv-sros"
"clab-mv-ceos"
"clab-mv-xrd"
"clab-mv-junos_evo"
"clab-mv-junos_switch"
"clab-mv-vqfx"
"clab-mv-aoscx"
"clab-mv-iosxr"
"clab-mv-ros"
)

# Loop over the array
for i in "${arr[@]}"
do
    echo -e "\033[1m################################################################################\033[0m"
    echo -e "\033[1mExecuting command for: $i\033[0m"
    echo -e "\033[1m################################################################################\033[0m"
    docker run --rm -t --network clab ghcr.io/hellt/terrapin-scanner:1.1.0 --connect $i
    echo
    echo
    echo
done
```

The raw output of the script, when executed against the Containerlab topology above, can be found [here](https://gist.github.com/hellt/346117c124186ef9d077aa7c6b9ab1fb).

## SR Linux and Terrapin Attack mitigation

In SR Linux, we use the upstream OpenSSH server implementation from the Debian distribution as of 23.10.1 release. Since Debian patched the vulnerability in their OpenSSH implementation, we will benefit from the upstream fix and provide the updated binaries in SR Linux 24.3.1.

/// note

The management network should already be significantly protected from access by unwanted entities. When the access to the management network (and thus the SR Linux SSH server) is properly protected and only highly trusted entities have access, the severity and risk of the vulnerability are also significantly lower.

As stated in the disclaimer at the beginning of the article, this is not an official Nokia alert or security response to the CVE-2023-48795. For an official response, please get in touch with your Nokia representative.

///

Still, if you wish to mitigate the attack in your current SR Linux release, you can do so by disabling the `chacha20-poly1305` cipher mode in the SSH server configuration. To do so, you may create the following sshd configuration file:

```
admin@srl:~$ echo "Ciphers -chacha20-poly1305@openssh.com" \
    | sudo tee /etc/ssh/sshd_config.d/terrapin.conf
```

This file will remove the `chacha20-poly1305` cipher mode from the list of supported ciphers on the SR Linux SSH server side, effectively removing the vulnerable cipher mode from the list of supported ciphers and mitigating the attack.

Once the configuration file is created, you need to restart the SSH server using the `tools` command in SR Linux CLI:

```srl
--{ running }--[ ]--
A:srl# tools app-management application sshd-mgmt restart

/system/app-management/application[name=sshd-mgmt]:
    Application 'sshd-mgmt' was killed with signal 9

/system/app-management/application[name=sshd-mgmt]:
    Application 'sshd-mgmt' was restarted
```

After the SSH server is restarted, you can verify that the scanner tool reports the vulnerability as mitigated:

```
❯ docker run --rm -t --network clab ghcr.io/hellt/terrapin-scanner:1.1.0 --connect clab-mv-srlinux
================================================================================
==================================== Report ====================================
================================================================================

Remote Banner: SSH-2.0-OpenSSH_9.2p1 Debian-2+deb12u1

ChaCha20-Poly1305 support:   false
CBC-EtM support:             false

Strict key exchange support: false

The scanned peer supports Terrapin mitigations and can establish
connections that are NOT VULNERABLE to Terrapin. Glad to see this.
For strict key exchange to take effect, both peers must support it.
```

## Summary

Terrapin attack demonstrates a novel approach to weaken the SSH protocol that affects most SSH servers deployed in the networks. Luckily, the requirement for an attacker to establish a MitM position in the network tcp/ip layer to intercept SSH session negotiation and SSH server and client to negotiate either `chacha20-poly1305` cipher mode or any encrypt-then-mac variants (generic EtM) reduces the attack surface significantly.

The management network should already be significantly protected from access by unwanted entities. When the access to the management network is properly protected and only highly trusted entities have access, the severity and risk of the vulnerability are also significantly lower.

Anyhow, it poses a valid concern for Network operators and vendors alike. The attack affects Most Network OSes, and vendors are likely to patch their SSH server implementations in due time. SR Linux is not an exception, but we are lucky to use the upstream OpenSSH server implementation from the Debian distribution, which was patched in the latest security release. And SR Linux users can still mitigate the attack in their current SR Linux devices by disabling the `chacha20-poly1305` cipher mode in the SSH server configuration.

You can follow up on or share the discussion on [Twitter][twitter-discuss] or [LinkedIn][linkedin-discuss].

[terrapin]: https://terrapin-attack.com/
[cve]: https://nvd.nist.gov/vuln/detail/CVE-2023-48795
[terrapin-paper]: https://terrapin-attack.com/TerrapinAttack.pdf
[jfrog]: https://jfrog.com/blog/ssh-protocol-flaw-terrapin-attack-cve-2023-48795-all-you-need-to-know/
[redhat]: https://access.redhat.com/security/cve/cve-2023-48795
[ars]: https://arstechnica.com/security/2023/12/hackers-can-break-ssh-channel-integrity-using-novel-data-corruption-attack/
[scanner]: https://github.com/RUB-NDS/Terrapin-Scanner
[twitter-discuss]: https://twitter.com/ntdvps/status/1743798974736175478
[linkedin-discuss]: https://www.linkedin.com/feed/update/urn:li:activity:7149567441105219584/

[^1]: As per [RedHat Security Bulletin][redhat] for CVE-2023-48795
[^2]: chacha20-poly1305 cipher is supported by the server
[^3]: encrypt-then-mac variants (generic EtM) ciphers are supported by the server
