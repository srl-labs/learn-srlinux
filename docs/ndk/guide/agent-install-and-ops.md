# Installing the agent

The onboarding of an NDK agent onto the SR Linux system is simply a task of copying [the agent and its files](agent.md) over to the SR Linux filesystem and placing them in the relevant directories.

This table summarizes an agent's components and the recommended locations to use.

| Component       | Filesystem location                      |
| --------------- | ---------------------------------------- |
| Executable file | `/usr/local/bin/`                        |
| YANG modules    | `/opt/$agentName/yang`                   |
| Config file     | `/etc/opt/srlinux/appmgr/$agentName.yml` |
| Other files     | `/opt/$agentName/`                       |

The agent installation procedure can be carried out in different ways:

1. manual copy of files via `scp` or similar tools
2. automated files delivery via configuration management tools (Ansible, etc.)
3. creating an `deb` package for the agent and its files and installing the package on SR Linux

The first two options are easy to execute, but they are a bit more involved as the installers need to maintain the remote paths for the copy commands. When using the `deb` option, though, it becomes less cumbersome to install the package. All the installers deal with is a single `.deb` file and a copy command.  
Of course, the build process of the `deb` package is still required, and we would like to explain this process in detail.

## Packaging the NDK application

/// admonition | Deb or RPM?
Prior to 24.3 release SR Linux used an rpm-based base Linux image, therefore the RPM package was used to distribute the NDK applications.

Starting from the release 24.3.1 SR Linux switched to Debian as its base distribution, so the `deb` package is used to distribute the NDK applications from that moment on.
///

One of the easiest ways to create an rpm, deb, or apk package is to use the [nFPM][nFPM] tool - a simple, 0-dependencies packager.

The only thing that nFPM requires of a user is to create a configuration file with the general instructions on how to build a package, and the rest will be taken care of.

### nFPM installation

nFPM offers many [installation options](https://nfpm.goreleaser.com/install/) for all kinds of operating systems and environments. In the course of this guide, we will use the universal [nFPM docker image](https://nfpm.goreleaser.com/install/#running-with-docker).

### nFPM configuration file

nFPM configuration file is the way of letting nFPM know how to build a package for the software artifacts that users created.

The complete list of options the `nfpm.yml` file can have is documented on the [project's site](https://nfpm.goreleaser.com/configuration/). Here we will have a look at the configuration file that is suitable for a typical NDK application written in Go.

The file named `ndkDemo.yml` with the following contents will instruct nFPM how to build a package:

```yaml
name: "ndkDemo"       # name of the go package
arch: "amd64"         # architecture you are using 
version: "v1.0.0"     # version of this package
maintainer: "John Doe <john@doe.com>"
description: Sample NDK agent # description of a package
vendor: "JD Corp"     # optional information about the creator of the package
license: "BSD 2"
contents:                              # contents to add to the package
  - src: ./ndkDemo                     # local path of agent binary
    dst: /usr/local/bin/ndkDemo        # destination path of agent binary

  - src: ./yang                        # local path of agent's YANG directory
    dst: /opt/ndkDemo/yang             # destination path of agent YANG

  - src: ./ndkDemo.yml                 # local path of agent yml
    dst: /etc/opt/srlinux/appmgr/      # destination path of agent yml
```

### Running nFPM

When nFPM configuration and NDK agent files are present, proceed with building an `deb` package.

Consider the following file layout:

```bash
.
├── ndkDemo          # agent binary file
├── ndkDemo.yml      # agent config file
├── nfpm.yml         # nFPM config file
└── yang             # directory with agent YANG modules
    └── ndkDemo.yang

1 directory, 4 files
```

With these files present we can build a Deb package using the containerized nFPM image like that:

```bash
docker run --rm -v $PWD:/tmp -w /tmp ghcr.io/goreleaser/nfpm:v2.40.0 package \
    --config /tmp/nfpm.yml \
    --target /tmp \
    --packager deb
```

This command will create `ndkDemo-1.0.0.x86_64.deb` file in the current directory that can be copied over to the SR Linux system for installation.

### Installing Deb package

Delivering the available deb package to a fleet of SR Linux boxes can be done with any configuration management tools. For demo purposes, we will utilize the `scp` utility:

```bash
# this example copies the deb via scp command to /tmp dir
scp ndkDemo-1.0.0.x86_64.deb admin@<srlinux-mgmt-address>:/tmp
```

Once the package has been delivered to the SR Linux system, it is ready to be installed. First, we login to SR Linux CLI and drill down to the Linux shell:

```
ssh admin@<srlinux-address>

Welcome to the srlinux CLI.
Type 'help' (and press <ENTER>) if you need any help using this.
--{ running }--[  ]--
A:srl# bash
```

Once in the bash shell, install the package with `dpkg`:

```bash
sudo dpkg -i /tmp/ndkDemo-1.0.0.x86_64.deb
```

During the package installation, the agent related files are copied over to the relevant paths as stated in the nFPM config file:

1. check the executable location

    ```bash
    [admin@srl ~]$ ls -la /usr/local/bin/ | grep ndkDemo
    -rw-r--r-- 1 root root    12312 Nov  4 11:28 ndkDemo
    ```

2. check YANG modules dir is present

    ```
    [admin@srl ~]$ ls -la /opt/ndkDemo/yang/
    total 8
    drwxr-xr-x 2 root root 4096 Nov  4 12:58 .
    drwxr-xr-x 3 root root 4096 Nov  4 12:53 ..
    -rw-r--r-- 1 root root    0 Nov  4 11:28 ndkDemo.yang
    ```

3. check ndkDemo config file is present

    ```bash
    [admin@srl ~]$ ls -la /etc/opt/srlinux/appmgr/
    total 16
    drwxr-xr-x+  2 root    root    4096 Nov  4 12:58 .
    drwxrwxrwx+ 10 srlinux srlinux 4096 Nov  4 12:53 ..
    -rw-r--r--+  1 root    root       0 Nov  4 11:28 ndkDemo.yml
    ```

All the agent components are available by the paths specified in the nFPM configuration file.

Congratulations, the agent has been installed successfully. Now, we need to nudge the App Manager to load the agent.

## Loading the agent

SR Linux's Application Manager is in charge of managing the applications lifecycle. App Manager controls both the native apps and customer-written agents.

After a user installs the agent on the SR Linux system by copying the relevant files, they need to reload the `app_mgr` process to detect new applications. App Manager gets to know about the available apps by reading the [app configuration files](agent.md#application-manager-and-application-configuration-file) located at the following paths:

| Directory                  | Description                    |
| -------------------------- | ------------------------------ |
| `/opt/srlinux/appmgr/`     | SR Linux embedded applications |
| `/etc/opt/srlinux/appmgr/` | User-provided applications     |

To reload the App Manager:

```
/ tools system app-management application app_mgr reload
```

Once reloaded, App Manager will detect the new applications and load them according to their configuration. The users will be able to see their app in the list of applications:

```
/show system application <app-name>
```

## Managing the agent's lifecycle

An application's lifecycle can be managed via any management interface by using the following knobs from the `tools` schema.

```
/ tools system app-management application <app-name> <start|stop|reload|restart>
```

The commands that can be given to an application are translated to system signals as per the following table:

| Command  | Description                                                                                                                                |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `start`  | Executes the application                                                                                                                   |
| `reload` | Send `SIGHUP` signal to the app. This signal can be handled by the app and reload its config and change initialization values if necessary |
| `stop`   | Send `SIGTERM` signal to the app. The app should handle this signal and exit gracefully                                                    |
| `quit`   | Send `SIGQUIT` signal to the app. Default behavior is to terminate the process and dump core info                                          |
| `kill`   | Send `SIGKILL` signal to the app. Kills the process without any cleanup                                                                    |

[nFPM]: https://nfpm.goreleaser.com/
