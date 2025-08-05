# SR Linux CLI

It seems that the technological progress touched every bit of a network OS, but CLI. We've witnessed significant development in the speeds and feeds, network management protocols, automation paradigms and yet CLI is largely the same as 20 years ago.

Maybe there is not much one could ask from a CLI? It accepts an input from a user and spits out the text output, what else does one need?  
Or maybe CLI is so dead that no one is interested to spend time thinking how to make it better?

We at SR Linux product team believe that CLI is still very much relevant and is an important human-facing interface to any Network OS. And there is definitely a lot of improvement to be found when thinking what a modern network CLI should be.

When designing the SR Linux CLI we made sure it feels fresh and powerful, leverages the recent software advancements, all with unprecedented customization capabilities and operator' UX at its heart.

## Core features

Even before touching any of the CLI programmability aspects, there are some core CLI features we made better in SR Linux.   Starting from a modern two-line prompt with a customizable toolbar with clear indication of a current context a user is in, through the powerful autocompletion engine with autosuggestions, all the way to a wide range of output modifiers to give you the ultimate flexibility in the output format.

These core features are explained in details in our [getting started guide](../get-started/cli.md) and we encourage every user to get through it.

## Plugins

Pluggable architecture is at the core of our CLI. It enables our users to customize almost every bit of the CLI behavior and that is something no other CLI can offer.

Ever found yourself in need of a CLI command that a vendor does not provide? With SR Linux CLI we allow you write your own CLI commands. And not just show commands!  
By giving you access to the same infrastructure and APIs that our stock CLI commands use, you will be able to create the CLI experience tailored for your ops teams.

As with every powerful system, there are some bits and pieces you will first need to get familiar with. Open the [CLI Plugins section](plugins/index.md) to become a professional CLI plugin developer.

## Aliases

Have you seen power Linux users swiftly typing in `gcb new-branch` or `k get po` and getting a meaningful output? These are command aliases that allow you to type less to get more. And we have them in SR Linux!

Aliases in SR Linux can be used to substitute a long command and can even be customized to take in arguments to have an ultimate CLI experience.

While we are working on an in-depth blog post about aliases, check out the [Hackathon exercise around aliases](https://github.com/nokia/SReXperts/tree/399867a5ace452c8bbc0e422b9db37e87bd95621/hackathon/activities/srlinux-b-cli-aliasing) to learn more about them, you'll love them!

## Wildcards and ranges

Let's talk about something that SR Linux CLI doesn't have -- apply groups :scared_face: Apply groups bloat the device model and makes the YANG-based code bindings bloated out of proportion.

But fear not, you won't miss apply groups, because SR Linux CLI comes with wildcards and ranges. These two will make the bulk edits a joy as they allow you to use familiar shell-like expansion and wildcards.

Checkout [Wildcards and ranges blog post](../blog/posts/2023/cli-ranges.md) for a deep dive on these concepts. Master it and you'll feel like having a CLI black belt!

## Prompt customization

SR Linux ships with a powerful two-line prompt conveying the most important information like the CLI mode, current context, username and hostname, and current date. A sane default. But what if you don't like it?

In Linux world the prompt customization is a form of art. There are hundreds of prompt engines for different prompts and power users create the custom prompt for their shells first thing they log in in a new system.

We wanted to give you the same flexibility in choosing what your prompt should look like in case you are not happy with the default one. You can customize both the prompt look and feel as well as the bottom toolbar. We plan to have a post about all the options and give you some ideas for prompt customization.
