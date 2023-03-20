---
comments: true
title: KNE Installation
---

# Installation

To start deploying labs orchestrated by KNE a user needs to install `kne` command line utility and have a k8s cluster available. Follow [KNE setup instructions](https://github.com/openconfig/kne/blob/main/docs/setup.md) to install `kne` and its dependencies.

!!!note "Versions"
    We used the following components and their versions in this tutorial:

    * [`kne v0.1.9`](https://github.com/openconfig/kne/releases/tag/v0.1.9)[^1]
    * [`kind v0.17.0`](https://github.com/kubernetes-sigs/kind/releases/tag/v0.17.0)[^2]

By following the setup instructions, you should have the following utilities successfully installed:

=== "kne"
    ```shell
    ❯ kne help
    Kubernetes Network Emulation CLI.  Works with meshnet to create
    layer 2 topology used by containers to layout networks in a k8s
    environment.

    Usage:
    kne [command]

    --snip--
    ```
=== "kind"
    ```shell
    ❯ kind version
    kind v0.17.0 go1.19.2 linux/amd64
    ```

## Cluster deployment

Once the necessary utilities are installed, proceed with the KNE cluster installation. KNE cluster consists of the following high-level components:

- **Kind cluster**: A kind-based k8s cluster to allow automated deployment.
- **Load Balancer service**: An Load Balancer service used in the KNE cluster to allow for external access to the nodes. Supported LB services: [MetalLB](https://metallb.universe.tf/).
- **CNI**: configuration of a CNI plugin used in the KNE cluster to layout L2 links between the network nodes deployed in a cluster. Supported CNI plugins: [meshnet-cni](https://github.com/networkop/meshnet-cni).
- **External controllers**: an optional list of external controllers that manage custom resources.

KNE provides a [cluster manifest file](https://github.com/openconfig/kne/blob/v0.1.9/deploy/kne/kind-bridge.yaml) (aka "deployment file") along with the command to install cluster components using `kne deploy` command[^3].

!!!warning
    Deployment file contains `controllers` section that enables automated installation of external controllers, such as [srl-controller][srl-controller-repo]. KNE pins particular versions of external controllers to guarantee compatibility between the KNE and controller layers. For example, KNE v0.1.9 deploys srl-controller v0.5.0. If a user wants to use a different version of a controller, they need to remove the controller from the `controllers` list and install it manually.

Using `kne deploy` and following the [cluster deployment instructions](https://github.com/openconfig/kne/blob/main/docs/create_topology.md#deploy-a-cluster), cluster installation boils down to a single command:

```bash
kne deploy deploy/kne/kind-bridge.yaml
```

The deployment process should finish without errors, stating that every component of a KNE cluster has been deployed successfully. At this point, it is helpful to check that the cluster and its components are healthy.

=== "kind cluster"
    Ensure that a kind cluster named `kne` is active.

    ```bash
    ❯ kind get clusters
    kne
    ```

    Check that `kubectl` is configured to work with `kne` cluster:

    ```bash
    ❯ kubectl config current-context
    kind-kne
    ```
=== "CNI"
    Ensure that `meshnet` CNI is running as a daemonset:

    ```bash
    ❯ kubectl get daemonset -n meshnet
    NAME      DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR              AGE
    meshnet   1         1         1       1            1           kubernetes.io/arch=amd64   8m55s
    ```

=== "Load Balancer"
    Ensure that MetalLB Load Balancer is running controller deployment and speaker daemonset:

    ```bash
    ❯ kubectl get pod -n metallb-system
    NAME                          READY   STATUS    RESTARTS   AGE
    controller-55d86f5f7c-bl9kx   1/1     Running   0          12m
    speaker-zsj29                 1/1     Running   0          11m
    ```

## SR Linux controller

[SR Linux controller][srl-controller-repo] manages SR Linux containers deployment on top of the KNE clusters and provides the necessary APIs for KNE to deploy SR Linux nodes as part of the network topology. It is automatically installed by the KNE CLI tool.

???hint "Installing SR Linux controller manually"
    SR Linux controller is an open-source project hosted at :material-github: [srl-labs/srl-controller][srl-controller-repo] repository and can be easily installed on a k8s cluster as per its [installation instructions](https://github.com/srl-labs/srl-controller#install), for example to test a version that was not yet releases or adopted by KNE:

    ```bash
    kubectl apply -k https://github.com/srl-labs/srl-controller/config/default
    ```

    Additional controllers can be installed by following the respective installation instructions provided in the [KNE documentation](https://github.com/openconfig/kne/blob/main/docs/create_topology.md#deploying-additional-vendor-controllers).

When `srl-controller` is installed successfully, it can be seen in its namespace as a deployment:

```bash
❯ kubectl get deployments -n srlinux-controller
NAME                                    READY   UP-TO-DATE   AVAILABLE   AGE
srlinux-controller-controller-manager   1/1     1            1           12m
```

### License

If a user intends to run a topology with chassis-based SR Linux nodes[^4], they must [install a valid license](https://github.com/srl-labs/srl-controller/blob/main/docs/using-licenses.md).

The same lab can be used with unlicensed IXR-D/H variants; to adapt the lab to unlicensed SR Linux variants users need to:

1. delete `model: "ixr6e"` string from the [KNE topology file][srl-with-oc-topo-file]
2. remove the openconfig configuration blob from the [startup-config file][srl-with-oc-startup-file]

    ```json title="remove this blob"
    "management": {
      "srl_nokia-openconfig:openconfig": {
        "admin-state": "enable"
      }
    }
    ```

## Image load

In the case of a `kind` cluster, it is advised to load container images to the kind cluster preemptively. Doing so will ensure that necessary images are present in the cluster when KNE creates network topologies.

To load [srlinux container image](https://github.com/nokia/srlinux-container-image) to the kind cluster:

```bash
kind load docker-image ghcr.io/nokia/srlinux:22.11.2 --name kne
```

[srl-controller-repo]: https://github.com/srl-labs/srl-controller
[srl-with-oc-topo-file]: https://github.com/openconfig/kne/blob/8daa2149cd6a6093a16177db23e4b399b025160d/examples/nokia/srlinux-services/2node-srl-ixr6-with-oc-services.pbtxt
[srl-with-oc-startup-file]: https://github.com/openconfig/kne/blob/8daa2149cd6a6093a16177db23e4b399b025160d/examples/nokia/srlinux-services/srl-openconfig.cfg.json

[^1]: The tutorial is based on this particular release, but newer releases might work as well.
[^2]: For this tutorial, we leverage [kind](https://kind.sigs.k8s.io/) (Kubernetes in Docker) to stand up a personal k8s installation. Using kind is not a hard requirement but merely an easy and quick way to get a personal k8s cluster.
[^3]: Users are free to install cluster components manually. `kne deploy` aims to automate the prerequisites installation using the tested configurations.
[^4]: Hardware types ixr6/10, ixr-6e/10e
