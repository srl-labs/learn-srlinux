---
date: 2023-10-24
tags:
  - sr linux
  - containerlab
authors:
  - rdodin
---

# Immediate SR Linux Labs

With [containerlab](https://containerlab.dev) we already made it possible to quickly launch labs on demand with just a few commands. You would need to clone a repository with the lab and then call `containerlab deploy` to start the lab.

Simple enough, but quite often you want to run this simple SR Linux lab to test something quickly using a very basic topology. At times like this it is cumbersome to find and clone the repository and then call `deploy` command. Can we make it even more simple? Yes, we can!

<!-- more -->

If we have two steps to start a lab (cloning and calling `deploy`) we can combine them into one step by using two different approaches:

1. curl the lab definition file from the repository and pipe it to `containerlab deploy` command
2. provide the github URL to the `deploy` command and [let it do the cloning](https://containerlab.dev/cmd/deploy/#remote-topology-files) for us

Both approaches are equally simple and can be used interchangeably, but they have some differences in the way they work. We will cover the `curl` approach as it is more akin to the goals of this post - which is to quickly start a tiny lab with SR Linux.

## Using curl to deploy a lab

The workflow boils down to getting the lab definition file contents from a remote location and pipe it to `containerlab deploy` command. Since most labs are stored in git repositories, using `curl` is likely the most convenient way to get the file contents.

```bash title="using stdin to deploy a lab"
curl some.url | containerlab deploy -c -t -
```

Since we wanted to let our users deploy basic SR Linux labs using a memorizable command, we created the following topology files hosted in the containerlab repository:

=== "Single SR Linux node"
    This lab defines a single SR Linux node named `clab-srl`. This lab is meant for users who just want to quickly test something on a single SR Linux node.

    ```yaml
    --8<-- "https://raw.githubusercontent.com/srl-labs/containerlab/main/lab-examples/srl-quickstart/srl01.clab.yml"
    ```

=== "Two SR Linux nodes"
    This lab defines two SR Linux nodes named `clab-srl1` and `clab-srl2` connected with two links. In this lab users can test protocol interactions between two SR Linux nodes.

    ```yaml
    --8<-- "https://raw.githubusercontent.com/srl-labs/containerlab/main/lab-examples/srl-quickstart/srl02.clab.yml"
    ```

And here is how you can deploy an Single node SR Linux lab with an easy to remember command:

```{.bash .no-select}
curl -sL srlinux.dev/clab-srl | containerlab deploy -c -t -
```

<div class="embed-result">
```bash
INFO[0000] Containerlab v0.47.0 started
INFO[0000] Parsing & checking topology file: topo-4226352936.clab.yml
INFO[0000] Removing /root/srl-labs/learn-srlinux/clab-clab directory...
INFO[0000] Creating docker network: Name="clab", IPv4Subnet="172.20.20.0/24", IPv6Subnet="2001:172:20:20::/64", MTU='֪'
INFO[0000] Creating lab directory: /root/srl-labs/learn-srlinux/clab-clab
INFO[0000] Creating container: "srl"
INFO[0001] Running postdeploy actions for Nokia SR Linux 'srl' node
INFO[0014] Adding containerlab host entries to /etc/hosts file
INFO[0014] Adding ssh config for containerlab nodes
+---+------+--------------+------------------------------+---------------+---------+----------------+----------------------+
| # | Name | Container ID |            Image             |     Kind      |  State  |  IPv4 Address  |     IPv6 Address     |
+---+------+--------------+------------------------------+---------------+---------+----------------+----------------------+
| 1 | srl  | 6b5cad8a221d | ghcr.io/nokia/srlinux:latest | nokia_srlinux | running | 172.20.20.2/24 | 2001:172:20:20::2/64 |
+---+------+--------------+------------------------------+---------------+---------+----------------+----------------------+
```
</div>

??? "Where is my topology downloaded to?"
    The lab file is downloaded to a temporary location as can be verified with the `containerlab inspect --all` command:

    ```note
    $ containerlab inspect --all
    +---+--------------------------------------------+----------+------+--------------+------------------------------+---------------+---------+----------------+----------------------+
    | # |                 Topo Path                  | Lab Name | Name | Container ID |            Image             |     Kind      |  State  |  IPv4 Address  |     IPv6 Address     |
    +---+--------------------------------------------+----------+------+--------------+------------------------------+---------------+---------+----------------+----------------------+
    | 1 | ../../../tmp/.clab/topo-288756812.clab.yml | srl      | srl  | 6b5cad8a221d | ghcr.io/nokia/srlinux:latest | nokia_srlinux | running | 172.20.20.2/24 | 2001:172:20:20::2/64 |
    +---+--------------------------------------------+----------+------+--------------+------------------------------+---------------+---------+----------------+----------------------+
    ```

Now you can type in `ssh srl` and get access to the SR Linux shell. Easy!

In the same spirit you can deploy a two-node SR Linux lab with a similar command (watch out for the `clab-srl2` name in the URL):

```{.bash .no-select}
curl -sL srlinux.dev/clab-srl2 | containerlab deploy -c -t -
```

## Parametrizing the lab

If you run the above commands as is, the labs will be deployed with the default parameters:

* `ghcr.io/nokia/srlinux:latest` image will be used
* `ixrd3l` type will be used

If you wish to change the SR Linux version or the type, you can do so by providing the env vars to the `containerlab` command:

```bash title="Deploying a lab with a different image and type"
curl -sL srlinux.dev/clab-srl | \
SRL_VERSION=23.3.2 SRL_TYPE=ixrd2 \
containerlab deploy -c -t -
```

## Summary

In this post we showed how to quickly deploy a single or two-node SR Linux lab using a simple command. Anywhere you are you can just type in `curl -sL srlinux.dev/clab-srl | containerlab deploy -c -t -` and get a lab up and running in a matter of seconds.
