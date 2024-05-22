---
comments: true
---

# Summary

In this project, we took the approach to translate intents or desired-state from the variables associated with each role. These variables contain structured data and follow a model that is interpreted by the role's template to generate input for the `config` module. Only one role, the `common/configure` role, uses the `nokia.srlinux.config` module directly and is run as a last step in the play. The other roles only generate the low-level intent, i.e. the input to the `config` module, from the higher-level intent stored in the role's variables and in the inventory.

The reasons for this approach are:

- avoid _dependencies_ between resources and _sequencing_ issues. Since SR Linux is a model-driven NOS, dependencies of resources, as described in the Yang modules are enforced by SR Linux. Pushing config snippets rather than complete configs will be more error-prone to model constraints, e.g. pushing configuration that adds sub-interfaces to a network instance that are not created beforehand, will result in a configuration error. By grouping all configuration statements together and call the config module only once, we avoid these issues. SR Linux will take care of the sequencing and apply changes in a single transaction.
- support for _resource pruning_. By building a full intent for managed resources, we know exactly the desired state the fabric should be in. Using the SR Linux node as configuration state store, we can compare the desired state with the actual configuration state of the node and prune any resources that are not part of the desired state. There is no need to flag such resources for deletion which is the typical approach with Ansible NetRes modules for other NOS's.
- support for _network audit_. The same playbook that is used to apply the desired state can be used to audit the network. By comparing the full desired state with the actual configuration state of the node, we can detect any drift and report it to the user. This is achieved by running the playbook in _dry-run_ or _check_ mode.
- keeping role-specific intent with the role itself, in the associated variables, results in separation of concerns and makes the playbook more readable and maintainable. It's like functions in a generic programming language: the role is the function and the variables are the arguments.
- device-level single transaction. The `config` module is called only once per device and results in a single transaction per device - _all or nothing_. This is important to keep the device configuration consistent. If the playbook would call the `config` module multiple times, e.g. once per role, and some of the roles would fail, this would leave the device in an inconsistent state with only partial config applied.

This is a 'low-code' approach to network automation using only Jinja templating and the Ansible domain-specific language. It does require some basic development and troubleshooting skills as playbook errors will happen and debugging will be required. For example, when adding new capabilities to roles/templates, invalid data in intent variables, when SR Linux model changes happen across software releases, etc. These events may break template rendering inside the roles. Most of the logic is embedded in the Jinja templates but runtime errors are not always easy to pinpoint as Ansible does not provide a stack trace or position of failure within the template. A general troubleshooting process is as follows:

  1. Reduce the output by limiting the playbook run to a single host that exhibits the problem (`hosts` variable in `cf_fabric.yml`)
  2. run `ansible-playbook` with the `-vvv` option to get verbose output during the playbook run
  3. insert  `debug` tasks at strategic places in the playbook to narrow down the problem. Debugging variables `my_intent`, which is local to the role, `intent`, which is built up incrementally as the playbook progresses and `replace`, `update` and `delete` in the `configure` role usually point you to the root cause of the problem. Running a playbook with the debug statements in place will show the values of these variables during a regular playbook run

_Network-wide transactions_ could be implemented with _Git_. You `git commit` your changes (intents/roles) to a Git repository after any change to intents or roles. If some issues occur during the playbook run, e.g. some nodes fail in the playbook resulting in a partial fabric-wide deployment or changes appear to be permanently service-affecting, you can revert back to a previous commit with e.g. `git revert` and run the playbook again from a known good state (intent/roles).

Transformation from high-level intent to per-device low-level configuration is a one-way street. There is no way to go back from the low-level configuration to the high-level intent. This means that it is not possible to _reconcile_ changes in the network that were not driven by intent. For this to happen, a manual step is required to update the intent with the new state of the network.

Finally, we would appreciate your feedback on this project. Please open an issue in the [GitHub repository][intent-based-ansible-lab] if you have any questions or remarks.

[intent-based-ansible-lab]: https://github.com/srl-labs/intent-based-ansible-lab
