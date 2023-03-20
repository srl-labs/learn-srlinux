---
comments: true
---

# SR Linux with Openconfig services

| Summary                     |                                                                                                                                              |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| **Tutorial name**           | SR Linux with KNE                                                                                                                            |
| **Lab components**          | 2 Nokia SR Linux nodes                                                                                                                       |
| **Resource requirements**   | :fontawesome-solid-microchip: 2 vCPU <br/>:fontawesome-solid-memory: 4 GB                                                                    |
| **Lab**                     | [kne/examples/srlinux/2node-srl-ixr6-with-oc-services.pbtxt][lab]                                                                            |
| **Main ref documents**      | [kne documentation][knedoc]                                                                                                                  |
| **Version information**[^1] | [`kne v0.1.9`][kne-install], [`srlinux:22.11.2`][srlinux-container], [`srl-controller:0.5.0`][srl-controller], [`kind:0.17.0`][kind-install] |
| **Authors**                 | Roman Dodin [:material-twitter:][rd-twitter] [:material-linkedin:][rd-linkedin]                                                              |

KNE repository contains a set of [example topologies](https://github.com/openconfig/kne/tree/main/examples) that aim to help new users get started with using KNE to orchestrate virtual network labs. SR Linux team maintains several examples, which include SR Linux nodes.

This chapter explains the details behind the [`2node-srl-ixr6-with-oc-services.pbtxt`](https://github.com/openconfig/kne/blob/main/examples/nokia/srlinux-services/2node-srl-ixr6-with-oc-services.pbtxt) example topology.

## Topology diagram

The lab topology aims to introduce KNE users to labs with Nokia SR Linux nodes and acquaint them with Openconfig services running on SR Linux. Two Nokia SR Linux nodes connected over their `ethernet-1/1` interfaces form a topology of this lab.

```console
  a_node                       z_node
 ┌──────┐ a_int          z_int┌──────┐
 │      ├─────┐         ┌─────┤      │
 │ srl1 │e1-1 ├─────────┤e1-1 │ srl2 │
 │      ├─────┘         └─────┤      │
 └──────┘                     └──────┘
```

Both nodes are configured to emulate IXR-6e chassis-based hardware and run SR Linux v22.6.3.

## Deployment

To deploy this topology, users should complete the following pre-requisite steps:

1. [Install KNE](../installation.md)
2. [Install SR Linux controller](../installation.md#sr-linux-controller)
3. [Install SR Linux license](../installation.md#license)[^2]

Once prerequisites are satisfied, topology deployment is just a single command:

```shell
kne create examples/nokia/srlinux-services/2node-srl-ixr6-with-oc-services.pbtxt
```

When the topology creation succeeds, the final log message `Topology "2-srl-ixr6" created` is displayed.

A Kubernetes namespace is created matching the [lab name](../topology.md#topology-name) `2-srl-ixr6`, and lab components are placed in that namespace. To verify lab deployment status, a user can invoke the following command and ensure that the pods are in running state.

```shell
❯ kubectl get pods -n 2-srl-ixr6 
NAME   READY   STATUS    RESTARTS   AGE
srl1   1/1     Running   0          15h
srl2   1/1     Running   0          15h
```

The above command confirms that the two nodes specified in the topology files are in running state.

## Configuration

Topology file utilizes [startup configuration](../topology.md#file) provided in a separate file. This startup configuration contains configuration for essential management and Openconfig services.

As a result of this startup config, the nodes come up online with these services in an already operational state.

???tip "How to configure Openconfig services via CLI"
    In order to configure the below mentioned Openconfig services users can spin up a single-node SR Linux topology with containerlab and enter the follwoing commands in the CLI:

    ```srl
    enter candidate
    /system tls
    replace "server-profile clab-profile" with "server-profile kne-profile"

    set / system gnmi-server network-instance mgmt tls-profile kne-profile
    set / system json-rpc-server network-instance mgmt https tls-profile kne-profile

    set / system management openconfig admin-state enable
    set / system gnmi-server network-instance mgmt yang-models openconfig

    set / system gribi-server admin-state enable network-instance mgmt admin-state enable tls-profile kne-profile
    set / network-instance mgmt protocols gribi admin-state enable

    set / system p4rt-server admin-state enable network-instance mgmt admin-state enable tls-profile kne-profile
    ```

### TLS certificate

A generated TLS profile is present in the configuration and can be found by `/system tls server-profile kne-profile` path. This server profile named `kne-profile` contains a TLS certificate and a key. This server profile is used by a number of SR Linux management services that require TLS-enabled security.

Note, that the certificate present in a lab is shared between both nodes and contains invalid CN and SAN values. Therefore, it won't be possible to verify the certificate offered by the lab nodes, and tools should skip certificate verification.

## Services

Essential management and Openconfig services are provided in the startup configuration file utilized by this lab. In the following sections, we explain how to verify the operational status of those services.

Services enabled on SR Linux nodes running in this lab are made available externally by the MetalLB Load Balancer and the corresponding [services configuration blob](../topology.md#services) in the topology file.  

!!!tip
    To list ports that available externally use:

    ```shell
    ❯ kubectl get svc -n 2-srl-ixr6 
    NAME           TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                        AGE
    service-srl1   LoadBalancer   10.96.72.99     172.18.0.50   22:30281/TCP,57400:30333/TCP   15h
    service-srl2   LoadBalancer   10.96.135.142   172.18.0.51   57400:31443/TCP,22:30266/TCP   15h
    ```
    Access to the services is done via `External-IP` and the corresponding port number. For example, SSH service on `srl1` node is available by the `172.18.0.50:22` socket.

### SSH

An SSH service is enabled on both SR Linux nodes and is exposed via port `22`. Users can access SSH using the `External-IP` for a matching service and port `22`.

??? "Example"
    Credentials: `admin:NokiaSrl1!`
    ```
    ❯ ssh admin@172.18.0.50
    Warning: Permanently added '172.18.0.50' (ECDSA) to the list of known hosts.
    ................................................................
    :                  Welcome to Nokia SR Linux!                  :
    :              Open Network OS for the NetOps era.             :
    :                                                              :
    :    This is a freely distributed official container image.    :
    :                      Use it - Share it                       :
    :                                                              :
    : Get started: https://learn.srlinux.dev                       :
    : Container:   https://go.srlinux.dev/container-image          :
    : Docs:        https://doc.srlinux.dev/22-6                    :
    : Rel. notes:  https://doc.srlinux.dev/rn22-6-1                :
    : YANG:        https://yang.srlinux.dev/v22.6.1                :
    : Discord:     https://go.srlinux.dev/discord                  :
    : Contact:     https://go.srlinux.dev/contact-sales            :
    ................................................................

    admin@172.18.0.50's password:
    ```

### Console

To get console-like access to SR Linux NOS users should leverage `kubectl exec` command and start the `sr_cli` process:

```shell
kubectl -n 2-srl-ixr6 exec -it srl1 -- sr_cli # (1)!
```

1. * Namespace `2-srl-ixr6` matches the lab name set in the topology file  
    * `srl1` container name matches the node name set in the topology file.

??? "Example"
    ```
    ❯ kubectl -n 2-srl-ixr6 exec -it srl1 -- sr_cli
    Defaulted container "srl1" out of: srl1, init-srl1 (init)
    Using configuration file(s): ['/etc/opt/srlinux/srlinux.rc']
    Welcome to the srlinux CLI.
    Type 'help' (and press <ENTER>) if you need any help using this.
    --{ running }--[  ]--
    A:srl1#
    ```

### Openconfig

<small>[:octicons-book-16: Openconfig docs][oc-doc]</small>

By default, Nokia SR Linux uses native [YANG models](../../../../yang/index.md). Openconfig YANG models are already enabled in the configuration file used in this lab.

For completeness, the below section shows how to enable Openconfig via different management interfaces.

=== "CLI"
    ```
    --{ running }--[  ]--
    A:srl# enter candidate

    --{ candidate shared default }--[  ]--
    A:srl# system management openconfig admin-state enable
    
    --{ * candidate shared default }--[  ]--
    A:srl# commit stay 
    All changes have been committed. Starting new transaction.
    ```
=== "Config file"
    ```json
    "srl_nokia-system:system": {
      "management": {
        "srl_nokia-openconfig:openconfig": {
          "admin-state": "enable"
        }
      },
    // other system containers
    }
    ```

### gNMI

<small>[:octicons-book-16: gNMI docs][gnmi-doc]</small>

gNMI service is enabled over port `57400` in the configuration file used with this lab and exposed by the cluster's LoadBalancer over `9339` port for external connectivity.

By default, gNMI instance configured in the `mgmt` network instance uses native [YANG models](../../../../yang/index.md). This is driven by the default configuration value of the `/system/gnmi-server/network-instance[name=mgmt]/yang-models` leaf and selects which models are going to be used when gNMI paths are provided without the [`origin`](https://github.com/openconfig/reference/blob/c243b35b36e366852f9476c87fb2efe6e9050dfe/rpc/gnmi/gnmi-specification.md#222-paths) information in the path.

Startup configuration file used in this lab has the `yang-models` leaf set to `openconfig`. This makes the paths without the `origin` value to be treated as openconfig paths.

??? "Example"
    gNMI service can be tested using [gnmic](https://gnmic.openconfig.net) cli client.
    === "Capabilities"
        ```bash
        ❯ gnmic -a 172.18.0.50:9339 -u admin -p NokiaSrl1! --skip-verify capabilities
        gNMI version: 0.7.0
        supported models:
          - urn:srl_nokia/aaa:srl_nokia-aaa, Nokia, 2022-06-30
          - urn:srl_nokia/aaa-password:srl_nokia-aaa-password, Nokia, 2022-06-30
          - urn:srl_nokia/aaa-types:srl_nokia-aaa-types, Nokia, 2021-11-30
          - urn:srl_nokia/acl:srl_nokia-acl, Nokia, 2022-06-30
        -- snip --
        ```
    === "Get using native YANG models"
        Since the default schema is set ot Openconfig in the startup configuration file, to perform gNMI requests using the native SR Linux models users have to specify the `native` origin. At the time of this wrigin, origin can be provided via Path Prefixes, and soon will be available for paths as well.
        ```bash
        ❯ gnmic -a 172.18.0.50:9339 -u admin -p NokiaSrl1! --skip-verify -e JSON_IETF \
          get --prefix 'native:' --path '/system/information/version'
        [
          {
            "source": "172.18.0.50:9339",
            "timestamp": 1678615621140266475,
            "time": "2023-03-12T11:07:01.140266475+01:00",
            "updates": [
              {
                "Path": "srl_nokia-system:system/srl_nokia-system-info:information/version",
                "values": {
                  "srl_nokia-system:system/srl_nokia-system-info:information/version": "v22.11.2-116-gf3be2e95f2"
                }
              }
            ]
          }
        ]
        ```
    === "Get using Openconfig YANG models"
        With the configuration leaf `/system/gnmi-server/network-instance[name=mgmt]/yang-models` set to `openconfig`, paths without the `origin` information are assumed to belong to the Openconfig YANG.
        ```bash
        ❯ gnmic -a 172.18.0.50:9339 -u admin -p NokiaSrl1! --skip-verify -e JSON_IETF \
          get --path "/system/state/hostname"
        [
          {
            "source": "172.18.0.50:9339",
            "timestamp": 1678615843724905250,
            "time": "2023-03-12T11:10:43.72490525+01:00",
            "updates": [
              {
                "Path": "openconfig-system:system/state/hostname",
                "values": {
                  "openconfig-system:system/state/hostname": "srl1"
                }
              }
            ]
          }
        ]
        ```

### gNOI

<small>[:octicons-book-16: gNOI docs][gnoi-doc]</small>

On SR Linux, gNOI service is enabled automatically once gNMI service is operational and share the same port `57400`. Although the same external post could have been used, to integrate with Ondatra test framework, a different service definition named `gnoi` with a separate `outside` port has been created.

??? "Example"
    gNOI service can be tested using [gnoic](https://gnoic.kmrd.dev) cli client.

    ```bash
    ❯ gnoic -a 172.18.0.50:9337 --skip-verify -u admin -p NokiaSrl1! file stat --path /etc/os-release
    +-------------------+-----------------+---------------------------+------------+------------+------+
    |    Target Name    |      Path       |       LastModified        |    Perm    |   Umask    | Size |
    +-------------------+-----------------+---------------------------+------------+------------+------+
    | 172.18.0.50:57400 | /etc/os-release | 2021-09-14T06:32:07+02:00 | -rwxrwxrwx | -----w--w- | 21   |
    +-------------------+-----------------+---------------------------+------------+------------+------+
    ```

### gRIBI

<small>[:octicons-book-16: gRIBI docs][gribi-doc]</small>

gRIBI server is enabled on a system level and in the `mgmt` network instance of SR Linux running on port `57401`. It is exposed to `9340` port for external connectivity as specified by the services configuration in the topology file.

??? "Example"
    gRIBI service can be tested using [gribic](https://gribic.kmrd.dev) cli client.

    ```bash
    ❯ gribic -a 172.18.0.50:9340 -u admin -p NokiaSrl1! --skip-verify get --ns mgmt
    INFO[0000] target 172.18.0.50:9340: final get response:  
    INFO[0000] got 1 results
    INFO[0000] "172.18.0.50:9340":
    ```

### P4 Runtime (P4RT)

<small>[:octicons-book-16: P4RT docs][p4rt-doc]</small>

The P4 Runtime server is configured on a system level and in the `mgmt` network instance of SR Linux running on port `9559`. The same port is used externally in this lab.

Lab users still need to [configure interface or device identifiers](https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/P4RT_Guide/sr_linux_p4rt_configuration.html#identifying_an_interface_to_the_p4rt_controller) as per the documentation.

[^1]: the following versions have been used to create this tutorial. The newer versions might work; please pin the version to the mentioned ones if they don't.
[^2]: License is required to run chassis-based SR Linux systems (models: `ixr6e/ixr10e`). License-free IXR-D/H systems do not yet have support for Openconfig service; hence they are not suitable for the goals of this lab.

[gnmi-doc]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/SysMgmt_Guide/gnmi-interface.html
[gnoi-doc]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/SysMgmt_Guide/gnoi_interface.html
[gribi-doc]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/gRIBI_Guide/gribi-config.html
[kind-install]: https://kind.sigs.k8s.io/docs/user/quick-start#installation
[knedoc]: https://github.com/openconfig/kne/#readme
[kne-install]: https://github.com/openconfig/kne/blob/main/docs/setup.md
[lab]: https://github.com/openconfig/kne/blob/v0.1.9/examples/nokia/srlinux-services/2node-srl-ixr6-with-oc-services.pbtxt
[oc-doc]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/SysMgmt_Guide/data-models.html#openconfig-ov
[p4rt-doc]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/P4RT_Guide/p4rt-overview.html
[rd-linkedin]: https://linkedin.com/in/rdodin
[rd-twitter]: https://twitter.com/ntdvps
[srlinux-container]: https://github.com/nokia/srlinux-container-image
[srl-controller]: https://github.com/srl-labs/srl-controller
