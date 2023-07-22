# Ansible

Ansible is one of the leading configuration management frameworks both in the application and networking realms. It provides a quick route to network automation by offering a simple[^1] domain-specific language (DSL) and a rich collection of modules written for different platforms and services.

Nokia provides Ansible users with the [`nokia.srlinux`](collection/index.md) Ansible collection that stores plugins and modules designed to perform automation tasks against Nokia SR Linux Network OS. The modules in `nokia.srlinux` collection are designed in a generic way with universal modules enabling configuration operations.

In contrast to the supported `nokia.srlinux` collection, a community collection `srllabs.srlinux` is in the works where the community members work on the network resource modules for SR Linux.

## See also

We strive to create hands-on material demonstrating the use of `nokia.srlinux` collection in various scenarios. The following tutorials, blog posts, and examples may be exactly what you're looking for:

* [Using `nokia.srlinux` Ansible collection](../tutorials/programmability/ansible/using-nokia-srlinux-collection.md) tutorial.

[^1]: Simplicity of a DSL often goes hand with constraints that a DSL has to impose when compared with a generic programming language. This may lead to complications when advanced data processing or branching control is required. For that reason it is common to hear sentiments that Ansible is easy to start with but may become a problem over time when automation tasks become more complex.
