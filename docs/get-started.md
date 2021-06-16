SR Linux packs a lot of unique features that datacenter networking teams can leverage.
Some of the features being truly new to the networking domain.
The goal of this portal is to introduce SR Linux to the visitors by demonstrating those features.

We believe that learning by doing yields the best results. With that in mind we made SR Linux container image available to everybody without any registration or licensing requirements :partying_face:

The public SR Linux container image when powered by [containerlab](https://containerlab.srlinux.dev) allows us to create easily deployable labs that everyone can launch at their convenience. All that to let you not only read about the features we offer, but to try them live!

## SR Linux container image
A single container image that hosts management, control and data plane functions is all you need to get started.

### Getting the image
To make our SR Linux image easily available to everyone, we push it to publicly accessible container registry. This means that you can pull SR Linux container image exactly the same way as you would pull any other image:

```shell
docker pull __SRLINUX_CONTAINER_IMAGE__
```

### Running SR Linux
When the image is pulled to a local image store, you can start exploring SR Linux by either running a full-blown lab scenario, or by starting a single container to explore SR Linux CLI and its management interfaces.

A system on which you can run SR Linux containers should conform to the following requirements

1. Linux OS with a kernel v4+.
1. Container runtime installed. We will use [Docker](https://docs.docker.com/engine/install/) as it is the most common way to run containers.
1. At least 2 vcpu and 4GB RAM.
1. A user with administrative privileges

Let's explore different ways you can launch SR Linux container.

#### Docker CLI
A `docker` CLI tool offers a quick way to run standalone SR Linux container:

```shell
docker run -t -d --rm --privileged \
  -u $(id -u):$(id -g) \
  --name srlinux __SRLINUX_CONTAINER_IMAGE__ \
  sudo bash /opt/srlinux/bin/sr_linux
```

The above command will start the container named `srlinux` on the host system with a single management interface attached to the default docker network.

This approach is viable when all you need is to run a standalone container to explore SR Linux CLI or to interrogate its management interfaces. But it is not particularly suitable to run multiple SR Linux containers with links between them, as this requires some scripting.

For multi-node SR Linux deployments containerlab offers a better way.

#### Containerlab
[Containerlab](https://containerlab.srlinux.dev) provides a CLI for orchestrating and managing container-based networking labs. It starts the containers, builds a virtual wiring between them to create lab topologies of users choice and manages labs lifecycle.

A [quickstart](https://containerlab.srlinux.dev/quickstart/) guide is a perfect place to start with containerlab. For the sake of completeness, we provide here a containerlab file that defines a lab with two SR Linux nodes connected back to back together:

```yaml
# file: srl-demo.clab.yml
name: srlinux

topology:
  nodes:
    srl1:
      kind: srl
      image: __SRLINUX_CONTAINER_IMAGE__
    srl2:
      kind: srl
      image: __SRLINUX_CONTAINER_IMAGE__

  links:
    - endpoints: ["srl1:e1-1", "srl2:e1-1"]
```

By copying this file over to your system you can immediately deploy it with containerlab:

```shell
containerlab deploy -t srl-demo.clab.yml

# TODO: insert lab deployment output
```

The labs we created for demonstrating SR Linux features will use containerlab as a means to deploy them.

#### Deployment verification
Regardless of the way you spin up SR Linux container it will be visible for `docker` CLI. If the deployment process went well and the container did not exit, a user can see it with `docker ps` command:

```shell
docker ps
# TODO: change to srlinux public image name
CONTAINER ID   IMAGE                             COMMAND                  CREATED        STATUS        PORTS             NAMES
75d3fdb25565   srlinux:21.3.1-410                "/tini -- fixuid -q …"   46 hours ago   Up 46 hours                     srlinux
```

The logs of the running container can be displayed with `docker logs <container-name>`.

In case of the misconfiguration or runtime errors, container may exit abruptly. In that case it won't appear in the `docker ps` output as it only shows running containers. Containers which are in the exited status will be part of the `docker ps -a` output. In case your container exits abruptly, check the logs as they typically reveal the cause of termination.

## Connecting to SR Linux
When SR Linux container is up and running, users can connect to it over different interfaces.

### CLI
One of the ways to manage SR Linux is via its advanced and extensible Command Line Interface.

To invoke the CLI application inside the SR Linux container:

```shell
# get SR Linux container name -> clab-srl01-srl
CONTAINER ID   IMAGE                             COMMAND                  CREATED          STATUS         PORTS                    NAMES
17a47c58ad59   srlinux:21.3.1-410                "/tini -- fixuid -q …"   10 seconds ago   Up 6 seconds                            clab-srl01-srl

# start the sr_cli process inside this container to get access to its CLI
docker exec -it clab-srl01-srl sr_cli
Using configuration file(s): []
Welcome to the srlinux CLI.
Type 'help' (and press <ENTER>) if you need any help using this.
--{ running }--[  ]--                                                                                                                           
A:srl#
```

The CLI can also be accessed via SSH service the SR Linux container runs. Using the default credentials `admin:admin` we can connect to the CLI over the network:

```shell
# containerlab creates local /etc/hosts entries
# for container names to resolve to their IP
ssh admin@clab-srl01-srl

Warning: Permanently added 'clab-srl01-srl,2001:172:20:20::2' (ECDSA) to the list of known hosts.
admin@clab-srl01-srl's password: 
Using configuration file(s): []
Welcome to the srlinux CLI.
Type 'help' (and press <ENTER>) if you need any help using this.
--{ running }--[  ]--                                                                                                                           
A:srl#
```

### gNMI
SR Linux containers deployed with containerlab come up gNMI interface up and running over port 57400.

Using the gNMI client such as [gnmic](https://gnmic.kmrd.dev) users can explore SR Linux' gNMI interface:

```
gnmic -a clab-srl01-srl --skip-verify -u admin -p admin capabilities
gNMI version: 0.7.0
supported models:
  - urn:srl_nokia/aaa:srl_nokia-aaa, Nokia, 2021-03-31
  - urn:srl_nokia/aaa-types:srl_nokia-aaa-types, Nokia, 2019-11-30
  - urn:srl_nokia/acl:srl_nokia-acl, Nokia, 2021-03-31
<SNIP>
```
