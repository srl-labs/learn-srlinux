---
comments: true
title: Validate Module
---

# `validate` Module

The `validate` module is used to validate intended configuration. The module doesn't make any changes to the target device and just ensures that the intended change set passes validation checks performed by SR Linux.

Module semantics is similar to the `config` module with the `update`, `replace` and `delete` parameters carrying the intended change set.

```yaml
- name: Validate
  hosts: clab
  gather_facts: false
  tasks:
    - name: Validate a valid change set
      nokia.srlinux.validate:
        update:
          - path: /system/information
            value:
              location: Some location
              contact: Some contact
      register: response

    - debug:
        var: response

    - name: Validate an invalid change set
      nokia.srlinux.validate:
        update:
          - path: /system/information
            value:
              wrong: Some location
              contact: Some contact
```
