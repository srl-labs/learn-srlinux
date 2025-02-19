---
hide:
  - toc
  - edit-button
title: Programmability
---

<style>
  .md-content__button {
    display: none;
  }
</style>

<div class="grid cards" markdown>

- :material-yin-yang:{ .lg .middle } **YANG**

    ---

    Nokia SR Linux was ground-up designed with YANG data models taking a central role.  
    Full YANG coverage for every component of SR Linux[^1] powers model-driven management interfaces and enables unprecedented automation capabilities.

    [:octicons-arrow-right-24: Continue](../yang/index.md)

- :octicons-stack-24:{ .lg .middle } **NetOps Development Kit (NDK)**

    ---

    The NDK enables operators to integrate their own and third-party applications into the system with all the same benefits as Nokia applications.

    [:octicons-arrow-right-24: Reference](../ndk/index.md)

- :material-puzzle-plus:{ .lg .middle } **Customizable CLI**

    ---

    An advanced, Python-based CLI provides a flexible framework for accessing the system’s underlying data models.

    Operators can leverage CLI plugins to customize the way CLI looks, feels, and reacts.

    [:octicons-arrow-right-24: Reference](../cli/plugins/index.md)

- :fontawesome-brands-golang:{ .lg .middle } **Go API**

    ---

    Up your automation workflows using Go API[^2] for SR Linux and leverage type hinting, compile-time validation and full schema conformance.

    Time to leave confguration templating at runtime in the past!

    [:octicons-arrow-right-24: Experiment](https://github.com/srl-labs/ygotsrl)

- :material-arrow-decision-outline:{ .lg .middle } **Event Handler**

    ---

    Event handler is a framework that enables SR Linux to react to specific system events, using programmable logic to define the actions taken in response to the events.

    Couple the fully-modelled configuration and state datastores with a versatile and simple Python language and you get a powerful automation execution framework running on the NOS.

    [:octicons-arrow-right-24: Checkout examples](../blog/tags.md#tag:event-handler)

- :material-ansible:{ .lg .middle } **Ansible**

    ---

    Does your networking team rely on Ansible for network automation, and you'd rather continue using it with SR Linux fabric?  
    We have you covered with Ansible collection developed for SR Linux fully modelled management interfaces.

    [:octicons-arrow-right-24: Documentation](../ansible/index.md)

- :octicons-terminal-24:{ .lg .middle } **Screen Scraping**

    ---

    Fully modeled, structured, and performant interfaces is not particularly your cup of tea? No worries, we added plugins for the two most popular screen craping libraries:

    <!-- markdownlint-disable MD007 -->

    - Scrapli ([py][scraplipy-srl], [go][scrapligo-srl])
    - [Netmiko][netmiko-srl]

    <!-- markdownlint-enable MD007 -->

    <small>:material-progress-wrench: Tutorials coming soon...</small>

- :material-emoticon-devil:{ .lg .middle } **Custom SNMP MIBs for Gets and Traps**

    ---

    We have gNMI, we have JSON-RPC, we have NETCONF, we have a CLI with JSON and YAML outputs, but if you are still using SNMP...

    We have SNMP, and it's fully programmable to define custom MIBs!

    [:octicons-arrow-right-24: SNMP Framework](../snmp/snmp_framework.md)

- :octicons-flame-24:{ .lg .middle } **NAPALM**

    ---

    Familiar with a multi-vendor network automation interface that spits fire?

    With [`napalm-srlinux`](https://github.com/napalm-automation-community/napalm-srlinux) community driver we plug in the NAPALM ecosystem using gNMI as the underlying management interface.

    <small>:material-progress-wrench: [Refactoring needed...](https://github.com/napalm-automation-community/napalm-srlinux)</small>

</div>

[scraplipy-srl]: https://github.com/scrapli/scrapli_community/tree/main/scrapli_community/nokia/srlinux
[scrapligo-srl]: https://github.com/scrapli/scrapligo/blob/main/assets/platforms/nokia_srl.yaml
[netmiko-srl]: https://github.com/ktbyers/netmiko/blob/develop/netmiko/nokia/nokia_srl.py

[^1]: Including [NDK applications](../ndk/apps/index.md) written by users.
[^2]: Generated with [openconfig/ygot](https://github.com/openconfig/ygot).
