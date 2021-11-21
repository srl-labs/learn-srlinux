# Python Development Environment
Although every developer's environment is different and is subject to a personal preference, we will provide some recommendations for a [Python](https://www.python.org/) toolchain setup suitable for the development of NDK applications.

## Environment components
The toolchain that can be used to develop Python-based NDK apps consists of the following components:

1. [Python programming language](https://www.python.org/downloads/) - Python interpreter, toolchain, and standard library
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
As explained in the [NDK Architecture](../architecture.md) section, NDK is a gRPC based service. The [language bindings](https://grpc.io/docs/languages/python/quickstart/) have to be generated from the source proto files to use gRPC services in a Python program.

Nokia not only provides the [proto files](https://github.com/nokia/srlinux-ndk-protobufs) for the SR Linux NDK service but also [NDK Python language bindings](https://github.com/nokia/srlinux-ndk-py).

With the provided Python bindings, the NDK can be installed with pip

```bash
# install the specific version (example given for v21.6.2)
pip install https://github.com/nokia/srlinux-ndk-py/archive/v21.6.2.zip
```

and imported in a Python project like that:

```python
from ndk import appid_service_pb2
```