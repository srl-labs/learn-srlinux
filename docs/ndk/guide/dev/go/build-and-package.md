# Building and packaging the application

The local [`run.sh`][run-sh] script has convenience functions to build, compress and package the application. For example, to build a development package one can simply run:

```bash
./run.sh package
```

This function will build, compress and package the application in a deb package in your `./build` directory. You can then copy this file over to an SR Linux container or hardware system and try it out.

/// admonition | Packaging with nFPM
The packaging step is explained in detail in [Packaging the NDK app section](../../agent-install-and-ops.md#packaging-the-ndk-application).
///

While using the `run.sh` script is fine for a quick local development, you would rather have a build pipeline that can use something like [Goreleaser][goreleaser] and build, package and push the application in a single step.

The greeter app repo uses [Goreleaser][goreleaser] to build, package and push the application to a free package repository. Checkout the GitHub actions workflow defined in the [`cicd.yml`][cicd-wf] file for more details as well as the [`goreleaser.yml`][goreleaser-yml] file for the Goreleaser configuration.

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
[run-sh]: https://github.com/srl-labs/ndk-greeter-go/blob/use-bond-agent/run.sh
[goreleaser-yml]: https://github.com/srl-labs/ndk-greeter-go/blob/use-bond-agent/goreleaser.yml
[cicd-wf]: https://github.com/srl-labs/ndk-greeter-go/blob/use-bond-agent/.github/workflows/cicd.yml
