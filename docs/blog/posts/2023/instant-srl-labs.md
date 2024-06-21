---
date: 2023-10-24
tags:
  - sr linux
  - containerlab
authors:
  - rdodin
---

# Instant SR Linux Labs

[Containerlab](https://containerlab.dev) already made it possible to quickly launch labs on demand with just a few commands. You would need to clone a repository with the lab and then call `containerlab deploy` to start the lab.

Simple enough, but quite often you want to run this simple SR Linux lab to test something quickly using a very basic topology. At times like this it is cumbersome to find and clone the repository and then call `deploy` command. Can we make it even more simple? Yes, we can!

<!-- more -->

If we have two steps to start a lab (cloning and calling `deploy`) we can combine them into one step by using two different approaches:

1. provide HTTP(S) URL to the deploy command and let containerlab fetch the clab file and deploy from it
2. provide GitHub/GitLab URL to the `deploy` command and [let containerlab clone the repo](https://containerlab.dev/cmd/deploy/#remote-topology-files) for us and deploy from it
3. curl the lab definition file from the repository and pipe it to `containerlab deploy` command

These approaches are equally simple, but they have quite distinct powers and limitations. Let's explore them in more detail.

/// warning
These features require [containerlab v0.48.2](https://containerlab.dev/install/) or later.
///

## Using HTTP(S) URL

Deploying a lab from a remote HTTP(S) URL is the simplest way to get a lab up and running. All you need to do is to provide the URL to the `deploy` command and containerlab will fetch the file and deploy from it.

```bash title="Deploying a lab from a remote URL"
sudo clab deploy -c -t https://srlinux.dev/clab-srl
```

<div class="embed-result">
```
INFO[0000] Containerlab v0.48.2 started
INFO[0000] Parsing & checking topology file: topo-2790519753.clab.yml
INFO[0000] Removing /root/srl-labs/learn-srlinux/clab-srl directory...
INFO[0000] Creating lab directory: /root/srl-labs/learn-srlinux/clab-srl
INFO[0000] Creating container: "srl"
INFO[0013] Adding ssh config for containerlab nodes
+---+------+--------------+------------------------------+---------------+---------+----------------+----------------------+
| # | Name | Container ID |            Image             |     Kind      |  State  |  IPv4 Address  |     IPv6 Address     |
+---+------+--------------+------------------------------+---------------+---------+----------------+----------------------+
| 1 | srl  | ee079defad8e | ghcr.io/nokia/srlinux:latest | nokia_srlinux | running | 172.20.20.2/24 | 2001:172:20:20::2/64 |
+---+------+--------------+------------------------------+---------------+---------+----------------+----------------------+
```
</div>

When deploying a clab file from a remote URL containerlab will download the clab file to a temporary directory - `/tmp/.clab` - and then perform a deploy command using the downloaded file. The temporary file will be deleted when the lab is destroyed with the cleanup flag provided.

Your Containerlab lab directory will still get created in the current working directory. While this is the default Containerlab behavior, it might not be quite useful for this particular case since you might want to quickly boot a lab from a dir where you don't want to see extra files popping up.

For this case, leverage `CLAB_LABDIR_BASE` env var to influence where Containerlab should put the lab directory:

```bash
CLAB_LABDIR_BASE=/tmp \
sudo -E containerlab deploy -c -t srlinux.dev/clab-srl
```

/// details | Where exactly is my topology file?
The lab file is downloaded to a temporary location as can be verified with the `containerlab inspect --all` command:

```note
$ containerlab inspect --all
+---+--------------------------------------------+----------+------+--------------+------------------------------+---------------+---------+----------------+----------------------+
| # |                 Topo Path                  | Lab Name | Name | Container ID |            Image             |     Kind      |  State  |  IPv4 Address  |     IPv6 Address     |
+---+--------------------------------------------+----------+------+--------------+------------------------------+---------------+---------+----------------+----------------------+
| 1 | ../../../tmp/.clab/topo-288756812.clab.yml | srl      | srl  | 6b5cad8a221d | ghcr.io/nokia/srlinux:latest | nokia_srlinux | running | 172.20.20.2/24 | 2001:172:20:20::2/64 |
+---+--------------------------------------------+----------+------+--------------+------------------------------+---------------+---------+----------------+----------------------+
```

///

Using HTTP-based lab deployment technique opens up a door to quickly deploy simple SR Linux labs with a single **mermorizable** command. This is handy when you need to quickly test something on SR Linux or demonstrate a feature to a colleague.

### Single node SR Linux lab

Here is the lab definition file that we used in the above example:

```yaml
--8<-- "https://raw.githubusercontent.com/srl-labs/containerlab/main/lab-examples/srl-quickstart/srl01.clab.yml"
```

As you can see, it is a simple single-node lab with SR Linux node named `srl`. This lab is meant for users who just want to quickly test something on a single SR Linux node and doesn't require any networking part to be configured.

The command can even be shortened further to:

```
sudo clab dep -c -t srlinux.dev/clab-srl
```

Once the lab is deployed you can type in `ssh srl` and get access to the SR Linux shell. Easy!

#### Parametrization

An attentive reader might have noticed that the lab definition file contains some environment variables. They allow to parametrize the lab definition file and change the SR Linux version or the type of the node.

If you deploy the commands as we did a few moments ago, the lab will be deployed with the default parameters:

* `ghcr.io/nokia/srlinux:latest` image will be used
* `ixrd3l` type will be used
* lab prefix is removed

If you wish to change the SR Linux version or the type, you can do so by providing the env vars to the `containerlab` command:

```bash title="Deploying a lab with a different image and type"
SRL_VERSION=23.10.1 SRL_TYPE=ixrd2 \
sudo containerlab deploy -c -t srlinux.dev/clab-srl
```

Since the default value for the lab prefix is an empty string, the node name (as well as container name) will be just `srl`. This makes it easy to connect to the node with `ssh srl` command, but if you want to deploy multiple labs with the same topology, you will need to change the prefix to avoid name collisions. Simply set `CLAB_PREFIX` variable to any value you want.

### Two-node SR Linux lab

In exactly the same spirit as the single-node lab, we thought it would be cool to have two SR Linux nodes connected back-to-back together. This lab can be deployed as:

```
sudo clab deploy -c -t https://srlinux.dev/clab-srl2
```

<div class="embed-result">
```
+---+------+--------------+------------------------------+---------------+---------+----------------+----------------------+
| # | Name | Container ID |            Image             |     Kind      |  State  |  IPv4 Address  |     IPv6 Address     |
+---+------+--------------+------------------------------+---------------+---------+----------------+----------------------+
| 1 | srl1 | 483cb7209697 | ghcr.io/nokia/srlinux:latest | nokia_srlinux | running | 172.20.20.4/24 | 2001:172:20:20::4/64 |
| 2 | srl2 | 936647611ade | ghcr.io/nokia/srlinux:latest | nokia_srlinux | running | 172.20.20.3/24 | 2001:172:20:20::3/64 |
+---+------+--------------+------------------------------+---------------+---------+----------------+----------------------+
```
</div>

This lab deploys nodes `srl1` and `srl2` and provides the same environment variables to parametrize the lab definition file.

### Limitations

The limitations of this approach is that clab file can not have external files used in the lab definition. For example, if you have a lab definition that relies on bind mounting of local files, you will not be able to deploy it from a remote URL. But thankfully we have a way to deploy labs from git repositories :wink:

## Using Git URL

Containerlab [added support](https://containerlab.dev/cmd/deploy/#git) for GitHub/GitLab URLs provided to the `deploy` command. The linked documentation article explains how different flavors of git URLs can be used to deploy labs from managed git repositories.

What is important for us here, is that we can now deploy full-blown labs by simply copying URL of the lab repository from the browser. Here is how it works:

<div class="iframe-container">
  <iframe width="100%" src="https://www.youtube.com/embed/0QlUZsJGQDo" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>

Because containerlab will clone the repository, the limitations of the previous approach are not applicable here. Your repository will be cloned in its entirety and therefore you will have access to all the files that are part of the repository. For example, deploying the SR Linux Streaming Telemetry Lab is as simple as:

```bash title="Deploying a lab from a git repository"
sudo clab dep -c -t https://github.com/srl-labs/srl-telemetry-lab
```

<div class="embed-result">
```
+----+------------+--------------+---------------------------------+---------------+---------+-----------------+--------------+
| #  |    Name    | Container ID |              Image              |     Kind      |  State  |  IPv4 Address   | IPv6 Address |
+----+------------+--------------+---------------------------------+---------------+---------+-----------------+--------------+
|  1 | client1    | 95ae7aa52c27 | ghcr.io/hellt/network-multitool | linux         | running | 172.80.80.31/24 | N/A          |
|  2 | client2    | 3996c8850794 | ghcr.io/hellt/network-multitool | linux         | running | 172.80.80.32/24 | N/A          |
|  3 | client3    | a3312bc21e21 | ghcr.io/hellt/network-multitool | linux         | running | 172.80.80.33/24 | N/A          |
|  4 | gnmic      | 7e0262a63604 | ghcr.io/openconfig/gnmic:0.33.0 | linux         | running | 172.80.80.41/24 | N/A          |
|  5 | grafana    | 31b1419f9d92 | grafana/grafana:10.2.1          | linux         | running | 172.80.80.43/24 | N/A          |
|  6 | leaf1      | 954283a965b6 | ghcr.io/nokia/srlinux:23.10.1   | nokia_srlinux | running | 172.80.80.11/24 | N/A          |
|  7 | leaf2      | b5fe74887300 | ghcr.io/nokia/srlinux:23.10.1   | nokia_srlinux | running | 172.80.80.12/24 | N/A          |
|  8 | leaf3      | 54f0d0592f12 | ghcr.io/nokia/srlinux:23.10.1   | nokia_srlinux | running | 172.80.80.13/24 | N/A          |
|  9 | loki       | 64735db32d5e | grafana/loki:2.9.2              | linux         | running | 172.80.80.46/24 | N/A          |
| 10 | prometheus | 28d62ea18df3 | prom/prometheus:v2.47.2         | linux         | running | 172.80.80.42/24 | N/A          |
| 11 | promtail   | 6a5526bca5d3 | grafana/promtail:2.9.2          | linux         | running | 172.80.80.45/24 | N/A          |
| 12 | spine1     | 03cab687a6a9 | ghcr.io/nokia/srlinux:23.10.1   | nokia_srlinux | running | 172.80.80.21/24 | N/A          |
| 13 | spine2     | b237260b25bf | ghcr.io/nokia/srlinux:23.10.1   | nokia_srlinux | running | 172.80.80.22/24 | N/A          |
| 14 | syslog     | 13188f89a169 | linuxserver/syslog-ng:4.1.1     | linux         | running | 172.80.80.44/24 | N/A          |
+----+------------+--------------+---------------------------------+---------------+---------+-----------------+--------------+
```
</div>

/// tip | Did you know?
For GitHub-hosted repos you can shrink the URL down to just as `user/repo`, for example:

```
sudo clab dep -c -t srl-labs/srl-telemetry-lab
```

///

## Using `curl`

And then lastly, you can use `curl`, `wget` or any other HTTP client to fetch the clab file and pipe it to `containerlab deploy` command. That way you can provide custom proxies to the HTTP client if required.

For example, deploying the same single-node SR Linux lab with `curl` can be done as:

```bash title="Deploying a lab from a remote URL with curl"
curl -sL srlinux.dev/clab-srl | sudo clab deploy -c -t -
```

## Summary

In this post we showed different ways to quickly deploy a single or two-node SR Linux lab using a simple, memorizable commands. Anywhere you are, you can just type in `curl -sL srlinux.dev/clab-srl | containerlab deploy -c -t -` and get a lab up and running in a matter of seconds.

We identified which limitations deployment from a remote URL has and how to overcome them by deploying labs from git repositories. Giving the flexibility in options whilst keeping the simplicity of the deployment process is what makes containerlab a great tool for SR Linux labs in particular and networking labs in general.
