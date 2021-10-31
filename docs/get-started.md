SR Linux packs a lot of unique features that the data center networking teams can leverage.
Some of the features being truly new to the networking domain.
The goal of this portal is to introduce SR Linux to the visitors through the interactive tutorials centered around SR Linux services and capabilities.

We believe that learning by doing yields the best results. With that in mind we made SR Linux container image available to everybody without any registration or licensing requirements :partying_face:

The public SR Linux container image when powered by [containerlab](https://containerlab.srlinux.dev) allows us to create easily deployable labs that everyone can launch at their convenience. All that to let you not only read about the features we offer, but to try them live!

## SR Linux container image
A single container image that hosts management, control and data plane functions is all you need to get started.

### Getting the image
To make our SR Linux image available to everyone, we pushed it to a [publicly accessible GitHub container registry](https://github.com/orgs/nokia/packages/container/package/srlinux). This means that you can pull SR Linux container image exactly the same way as you would pull any other image:

```shell
docker pull ghcr.io/nokia/srlinux
```

When image is referenced without a tag, the latest container image version will be pulled. To obtain a specific version of a containerized SR Linux, refer to the [list of tags](https://github.com/orgs/nokia/packages/container/srlinux/versions) the `nokia/srlinux` image has and change the `docker pull` command accordingly.

### Running SR Linux
When the image is pulled to a local image store, you can start exploring SR Linux by either running a full-fledged lab topology, or by starting a single container to explore SR Linux CLI and its management interfaces.

A system on which you can run SR Linux containers should conform to the following requirements:

1. Linux OS with a kernel v4+[^1].
1. [Docker](https://docs.docker.com/engine/install/) container runtime.
1. At least 2 vCPU and 4GB RAM.
1. A user with administrative privileges.

Let's explore the different ways you can launch SR Linux container.

#### Docker CLI
`docker` CLI offers a quick way to run standalone SR Linux container:

```shell
docker run -t -d --rm --privileged \
  -u $(id -u):$(id -g) \
  --name srlinux ghcr.io/nokia/srlinux \
  sudo bash /opt/srlinux/bin/sr_linux
```

The above command will start the container named `srlinux` on the host system with a single management interface attached to the default docker network.

This approach is viable when all you need is to run a standalone container to explore SR Linux CLI or to interrogate its management interfaces. But it is not particularly suitable to run multiple SR Linux containers with links between them, as this requires some extra work.

For multi-node SR Linux deployments containerlab[^3] offers a better way.

#### Containerlab

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:4,&quot;zoom&quot;:1,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/containerlab/diagrams/containerlab.drawio&quot;}"></div>

<script type="text/javascript" src="https://cdn.jsdelivr.net/gh/hellt/drawio-js@main/embed2.js" async></script>

[Containerlab](https://containerlab.srlinux.dev) provides a CLI for orchestrating and managing container-based networking labs. It starts the containers, builds a virtual wiring between them and manages labs lifecycle.

A [quickstart guide](https://containerlab.srlinux.dev/quickstart/) is a perfect place to get started with containerlab. For the sake of completeness, let's have a look at the containerlab file that defines a lab with two SR Linux nodes connected back to back together:

```yaml
# file: srlinux.clab.yml
name: srlinux

topology:
  nodes:
    srl1:
      kind: srl
      image: ghcr.io/nokia/srlinux
    srl2:
      kind: srl
      image: ghcr.io/nokia/srlinux

  links:
    - endpoints: ["srl1:e1-1", "srl2:e1-1"]
```

By copying this file over to your system you can immediately deploy it with containerlab:

```shell
containerlab deploy -t srlinux.clab.yml
```
```
INFO[0000] Parsing & checking topology file: srlinux.clab.yml 
INFO[0000] Creating lab directory: /root/demo/clab-srlinux 
INFO[0000] Creating container: srl1                     
INFO[0000] Creating container: srl2                     
INFO[0001] Creating virtual wire: srl1:e1-1 <--> srl2:e1-1 
INFO[0001] Writing /etc/hosts file                      
+---+--------------------+--------------+-----------------------+------+-------+---------+----------------+----------------------+
| # |        Name        | Container ID |         Image         | Kind | Group |  State  |  IPv4 Address  |     IPv6 Address     |
+---+--------------------+--------------+-----------------------+------+-------+---------+----------------+----------------------+
| 1 | clab-srlinux-srl1  | 50826b3e3703 | ghcr.io/nokia/srlinux | srl  |       | running | 172.20.20.2/24 | 2001:172:20:20::2/64 |
| 2 | clab-srlinux-srl2  | 4d4494aba320 | ghcr.io/nokia/srlinux | srl  |       | running | 172.20.20.4/24 | 2001:172:20:20::4/64 |
+---+--------------------+--------------+-----------------------+------+-------+---------+----------------+----------------------+
```

#### Deployment verification
Regardless of the way you spin up SR Linux container it will be visible in the output of the `docker ps` command. If the deployment process went well and the container did not exit, a user can see it with `docker ps` command:

```shell
$ docker ps
CONTAINER ID   IMAGE                      COMMAND                  CREATED             STATUS             PORTS                    NAMES
4d4494aba320   ghcr.io/nokia/srlinux      "/tini -- fixuid -q …"   32 minutes ago      Up 32 minutes                               clab-learn-01-srl2
```

The logs of the running container can be displayed with `docker logs <container-name>`.

In case of the misconfiguration or runtime errors, container may exit abruptly. In that case it won't appear in the `docker ps` output as this command only shows running containers. Containers which are in the exited status will be part of the `docker ps -a` output.  
In case your container exits abruptly, check the logs as they typically reveal the cause of termination.

## Connecting to SR Linux
When SR Linux container is up and running, users can connect to it over different interfaces.

### CLI
One of the ways to manage SR Linux is via its advanced and extensible [Command Line Interface](kb/mgmt.md#sr-linux-cli).

To invoke the CLI application inside the SR Linux container get container name/ID first, and then execute the `sr_cli` process inside of it:

```shell
# get SR Linux container name -> clab-srl01-srl
$ docker ps
CONTAINER ID   IMAGE                             COMMAND                  CREATED          STATUS         PORTS                    NAMES
17a47c58ad59   ghcr.io/nokia/srlinux             "/tini -- fixuid -q …"   10 seconds ago   Up 6 seconds                            clab-learn-01-srl1
```
```shell
# start the sr_cli process inside this container to get access to CLI
docker exec -it clab-learn-01-srl1 sr_cli
Using configuration file(s): []
Welcome to the srlinux CLI.
Type 'help' (and press <ENTER>) if you need any help using this.
--{ running }--[  ]--                                                                                                                           
A:srl1#
```

The CLI can also be accessed via an SSH service the SR Linux container runs. Using the default credentials `admin:admin` you can connect to the CLI over the network:

```shell
# containerlab creates local /etc/hosts entries
# for container names to resolve to their IP
ssh admin@clab-learn-01-srl1

admin@clab-learn-01-srl1's password: 
Using configuration file(s): []
Welcome to the srlinux CLI.
Type 'help' (and press <ENTER>) if you need any help using this.
--{ running }--[  ]--                                                                                                                           
A:srl1#
```

### gNMI
SR Linux containers deployed with containerlab come up with gNMI interface up and running over port 57400.

Using the gNMI client[^2] users can explore SR Linux' gNMI interface:

```
gnmic -a clab-srlinux-srl1 --skip-verify -u admin -p admin capabilities
gNMI version: 0.7.0
supported models:
  - urn:srl_nokia/aaa:srl_nokia-aaa, Nokia, 2021-03-31
  - urn:srl_nokia/aaa-types:srl_nokia-aaa-types, Nokia, 2019-11-30
  - urn:srl_nokia/acl:srl_nokia-acl, Nokia, 2021-03-31
<SNIP>
```

[^1]: Centos 7.3+ although having a 3.x kernel is still capable of running SR Linux container
[^2]: for example [gnmic](https://gnmic.kmrd.dev)
[^3]: The labs referenced on this site are deployed with containerlab unless stated otherwise