---
date: 2023-05-03
tags:
  - gnmi
  - gnsi
  - gnoi
  - gribi
  - openconfig
authors:
  - rdodin
---

# gNxI Browser - A documentation UI for Openconfig gRPC services

In the past year, there has been a lot of buzz around gRPC and Openconfig services. Network engineers started to hear more *g-acronyms*: gNMI, gNOI, gRIBI. The bravest ones started to play with them, and those who like to live on the edge even started to use them in production. But the majority of network engineers are still not familiar with these technologies. The lack of tools to explore and understand these new technologies is one of the reasons for this.

You probably know that in srl-labs we strive for quality tools, and we are not afraid to build them ourselves. The famous [`gnmic`][gnmic], [`gnoic`][gnoic], [`gribic`][gribic] by Karim Radhouani are stellar examples of our effort to make gRPC and Openconfig services more accessible to network engineers.

Today we are happy to announce another initiative by our team - [**gnxi.srlinux.dev**](https://gnxi.srlinux.dev) - a documentation UI for Openconfig gRPC services. It is a simple web application that allows you to explore Openconfig gRPC services and their protobuf definitions.

We hope that it will help network engineers to get familiar with gRPC and Openconfig services and we wanted to tell you how we built it.

<!-- more -->

## Documentation problem

The problem with Openconfig gRPC services is that there is **a bunch** of them, and it is not particularly easy to find and consume their documentation. The documentation is usually in the form of protobuf files, which are not very human-readable.  
What makes things even more complicated is that there are multiple repos these services are live at and there are multiple versions of the protobuf files constituting the service.

So we decided to build a simple web application that would allow us to explore Openconfig gRPC services, their protobuf definitions and tight it all with links to available documentation articles and source files. That is how gNxI Browser was born.

![pic1](https://gitlab.com/rdodin/pics/-/wikis/uploads/67f33b3bbf24effe7f7f7a010195b5cc/image.png){: .img-shadow}

!!!tip "What is gNxI?"
    gNxI is a term that we use to refer to a set of Openconfig gRPC services.

## Interfaces and Services

As you can see from the screenshot above, the application is pretty simple. It has a list of Openconfig gNxI interfaces on the top and a list of services that constitute each interface beneath it. Currently we count 4 gNxI interfaces: gNMI, gNOI, gNSI and gRIBI. Each interface has a list of services that belong to it. For example, gNSI interface has 5 services:

![pic2](https://gitlab.com/rdodin/pics/-/wikis/uploads/f068346e2ffe1e5acdbb2538384e00db/2023-05-03_17-35-14__2_.gif){.img-shadow}

## Service documentation

The main purpose of the application is to provide a convenient way to explore Openconfig gRPC services and their protobuf definitions. By clicking on a service users are presented with a documentation UI:

![pic3](https://gitlab.com/rdodin/pics/-/wikis/uploads/6868ced80038b77b1d728213a712d200/image.png){: .img-shadow}

For each service, we provide a list of RPCs that it exposes and a list of messages that it uses.

At the central part of the screen, we provide the RPCs that constitute the service. This is the core of the service documentation. Each RPC consists of the request and response messages which are linked to the corresponding protobuf definitions. We also provide a link to the documentation article for each RPC.

The side panel contains the list of messages that are used by the service that can be filtered using the search input.

![filter](https://gitlab.com/rdodin/pics/-/wikis/uploads/05cda27edcdb684e3fe7aa3d313614a5/2023-05-03_18-13-22__1_.gif){: .img-shadow}

Every service has a link to the source code of the protobuf definitions that constitute it and, if available, a link to the documentation.

<center markdown>![pic4](https://gitlab.com/rdodin/pics/-/wikis/uploads/b3eaf69cb12234238492ffa68a7253ae/image.png){: .img-shadow width="70%" }</center>

## Version selection

As we mentioned before, there are multiple versions of the protobuf definitions for each service. We wanted to make sure that users can easily switch between versions of the service documentation. That is why we added a version selector to the top rightmost section of the screen. When you first click on service, the latest version of the service is rendered. You can switch to older versions of the same service or to another service in the same interface by clicking on the version selector.

![select](https://gitlab.com/rdodin/pics/-/wikis/uploads/e2c143d3cb3a236493ffc9da42bbfcf9/2023-05-03_18-31-48__1_.gif){: .img-shadow}

## Generating the documentation

The UI is rendered from the JSON files generated with the help of [`protoc-gen-doc`][protoc-gen-doc] open source tool that we bundled with a bunch of common proto files and published at [`protoc-container`](https://github.com/srl-labs/protoc-container).

The generation is launched by the bash runner script - [`run.sh`](https://github.com/srl-labs/gnxi-browser/blob/main/run.sh) - and the generated JSON files are stored in the [`static/intefaces`](https://github.com/srl-labs/gnxi-browser/tree/main/static/interfaces) folder.

If you see that some version is missing, you can use the scripts to generate the JSON files and submit a merge request to the [gnxi-browser](https://github.com/srl-labs/gnxi-browser) repo.

[gnmic]: https://gnmic.openconfig.net/
[gnoic]: https://gnoic.kmrd.dev/
[gribic]: https://gribic.kmrd.dev/
[protoc-gen-doc]: https://github.com/pseudomuto/protoc-gen-doc
