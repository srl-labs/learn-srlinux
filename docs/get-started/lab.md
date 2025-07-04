# SR Linux Lab

## SR Linux container image and Containerlab

We wanted to make SR Linux the most accessible Network OS. With that in mind we made SR Linux container image available to everybody without any registration or licensing requirements :partying_face:

The public SR Linux container image when powered by [containerlab][containerlab] allows users to build virtual labs with SR Linux in no time. All that to let you not only read about the features we offer, but to try them live!

A single container image that hosts management, control and data plane functions is all you need to get started.

The container image is hosted at the [publicly accessible GitHub container registry](https://github.com/orgs/nokia/packages/container/package/srlinux). This means that you can pull SR Linux container image exactly the same way as you would pull any other image.

Because SR Linux simulator image is distributed exclusively in a container packaging, it offers great startup times (~1min) and extremely resource friendly[^1]. Because of its containerized nature, we wanted to create a lab orchestration tool that would play nicely with containerized Network OSes and be more "as code" when compared to traditional GUI-based network virtualization tools. Enter [containerlab][containerlab].

Containerlab is an open source project that provides a CLI for orchestrating and managing container-based networking labs. It starts the containers, builds a virtual wiring between them and manages labs lifecycle.

The extremely low footprint of Containerlab and YAML-based topology definition made it a perfect fit for the SR Linux-based labs.

## Lab prerequisites

You are minutes away from deploying your first SR Linux lab using containerlab. But first, you need to [install containerlab](https://containerlab.dev/install/) and Docker on any Linux system, which can be as easy as running a single installation command[^2]:

```bash
curl -sL https://containerlab.dev/setup | sudo -E bash -s "all"
```

Make sure, that your Linux host satisfies the following requirements:

1. Linux OS with a kernel v4.10+
2. At least 2 vCPU and 6GB RAM available
3. A user with administrative privileges

## Deploying a lab

Everything is ready for the lab deployment. We are going to spin up this lovely topology with two leaf and one spine switches making up our tiny fabric with two clients connected.

-{{ diagram(url='srl-labs/srlinux-getting-started/main/diagrams/topology.drawio', title='Lab Topology', page=0) }}-

How do we deploy it? Enter in some directory where the lab is about to be cloned and run this one-liner:

```{.bash .no-select}
sudo containerlab deploy -c -t \
  https://github.com/srl-labs/srlinux-getting-started #(1)!
```

1. This is not a containerlab tutorial so we won't dive into what happens under the hood after you run this command. In short, containerlab pulled the lab topology from the GitHub repository and started the lab.

    Feel free to explore containerlab's documentation to learn more about the tool.

In less than a minute, you should have the lab running with the summary table of the deployed nodes presented by containerlab:

```
+---+---------+--------------+------------------------------------+---------------+---------+----------------+----------------------+
| # |  Name   | Container ID |               Image                |     Kind      |  State  |  IPv4 Address  |     IPv6 Address     |
+---+---------+--------------+------------------------------------+---------------+---------+----------------+----------------------+
| 1 | client1 | 9b3955f9ab50 | ghcr.io/srl-labs/network-multitool | linux         | running | 172.20.20.8/24 | 2001:172:20:20::8/64 |
| 2 | client2 | 50d068413361 | ghcr.io/srl-labs/network-multitool | linux         | running | 172.20.20.4/24 | 2001:172:20:20::4/64 |
| 3 | leaf1   | f1643c11603b | ghcr.io/nokia/srlinux:24.10.4      | nokia_srlinux | running | 172.20.20.7/24 | 2001:172:20:20::7/64 |
| 4 | leaf2   | fb50f174cb73 | ghcr.io/nokia/srlinux:24.10.4      | nokia_srlinux | running | 172.20.20.6/24 | 2001:172:20:20::6/64 |
| 5 | spine1  | 8162d45caac9 | ghcr.io/nokia/srlinux:24.10.4      | nokia_srlinux | running | 172.20.20.5/24 | 2001:172:20:20::5/64 |
+---+---------+--------------+------------------------------------+---------------+---------+----------------+----------------------+
```

/// details | Running SR Linux container without containerlab?
    type: subtle-question

There are not a lot of reasons not to use containerlab, but "not a lot" doesn't mean there aren't any. You can run SR Linux container image with `docker` CLI as well, but of course, you will have to do more things manually.

```bash
sudo docker run -t -d --rm --privileged \
  -u 0:0 \
  -v srl23-7-1.json:/etc/opt/srlinux/config.json \ #(1)!
  --name srlinux ghcr.io/nokia/srlinux:23.7.1 \
  sudo bash /opt/srlinux/bin/sr_linux
```

1. By default container starts with a factory config, if you want to start with a custom config, mount it to `/etc/opt/srlinux/config.json` path.  
    In this example, [config](https://gist.github.com/hellt/3f695394d705ed2bf016f7919ba90018) created by [containerlab](https://containerlab.dev) is mounted to the container.

The above command will start the container named `srlinux` emulating the D3L hardware variant on the host system with a single management interface attached to the default docker network.

To connect to the CLI of the container you can either use `docker exec -it srlinux sr_cli` or SSH to the container over the network:

```shell
# default password is NokiaSrl1!
ssh admin@$(docker inspect -f '{{.NetworkSettings.IPAddress}}' srlinux)
```

Using docker CLI is a viable approach when all you need is to run a standalone container to explore SR Linux CLI or to use its management interfaces. However, it is not particularly suitable to run multiple SR Linux containers with links between them, as this requires some extra work.

For multi-node SR Linux deployments containerlab offers a better way.

<h3>Deployment verification</h3>

Regardless of the way you spin up SR Linux container it will be visible in the output of the `docker ps` command. If the deployment process went well and the container did not exit, a user can see it with `docker ps` command:

```shell
$ docker ps
CONTAINER ID   IMAGE                      COMMAND                  CREATED             STATUS             PORTS                    NAMES
4d4494aba320   ghcr.io/nokia/srlinux      "/tini -- fixuid -q …"   32 minutes ago      Up 32 minutes                               clab-learn-01-srl2
```

The logs of the running container can be displayed with `docker logs <container-name>`.

In case of the misconfiguration or runtime errors, container may exit abruptly. In that case it won't appear in the `docker ps` output as this command only shows running containers. Containers which are in the exited status will be part of the `docker ps -a` output.  
In case your container exits abruptly, check the logs as they typically reveal the cause of termination.
///

## Connecting to the SR Linux nodes

Now that the lab is ready, we can connect to the nodes directly from the host system using the node names as seen in the table above. Let' connect to the `leaf1` node.

```{.bash .no-select}
ssh leaf1 #(1)!
```

1. Containerlab automatically creates a `/etc/hosts` to map the node names to the IP addresses and creates an ssh config entry with the default username - `admin` - associated with the SR Linux node names, hence we can simply omit the username in our ssh command.

    If you have any ssh keys on your host, containerlab will provision them to the SR Linux container so that the login would be possible without a password, but if the key is not present, you will be prompted for the password, which is `NokiaSrl1!` by default.

<div class="embed-result">
```{.srl .no-select .no-copy}
Warning: Permanently added 'leaf1' (ED25519) to the list of known hosts.
................................................................
:                  Welcome to Nokia SR Linux!                  :
:              Open Network OS for the NetOps era.             :
:                                                              :
:    This is a freely distributed official container image.    :
:                      Use it - Share it                       :
:                                                              :
: Get started: https://learn.srlinux.dev                       :
: Container:   https://go.srlinux.dev/container-image          :
: Docs:        https://doc.srlinux.dev/24-10                   :
: Rel. notes:  https://doc.srlinux.dev/rn24-10-4               :
: YANG:        https://yang.srlinux.dev/v24.10.4               :
: Discord:     https://go.srlinux.dev/discord                  :
: Contact:     https://go.srlinux.dev/contact-sales            :
................................................................

Using configuration file(s): ['/home/admin/.srlinuxrc']
Welcome to the srlinux CLI.
Type 'help' (and press <ENTER>) if you need any help using this.

--{ running }--[  ]--
A:leaf1#

```
</div>

Alright, we are in, let's get familiar with the SR Linux CLI!

:octicons-arrow-right-24: [Get to know SR Linux CLI](cli.md)

/// admonition | Lab management cheatsheet
    type: code-example

Here are some useful commands to manage your lab:

```bash title="List lab nodes"
sudo containerlab inspect --all
```

```bash title="destroy the get started lab (execute from within the <code>srlinux-getting-started</code> directory)"
sudo containerlab destroy -c
```

```bash title="redeploy the get started lab"
sudo containerlab deploy -c -t \
  https://github.com/srl-labs/srlinux-getting-started
```

///

[^1]: Each node requires 2vCPU and 2GB of RAM.
[^2]: Looking for other installation options? Check out [containerlab installation docs](https://containerlab.dev/install/).

[containerlab]: https://containerlab.dev/

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
