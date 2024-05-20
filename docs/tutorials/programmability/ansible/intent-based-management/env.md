# Setting up the environment

To demonstrate the intent-based configuration management with Ansible we prepared a lab environment that you can set up on your own machine[^1]. The lab environment consists of a small SR Linux-based Clos fabric that is going to be configured by Ansible using intents declared in the Ansible roles.

## Clone the project repository

The entire project is contained in the [intent-based-ansible-lab][intent-based-ansible-lab] repository. Following command will clone the repository to the current directory on your machine (in `intent-based-ansible-lab` directory):

```bash
git clone https://github.com/srl-labs/intent-based-ansible-lab.git
cd intent-based-ansible-lab
```

The following sections assume you are in the `intent-based-ansible-lab` directory.

## Install Ansible and dependencies

- To run the playbooks in the above repo, Ansible and related dependencies must be installed. The recommended way is to create a Python virtual environment and install the packages in that environment. Next to the Python packages, the `nokia.srlinux` Ansible collection is required that provides the connection plugin to interact with SR Linux using JSON-RPC.

    ```bash title="Creating a venv and installing dependencies"
    python3 -mvenv .venv
    source .venv/bin/activate
    pip install -U pip && pip install -r requirements.txt
    ansible-galaxy collection install nokia.srlinux    
    ```

- Ensure you have the [Containerlab](https://containerlab.dev/install)[^2] installed and are meeting its installation requirements.

- We recommend you install the [fcli](https://github.com/srl-labs/nornir-srl#readme) tool that generates fabric-wide reports to verify things like configured services, interfaces, routes, etc.  
  `fcli` is not required to run the project, but it's useful to verify the state of the fabric after running the playbook and is used throughout this tutorial to illustrate the effects of the Ansible playbooks. It is packaged in a container and run via a shell alias via the following command:

    ```bash
    source .aliases.rc
    ```

## Deploying the lab

You need an SR Linux test topology to run the Ansible playbook and roles against. We will use [Containerlab](https://containerlab.dev/) to create a lab environment with 6 SR Linux nodes: 4 leaves and 2 spines:

```bash
sudo containerlab deploy -t topo.yml --reconfigure
```

This will create a lab environment with 6 SR Linux nodes and a set of Linux containers to act as hosts:

<figure markdown>
  <div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph='{"page":0,"zoom":2,"highlight":"#0000ff","nav":true,"check-visible-state":true,"resize":true,"url":"https://raw.githubusercontent.com/srl-labs/intent-based-ansible-lab/main/img/ansible-srl-topo.drawio.svg"}'></div>
  <figcaption> Fabric topology</figcaption>
</figure>

Containerlab populates the `/etc/hosts` file on the host machine with the IP addresses of the deployed nodes. This allows Ansible to connect to the nodes that has a matching inventory file inside the `inv` directory.

```bash title="Verifying that all lab nodes are up and running"
sudo containerlab inspect -t topo.yml
```

With the lab deployed, we can now explore the project's structure and understand the role's layout that powers the intent-based configuration management.

[intent-based-ansible-lab]: https://github.com/srl-labs/intent-based-ansible-lab
[^1]: As always, the lab is completely free to run, featuring our free and public SR Linux container image.
[^2]: Using the version not older than the one mentioned in the [tutorial summary](index.md) section.
<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
