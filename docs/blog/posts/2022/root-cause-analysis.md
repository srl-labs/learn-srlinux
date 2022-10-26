---
date: 2022-10-27
authors:
  - jbemmel
---
# Root cause analysis

The year is 2023. You wake up to a subtle 'ping' from your phone 📱, signifying there is a message from someone important. Still half asleep you reach out and grab it, glancing at the screen. It says: "The network went out - you're fired!"

Rollback to the present day, where I can confidentially share that this is exactly the kind of scenario that our engineers had in mind when they designed the new [Event Handler](https://learn.srlinux.dev/kb/event-handler/) feature for SR Linux. Because you can never have enough flexibility to add just the right amount of automation, configuring things properly and - critically - keeping track of changes to the configuration (and whichever #!$!! person made them)
<!-- more -->

![image](https://user-images.githubusercontent.com/2031627/198035448-1a2c3987-d2fb-48ff-81b8-2322498d40b9.png){: class="img-shadow"}

To make things more practical, take a look at [this Python script](https://github.com/jbemmel/opergroup-lab/blob/main/backup_config.py) which uses the Event Handler mechanism to scp a backup of the config to any destination of your choice, whenever something or someone commits a change. This is just a quick starting point of course - you may want to make it more elaborate and (for example) have the system send you a text for approval, with automatic rollback in case you don't approve within a certain amount of time (configurable). Or maybe you're thinking to add some Blockchain logic there, creating indisputable proof that things happened the way you say they did. Go for it!

My point is simple: You need a truly open system. A platform that allows you to configure and automate things the way you like to do them, unrestricted by vendor imposed limitations or poor product design choices. Because if not, one day you may find yourself waking up to that 'ping'. Root cause? You didn't pick that truly open network platform when you had the chance...

!!! note "Disclaimer"
    Events and people referenced in this story are fictional. Any resemblance to existing persons or events is completely accidental.
    And we both know this would never happen to you, right? Because you always make the right choices :man_raising_hand:
