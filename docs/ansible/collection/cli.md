---
title: CLI Module
comments: true
---
# `cli` Module

The `cli` module is used to execute CLI commands on SR Linux devices. It is most often used to get the output of `show` or to execute CLI plugins that do not belong to the YANG module.

=== "Playbook"

    ```yaml
    - name: Run "show version" CLI command
      hosts: clab
      gather_facts: false
      tasks:
        - name: Run "show version" CLI command
          nokia.srlinux.cli:
            commands:
              - show version
          register: response

        - debug:
            var: response
    ```
=== "Response with default format"

    ```json
    {
      "changed": false,
      "failed": false,
      "jsonrpc_req_id": "2023-05-01 10:06:52:663255",
      "jsonrpc_version": "2.0",
      "result": [
          {
              "basic system info": {
                  "Architecture": "x86_64",
                  "Build Number": "343-gab924f2e64",
                  "Chassis Type": "7250 IXR-6",
                  "Free Memory": "27532316 kB",
                  "Hostname": "srl",
                  "Last Booted": "2023-04-26T20:14:32.259Z",
                  "Part Number": "Sim Part No.",
                  "Serial Number": "Sim Serial No.",
                  "Software Version": "v23.3.1",
                  "System HW MAC Address": "1A:2E:00:FF:00:00",
                  "Total Memory": "36087609 kB"
              }
          }
      ]
    }
    ```
=== "Response with text format"

    ```json
    {
      "response": {
          "changed": false,
          "failed": false,
          "failed_when_result": false,
          "jsonrpc_req_id": "2023-05-01 10:06:55:082540",
          "jsonrpc_version": "2.0",
          "result": [
              "--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------\nHostname             : srl\nChassis Type         : 7250 IXR-6\nPart Number          : Sim Part No.\nSerial Number        : Sim Serial No.\nSystem HW MAC Address: 1A:2E:00:FF:00:00\nSoftware Version     : v23.3.1\nBuild Number         : 343-gab924f2e64\nArchitecture         : x86_64\nLast Booted          : 2023-04-26T20:14:32.259Z\nTotal Memory         : 36087609 kB\nFree Memory          : 27532316 kB\n--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------\n"
          ]
      }
    }
    ```

It is possible to use this module to configure the system by sending over CLI commands that will enter into the candidate mode, make changes and then commit them. However, this is not recommended as it is not idempotent.

## Parameters

### commands

List of commands to execute.

### output_format

<small>choice: `json`, `text`, `table`</small>

Format of the output. Default is `json`.

SR Linux CLI subsystem supports three output formats: `json`, `text` and `table`.

The `json` format is the default format and is used when `output_format` is not specified.

The `text` format will return the output of the command as a string exactly as it would be displayed on the CLI.

The `table` format will return the output of the command as a string but will apply a table formatting to it. This format is useful when users want to have a table view of `info show` commands.

## Return Values

Common Ansible return values such as `changed`, `failed` and common SR Linux values such as `jsonrpc_req_id` and `jsonrpc_version` are documented in the [Get](get.md) module.

### result

List of responses for each command using the specified output format.
