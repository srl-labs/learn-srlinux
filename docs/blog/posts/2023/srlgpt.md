---
date: 2023-10-09
tags:
  - ndk
  - ai
  - chatgpt
  - media
authors:
  - ejames
---

# SR Linux GPT

It's taken much longer than we anticipated and wanted (Big co problems...) but we're finally here, SR Linux GPT release day!

![feat](https://gitlab.com/rdodin/pics/-/wikis/uploads/248c99aa1a3c7d74b346ef048ed514ca/srlinux-gpt-sticker_v1_webp.webp){ width=20% align=left}

Given the excitement surrounding generative AI, especially after the public release of OpenAI's ChatGPT, it's no surprise that everyone has been exploring the potential value of integrating generative AI into their products and applications. We're no exception. It's an ongoing journey for us, and we're thrilled to start unveiling some of our findings!

<!-- more -->

SR Linux GPT was actually initially developed many....many months ago, it started out as a little weekend project by one of the SR Linux developers - and quite frankly the first working version only took just that, a weekend.  By Monday morning, we had an NDK application with a fully functional 'ChatGPT-like' prompt integrated directly into the SR Linux CLI. We could ask it questions about any aspect of the CLI, request configuration examples, and, to our astonishment, it could even answer questions about the system's state! Was it flawless? No. But it was right more often than not, and it was undeniably fun to interact with.

The best part? We didn't need to overhaul the entire operating system or drastically modify our CLI. There was no need for a Request For Enhancement (RFE) process. The integration of the SR Linux GPT app was achieved using the [NDK](../../../ndk/index.md) and CLI plugin frameworks, which power SR Linux's extensibility. The same frameworks we proudly offer to all SR Linux users.

## Generative AI and the Network Operating System

Does Generative AI really play a role in the Network Operating System?

Sure! For the same reason we still have a CLI in every single one of the NOSs available on the market today.  Firstly, ability to use natural language to interact with a network device is simply just another interface into the system, one in which you do not need to be a power user in that specific NOS CLI.  It does also provide some capabilities which a typical CLI doesn't, you can ask the AI assistant to look at different areas of the system and provide summaries which may require multiple standard CLI commands.  It can help come to come conclusions about problems or about a mis-configuration without needing to sift through a plethora of CLI outputs.

Will an in-line CLI AI assistant replace show commands, or info commands? No - there is no question that a power user will most certainly get to the information they need more quickly than waiting for the AI assistant to get back to them.  That said there are still cases where even as a power user I've found myself getting a little help from SR Linux GPT. Whether it be reminding myself of how something worked, or parsing logs, or summarizing large amounts of state data.  And plus, who doesn't want to learn how to configure OSPF from Yoda?

```srl
A:srl# askai can you provide a configuration example for configuring an OSPF neighbor, in the voice of Yoda
In the voice of Yoda, I shall provide the configuration example for configuring an OSPF neighbor, hmm.

Hmm, "default" the name of your network instance, it is. Enable the admin state, you must. "ospf-v2", the version should be.
"10.10.10.1", your router-id, it is. "0.0.0.0", the area-id, it is. "ethernet-1/1.10", the interface-name, it is.
"point-to-point", the interface-type, it is.

CLI flat SET commands, you can use, hmm:

set / network-instance default protocols ospf instance default admin-state enable, you must.
set / network-instance default protocols ospf instance default version ospf-v2, you should.
set / network-instance default protocols ospf instance default router-id 10.10.10.1, you must.
set / network-instance default protocols ospf instance default area 0.0.0.0 interface ethernet-1/1.10, you should.
set / network-instance default protocols ospf instance default area 0.0.0.0 interface ethernet-1/1.10 interface-type point-to-point, you must.

Hmm, clear an OSPF neighbor, you want to? Use this command, you should:

# tools network-instance default protocols ospf instance default neighbors neighbor 10.10.10.2 clear

Hmm, may the force be with you, young network administrator.
```

But as a new SR Linux user, this assistant can prove to be extremely valuable.  Take for example a question asked in our community discord channel

![question](https://gitlab.com/rdodin/pics/-/wikis/uploads/1bd44c3ca9c6ca0146725385b63bd7e4/image.png){.img-shadow}

What happens if this user has the ability to simply ask the question while working in their lab without the need to context switch away to documentation search or community assistance?

<video width="100%" controls playsinline><source src="https://gitlab.com/rdodin/pics/-/wikis/uploads/77dd0154c995c10f0f32ce8d9149e6d5/allow-multiple.mp4" type="video/mp4"></video>

Cool right?  Anyone starting out with SR Linux should definitely try out the AI assistant.

## Getting Started

Before we dive in, it's important to note that this release is a proof of concept, not a Nokia-supported product. It's an exciting project we're developing for everyone to use, but it comes with a 'use at your own risk' disclaimer. We plan to continue refining and releasing new versions over time. For instance, the concept of dynamic data (state or logs) is still in its early stages, and we have considerable work ahead to expand more of the state tree and logs.

!!!warning
    If you enable dynamic data (state and logs) in the app's config which is disabled by default, you will be sharing device configuration, state and logs in the form of embeddings with OpenAI if a question is asked where we need to include the information in the API request to help answer the question. Data shared with OpenAI is not obfuscated or anonymized in any way.

Additionally, in today's release we only support using OpenAI's LLM and you must provide your own OpenAI API key, which means you should be aware there will be costs associated with using the assistant (cost of using OpenAI's API).  As you'll probably see in the configuration tree of the askai-server we've tested with a few other LLMs and will most likely allow the use of your own hosted LLM soon - but until then use at your own risk (and cost)!

### Installing SR Linux GPT NDK Application

-{{% import 'macros.html' as macros %}}-
-{{ macros.srl_version('23.7.1') }}-
-{{ macros.clab_version('0.48.2') }}-

OK, so to demonstrate SR Linux GPT app we will use Containerlab (min version 0.47.1) and spin up a very simple single node SR Linux topology:

```bash
sudo containerlab deploy -c -t srlinux.dev/clab-srl
```

Wait ~20 seconds for the lab to deploy and SSH into the node:

```
❯ ssh srl

................................................................
:                  Welcome to Nokia SR Linux!                  :
:              Open Network OS for the NetOps era.             :
:                                                              :
:    This is a freely distributed official container image.    :
:                      Use it - Share it                       :
:                                                              :
: Get started: https://learn.srlinux.dev                       :
: Container:   https://go.srlinux.dev/container-image          :
: Docs:        https://doc.srlinux.dev/23-7                    :
: Rel. notes:  https://doc.srlinux.dev/rn23-7-2                :
: YANG:        https://yang.srlinux.dev/release/v23.7.2        :
: Discord:     https://go.srlinux.dev/discord                  :
: Contact:     https://go.srlinux.dev/contact-sales            :
................................................................

Using configuration file(s): []
Welcome to the srlinux CLI.
Type 'help' (and press <ENTER>) if you need any help using this.
--{ running }--[  ]--
A:srl#
```

Now let's install the `srlgpt` app.  
There are two different package formats that SR Linux uses:

1. `deb` packages are used in SR Linux >= 23.10
2. `rpm` packages are used in SR Linux <= 23.7

Depending on which version of SR Linux you're running you will need to run the relevant installation command:

/// tab | APT (deb)

```srl
--{ running }--[  ]--
A:srl# bash sudo apt update && sudo apt install -y srlgpt
```

In case APT index update is taking too long, use the following command to only update the custom repository:

```
bash sudo apt -o Dir::Etc::sourcelist=sources.list.d/srlinux.list -o Dir::Etc::sourceparts=- -o APT::Get::List-Cleanup=0 update && sudo apt install srlgpt
```

///
/// tab | YUM (rpm)
To speed things up in YUM/rpm system we will disable all the repos except for the one that contains the `srlgpt` package.

```srl title="paste this two-line command into your CLI"
--{ running }--[  ]--
A:srl# bash sudo yum install -y --disablerepo=* --enablerepo=srlinux srlgpt
```

///

Wait a few seconds for the app to download and install. It is that simple!

//// details | Alternative installation options
If you want to install SR Linux GPT app on a hardware device, or a virtual device that is run by a different orchestrator, you can download the SR Linux GPT application package and `scp` it to your SR Linux device.

!!!note
    SR Linux GPT uses some advanced CLI capabilities that we added in 23.7.1, therefore you need to be running 23.7.1 or later.

/// tab | Install RPM
Up until release 23.10 SR Linux used to run Centos-based Linux OS with RPM package manager.

```bash
curl -L https://gitlab.com/rdodin/pics/-/wikis/uploads/5b5a3eab3e14229d484a35dcd2f23264/srlgpt_1.0.99_linux_amd64.rpm \
-o /tmp/srlgpt.rpm && scp /tmp/srlgpt.rpm clab-srl-srl: #(1)!
```

1. In the example the SR Linux node is named `clab-srl-srl`, replace with the name/address you have.
///
/// tab | Install DEB
Starting from 23.10 version, SR Linux uses Debian-based Linux OS with DEB package manager.

```bash
curl -L https://gitlab.com/rdodin/pics/-/wikis/uploads/19637b56a042c6d6aaa51072e3fefa55/srlgpt_1.0.99_linux_amd64.deb \
-o /tmp/srlgpt.deb && scp /tmp/srlgpt.deb clab-srl-srl: #(1)!
```

2. In the example the SR Linux node is named `clab-srl-srl`, replace with the name/address you have.
///

Now install the copied package by opening a bash shell and running the relevant command for the package manager used in your SR Linux version.

```bash
docker exec -it clab-srl-srl bash
```

```bash
[admin@srl ~]$ sudo rpm -i srlgpt.rpm #(1)!
```

1. Replace with `sudo dpkg -i srlgpt.deb` if you're using DEB package manager.

Now enter SR Linux CLI and reload `app_mgr` so that it can read the new application YANG models:

```
[root@srl /]# sr_cli
Using configuration file(s): []
Welcome to the srlinux CLI.
Type 'help' (and press <ENTER>) if you need any help using this.
--{ running }--[  ]--
A:srl# tools system app-management application app_mgr reload
```

We need to get into a new CLI session to pickup on the newly installed CLI plugin and configuration tree. So close the existing session and open a new one:

```srl
❯ ssh admin@clab-srl-srl

................................................................
:                  Welcome to Nokia SR Linux!                  :
:              Open Network OS for the NetOps era.             :
:                                                              :
:    This is a freely distributed official container image.    :
:                      Use it - Share it                       :
:                                                              :
: Get started: https://learn.srlinux.dev                       :
: Container:   https://go.srlinux.dev/container-image          :
: Docs:        https://doc.srlinux.dev/23-7                    :
: Rel. notes:  https://doc.srlinux.dev/rn23-7-1                :
: YANG:        https://yang.srlinux.dev/v23.7.1                :
: Discord:     https://go.srlinux.dev/discord                  :
: Contact:     https://go.srlinux.dev/contact-sales            :
................................................................

Last login: Mon Oct  9 21:24:47 2023 from 2001:172:20:20::1
Using configuration file(s): []
Welcome to the srlinux CLI.
Type 'help' (and press <ENTER>) if you need any help using this.
--{ running }--[  ]--
A:srl#
```

/// note | Configuring DNS servers
For SR Linux GPT app to reach out to OpenAI API you need to configure DNS servers on your SR Linux device ensuring that DNS resolution works. Containerlab does that on your behalf, but if you don't use it you have to configure it manually. It might depend on your infra, but usually configuring public DNS servers works just fine:

```srl title="paste this into your CLI"
enter candidate
  system dns network-instance mgmt server-list [ 1.1.1.1 ]
commit now
```

///
////

### Configuring SR Linux GPT App

Alright we're almost there! Configure your OpenAI key, let the app know if you want to use GPT3.5 or GPT4 - and if you want to start playing around with dynamic data (state and logs).

```srl
--{ + running }--[  ]--
A:srl# enter candidate
--{ +* candidate shared default }--[  ]--
A:srl# askai-server openai-key <key>
A:srl# askai-server model-version gpt-4
A:srl# askai-server dynamic-state true
A:srl# commit stay
```

And you're off the races!  Use the askai prompt to ask your first question - when asking your very first question you will be prompted to accept the terms and conditions (Big co legal team requirement), once accepted you won't be prompted again!

```srl
--{ + candidate shared default }--[  ]--
A:srl# askai what are you?
I am SRLinux, a Network Operating System from Nokia.
```

```srl
--{ + candidate shared default }--[  ]--
A:srl# askai how many interfaces are up?
There are 4 interfaces that are up.

--{ + candidate shared default }--[  ]--
A:srl# askai what are they?
The interfaces that are up are:

1. ethernet-1/1
2. ethernet-1/2
3. mgmt0
4. system0

--{ + candidate shared default }--[  ]--
A:srl#
```

## Summary

The blog post introduces the SR Linux GPT, a generative AI integrated into the SR Linux CLI. It can be used to ask questions about the CLI, provide configuration examples, and even answer questions about the system's state. The integration of the SR Linux GPT app was done using the NDK and CLI plugin frameworks, which are also available to all SR Linux users. The post also discusses the role of generative AI in the Network Operating System and how it can be beneficial, especially for new SR Linux users. The release of SR Linux GPT is not a supported product by Nokia but a proof of concept. The post also provides a step-by-step guide on how to get started with the AI assistant, including how to load the SR Linux GPT application, configure your OpenAI key, and ask your first question.

<video width="100%" controls playsinline><source src="https://gitlab.com/rdodin/pics/-/wikis/uploads/4251cdb6d5818019295b31e9208c2183/blog.mp4" type="video/mp4"></video>

If you're up for a more immersive demo experience checkout this bootlegged demo video of the SR Linux GPT app in action ripped from the Nokia SReXperts North America 2023 event.

<center><blockquote class="twitter-tweet"><p lang="en" dir="ltr">If you remember, we have been working on an AI assistant running on SR Linux in our automation garage.</p>&mdash; Roman Dodin<a href="https://twitter.com/ntdvps/status/1704634777666502779">September 21, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script></center>

And for a deep dive into the SR Linux GPT app, check out Erwan James' appearance on Packet Pushers Video Bytes:

<div class="iframe-container">
<iframe width="853" height="480" src="https://www.youtube.com/embed/zxwdecY12-E" title="SR Linux GPT" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
</div>

and a demo of the SR Linux GPT app in action at NFD33:
<div class="iframe-container">
<iframe width="100%" src="https://www.youtube.com/embed/tUjN2VtveCw" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>
