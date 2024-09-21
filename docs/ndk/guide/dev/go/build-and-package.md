# Building and packaging the application

The local [`run.sh`][run-sh] script that we ship with the demo [`greeter` app][greeter-go-repo] has convenience functions to build, compress and package the application. For example, to build a development package one can simply run:

```bash
./run.sh package
```

This function will build, compress and package the application in a deb package in your `./build` directory. You can then copy this file over to an SR Linux container or hardware system and try it out.

/// admonition | Packaging with nFPM
The packaging step is explained in detail in [Packaging the NDK app section](../../agent-install-and-ops.md#packaging-the-ndk-application).
///

While using the `run.sh` script is fine for a quick local development, you would rather have a build pipeline that can use something like [Goreleaser][goreleaser] and build, package and push the application in a single step.

The greeter app repo uses [Goreleaser][goreleaser] to build, package and push the application to a free package repository. Checkout the GitHub actions workflow defined in the [`cicd.yml`][cicd-wf] file for more details as well as the [`goreleaser.yml`][goreleaser-yml] file for the Goreleaser configuration.

## Postinstall script

Packaging the application in a deb package has a benefit of having a built-in mechanism to run a post-installation script. As an app developer you can craft a script that can prepare the grounds for your application to run successfully.

It can be as complex as your application requirements dictate, or as simple as just reloading the app manager once the app is installed. The latter is the case with the greeter app.

Recall, that whenever we install a new application on SR Linux system, we need to reload the application manager. App manager is like an manager of all the applications installed on the system. It parses the configuration of each app and manages the lifecycle of each app.

Thus, with every new app onboarded on the system we require to reload the application manager in order for the new app to be recognized by the system. But it is not fun to always manually type `tools system app-management application app_mgr reload` whenever you install a new app...

That's where the post-install script comes in. Consider the following [`postinstall.sh`][postinstall-sh] script that we ship with the greeter app:

```bash
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/postinstall.sh"
```

It does only one thing - reload the application manager - but does it just in time when the app is installed.

To make the postinstall script part of your deb package, you add the postinstall script path in your nfpm section of the [`goreleaser.yml`][goreleaser-yml] file. The rest is done by the Apt package manager. Cool!

## Try greeter

Once the application package is published in our package repository, containerlab users can install it on their SR Linux system:

```srl
--{ running }--[  ]--
A:srl# bash sudo apt update && sudo apt install -y ndk-greeter-go
```

Once the package is installed, reload your app manager and try configuring the greeter app:

```srl
--{ running }--[  ]--
A:srl# /tools system app-management application app_mgr reload
```

[goreleaser]: https://goreleaser.com/
[run-sh]: https://github.com/srl-labs/ndk-greeter-go/blob/main/run.sh
[goreleaser-yml]: https://github.com/srl-labs/ndk-greeter-go/blob/main/goreleaser.yml
[cicd-wf]: https://github.com/srl-labs/ndk-greeter-go/blob/main/.github/workflows/cicd.yml
[greeter-go-repo]: https://github.com/srl-labs/ndk-greeter-go
[postinstall-sh]: https://github.com/srl-labs/ndk-greeter-go/blob/main/postinstall.sh
