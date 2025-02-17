---
date: 2023-11-07
tags:
  - sr linux
  - ssh
authors:
  - rdodin
---

# Sharing SR Linux Terminal with SSHX

Countless times I've been in a situation where I needed to share my terminal with someone or being asked to connect to someone's device instead.

Either I exhausted my networking foo and needed help from a colleague, or I was the one who was asked to help. In both cases, the problem was the same - how to **quickly**, **securely**[^1] and **effortlessly** share the terminal with someone else.

The problem is not new and there are many options on the table. From installing a VPN software and sharing the credentials, through zero-trust solutions like Teleport, to using a simple SSH tunnel. All of these solutions are great, but they require some setup and configuration. And sometimes you just want to share your terminal with someone without going through the hassle of setting up a VPN or a zero-trust solution.

The [sshx.io](https://sshx.io) open-source service that [just](https://twitter.com/ekzhang1/status/1721288674204131523) popped out offers a simple solution to this problem.

1. Install the multi-arch lightweight[^2] `sshx` binary on your machine
2. Run `sshx`
3. Share the URL with someone
4. Enjoy collaborative terminal in a responsive web UI with a multi panel canvas

I felt an immediate urge to try it out with SR Linux. And it worked like a charm!

<div class="iframe-container">
<iframe width="560" height="315" src="https://www.youtube.com/embed/-BByXtL6dNo?si=vkvZUUPsxg7GdF6R" title="Sharing SR Linux Terminal with SSHX" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
</div>

<!-- more -->

It is super easy to bring `sshx` to SR Linux, here is a quick demo environment that you can spin up to try it out:

1. Deploy a single-node SR Linux lab

    ```
    curl -sL srlinux.dev/clab-srl | sudo clab dep -c -t -
    ```

2. Login to the newly-created `srl` node

    ```
    ssh srl
    ```

3. In the SR Linux terminal go to `bash` and install `sshx`

    ```srl
    --{ running }--[  ]--
    A:srl# bash
    [admin@srl ~]$
    ```

4. Install `sshx`

    ```bash
    [admin@srl ~]$ curl -sSf https://sshx.io/get | sh
    ```

5. Run `sshx`, grab a link and pop up the Web UI with the terminal

    ```bash
    [admin@srl ~]$ sshx

    sshx v0.2.0

    ➜  Link:  https://sshx.io/s/bRPTeBxXiY#YKcwyLj03r0tik
    ➜  Shell: /bin/bash
    ```

[^1]: Usual security measures apply. Vet the installation binary, keep a vetted copy of the binary, etc.
[^2]: The binary is around 3MB in size
