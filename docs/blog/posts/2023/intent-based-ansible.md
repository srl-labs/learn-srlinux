---
date: 2023-07-06
tags:
  - srlinux
  - ansible
authors:
  - wdesmedt
hide:
  - toc
---

# Intent-based fabric management with Ansible

<small>:material-book: [Tutorial: Intent-based management with Ansible][tutorial]</small>

Ansible is today the _lingua franca_ for many network engineers to automate the configuration of network devices. Due to its simplicity and low entry barrier, it is a popular choice for network automation that features modular and reusable automation tasks available to network teams.

Broadly speaking, there are two common approaches to network automation with Ansible:

1. Smaller, per-device configuration management using Ansible modules
2. And a more broad and generic, per-service/role (or even per-fabric) configuration management using higher-level Ansible abstractions like roles and custom modules.

The first approach is the most common and straightforward one, as it is easy to get started with and requires little to no development skills. Just take the off-the-shelf module provided by the Ansible community or a vendor and start moving configuration tasks from the CLI snippets saved in a notebook to a playbook.  
While sounding simple, this approach can become a maintenance nightmare as the number of devices and configuration tasks grows. The playbook will become a long list of tasks that are hard to maintain and reuse.

This is when the second approach comes into play. It requires a deeper understanding of Ansible concepts, but it is more scalable and maintainable in the long run. The idea is to abstract the configuration tasks into reusable Ansible roles and use variables to pass the configuration parameters to the roles. This way, the playbook becomes a list of roles that are applied to the devices in the inventory.  

When roles are designed in a way that make services provisioned on all the devices in the inventory, the playbook becomes an intent-based service provisioning tool. To provide a practical example of using Ansible to manage the configuration of an SR Linux fabric with the **intent-based approach** leveraging the official [Ansible collection for SR Linux][collection-doc-link] we created a comprehensive tutorial that covers A to Z the steps required to start managing a fabric in that way - **[:material-book: Intent-based management with Ansible][tutorial]** tutorial.

We are eager to hear your thoughts on that approach and the tutorial itself. Please drop a comment below or open an issue in the [GitHub repository][intent-based-ansible-lab] if you have any questions or remarks.

[collection-doc-link]: ../../../ansible/collection/index.md
[intent-based-ansible-lab]: https://github.com/srl-labs/intent-based-ansible-lab
[tutorial]: ../../../tutorials/programmability/ansible/intent-based-management/index.md
