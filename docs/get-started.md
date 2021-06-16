SR Linux packs a lot of unique features that datacenter networking teams can leverage.
Some of the features being truly new to the networking domain.
The goal of this portal is to introduce SR Linux to the visitors by demonstrating those features.

We believe that learning by doing yields the best results. With that in mind we made SR Linux container image available to everybody without any registration or licensing requirements :partying_face:

The public SR Linux container image when powered by [containerlab](https://containerlab.srlinux.dev) allows us to create easily deployable labs that everyone can launch at their convenience. All that to let you not only read about the features we offer, but to try them live!

## SR Linux container image
A single container image that hosts management, control and data plane functions is all you need to get started.

### Getting the image
To make our SR Linux image easily accessible to eveyone, we push it to publicly accessible container registry. This means that you can pull SR Linux container image exactly the same way as you would pull a regular image:

```shell
docker pull __SRLINUX_CONTAINER_IMAGE__
```

!!!note "Restrictions of the unlicensed image"
    The freely available SR Linux container image can run both with and without a license.  
    When license file is not provided, the dataplane throughput will be limited to 100pps and the srlinux application will reboot every 45 days.  
    But don't worry, these limitations will have no impact on the labbing activities this image is designed to be used for.

### Running SR Linux
When the image is pulled to a local image store, you can start exploring SR Linux by either running a full-blown lab scenario, or by starting a single container to explore SR Linux CLI or its management interfaces.

Let's explore the ways of running SR Linux container.

#### Docker CLI
A `docker` CLI tool can be used to run SR Linux containers. For example, to run a single standalone SR Linux container in a daemon mode:

```shell
docker run -t -d --rm --privileged \
  -u $(id -u):$(id -g) \
  --name srlinux __SRLINUX_CONTAINER_IMAGE__ \
  sudo bash /opt/srlinux/bin/sr_linux
```

This approach is viable when all you need is to run a standalone container to explore SR Linux CLI or to interrogate its management interfaces.

#### Containerlab

Use `docker ps` to verify "srlinux-dut1" container is running

```shell
CONTAINER ID   IMAGE                             COMMAND                  CREATED        STATUS        PORTS             NAMES
75d3fdb25565   srlinux:21.3.1-410                "/tini -- fixuid -q …"   46 hours ago   Up 46 hours                     srlinux-dut1
```

Attach to SR Linux CLI

```shell
docker exec -it srlinux-dut1 sr_cli
```

See [Usage](usage/basics.md) for basic command examples


### Optional - Docker Compose

Make sure [Docker Compose](https://docs.docker.com/compose/install/) is installed.

Create this `docker-compose.yml` file

```yaml
version: "3"
services:
  srlinux:
    container_name: srlinux-dut1
    image: srlinux:21.3.1-410
    privileged: true
    user: "${CURRENT_UID}"
    command: sudo sh -c "/opt/srlinux/bin/sr_linux"
    restart: "no"
```

Launch using this command

```shell
CURRENT_UID=$(id -u):$(id -g) docker-compose up -d
```

Remove the container when done

```shell
CURRENT_UID=$(id -u):$(id -g) docker-compose down
```