---
date: 2022-10-27
authors:
  - jbemmel
tags:
  - event handler
  - config management
  - backup
---
# Configuration backup with Event Handler

The year is 2023. You wake up to a subtle 'ping' from your phone 📱, signifying there is a message from someone important. Still half asleep you reach out and grab it, glancing at the screen. It says: "The network went out - you're fired!"

Rollback to the present day, where I can confidentially share that this is exactly the kind of scenario that our engineers had in mind when they designed the new [Event Handler](https://learn.srlinux.dev/tutorials/programmability/event-handler/oper-group/oper-group-intro/) feature for SR Linux. Because you can never have enough flexibility to add just the right amount of automation, configuring things properly and - critically - keeping track of changes to the configuration (and whichever #!$!! person made them)
<!-- more -->

<center markdown>![image](https://user-images.githubusercontent.com/2031627/198035448-1a2c3987-d2fb-48ff-81b8-2322498d40b9.png){: class="img-shadow"}</center>
<center><small>"Backup config" event handler instance config</small></center>

To make things more practical, take a look at [this Python script](https://github.com/jbemmel/opergroup-lab/blob/main/backup_config.py) which uses [the Event Handler](https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/Event_Handler_Guide/eh-overview.html) mechanism to scp a backup of the config to any destination of your choice, whenever something or someone commits a change.

``` py title="backup_config.py" linenums="1"
import json, time

# main entry function for event handler
def event_handler_main(in_json_str):
    # parse input json string passed by event handler
    in_json = json.loads(in_json_str)
    paths = in_json["paths"]
    options = in_json["options"]
    debug = options.get("debug") == "true"

    if debug:
       print( in_json_str )

    target = options.get("target", None)
    if target:
      timestamp = None
      for p in paths:
        if p['path']=="system configuration last-change":
          timestamp = p['value']
          break
        # elif p['path'] starts with "system aaa authentication session" ...

      if not timestamp:
        t = time.gmtime() # in UTC
        timestamp = '{:04d}-{:02d}-{:02d}_{:02d}:{:02d}:{:02d}_UTC'.format(t[0], t[1], t[2], t[3], t[4], t[5])
      response = { "actions": [
        { "run-script": {
           "cmdline": f"ip netns exec srbase-mgmt /usr/bin/scp /etc/opt/srlinux/config.json {target}/config-{timestamp}.json"
          }
        }
      ] }
      return json.dumps(response)

    print( "Error: no 'target' defined" )
    return { "actions": [] }
```

The script should be fairly self-explanatory: It gets the `target` from the configuration and the timestamp of the change, and then invokes a standard Linux `scp` command (making sure it runs in the correct [network namespace](https://linuxhint.com/use-linux-network-namespace/)). Although it does not currently do anything with the username, those skilled in the art will appreciate that this could easily be added.

!!!question
    Anyone stopped here for a moment thinking "Why not use Git?". Valid question, and a reasonable enhancement to the backup function presented here.

    The reason plain `scp` has been used in this example is because `scp` is shipped with the linux subsystem of SR Linux, and `git` is not. When `git` becomes available on SR Linux, we may update this example with a `git`-friendly backup option.

The above is just a quick starting point of course - you may want to make it more elaborate and (for example) have the system send you a text for approval, with automatic rollback in case you don't approve within a certain amount of time (configurable). Or maybe you're thinking to add some Blockchain logic there, creating indisputable proof that things happened the way you say they did. Go for it![^1]

My point is simple: You need a truly open system. A platform that allows you to configure and automate things the way you like to do them, unrestricted by vendor imposed limitations or poor product design choices. Because if not, one day you may find yourself waking up to that 'ping'. Root cause? You didn't pick that truly open network platform when you had the chance...

!!! note "Disclaimer"
    Events and people referenced in this story are fictional. Any resemblance to existing persons or events is completely accidental.
    And we both know this would never happen to you, right? Because you always make the right choices :man_raising_hand:

[^1]: Micro Python backend that powers the Event Handler framework doesn't allow you to install extra packages. But you can use external APIs via standard lib HTTP client and integrate with them to build advanced pipelines. Another option is to leverage the `run-script` action and call an external binary/script that can leverage external dependencies.
