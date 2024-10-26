# Python Development Environment

/// admonition | Work in progress
    type: warning
This tutorial might be outdated. Please check Go tutorial for the latest updates until this version is updated.
///

Although every developer's environment is different and is subject to a personal preference, we will provide some recommendations for a [Python](https://www.python.org/) toolchain setup suitable for the development of NDK applications.

## Environment components

The toolchain that can be used to develop Python-based NDK apps consists of the following components:

1. [Python programming language](https://www.python.org/downloads/) - Python interpreter, toolchain, and standard library. Python2 is not supported.
2. [Python NDK bindings](https://github.com/nokia/srlinux-ndk-py) - generated data access classes for gRPC based NDK service.

## Project structure

Here is an example project structure that you can use for the NDK agent development:

```
.                            # Root of a project
├── app                      # Contains agent core logic
├── yang                     # A directory with agent YANG modules
├── agent.yml                # Agent yml config file
├── main.py                  # Package main that calls agent logic
├── requirements.txt         # Python packages required by the app logic
```

## NDK language bindings

As explained in the [NDK Architecture](../../architecture.md) section, NDK is a gRPC based service. The [language bindings](https://grpc.io/docs/languages/python/quickstart/) have to be generated from the source proto files to use gRPC services in a Python program.

Nokia provides both the [proto files](https://github.com/nokia/srlinux-ndk-protobufs) for the SR Linux NDK service and also [NDK Python language bindings](https://github.com/nokia/srlinux-ndk-py).

With the provided Python bindings, the NDK can be installed with `pip`

```bash
# it is a good practice to use virtual env
sudo python3 -m venv /opt/myApp/venv

# activate the newly created venv
source /opt/myApp/venv/bin/activate

# update pip/setuptools in the venv
pip3 install -U pip setuptools

# install the latest pip package of the NDK
pip install srlinux-ndk # (1)
```

1. To install a specific version of the NDK check the [NDK install instructions](https://github.com/nokia/srlinux-ndk-py#installation) on the [NDK github repo](https://github.com/nokia/srlinux-ndk-py).

Once installed, NDK services are imported in a Python project like that:

```python
from ndk import appid_service_pb2 # (1)
```

1. The example is provided for `appid_service_pb2` service but every service is imported the same way.
