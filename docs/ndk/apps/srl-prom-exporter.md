# SR Linux Prometheus Exporter

|                          |                                                                                                                                                                                                                                                                              |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Description**          | SR Linux Prometheus Exporter agent creates prometheus scrape-able endpoints on individual switches. This telemetry horizontally scaled telemetry collection model comes with additional operational enhancements over traditional setups with a central telemetry collector. |
| **Components**           | [Nokia SR Linux][srl], Prometheus                                                                                                                                                                                                                                            |
| **Programming Language** | Go                                                                                                                                                                                                                                                                           |
| **Source Code**          | [`karimra/srl-prometheus-exporter`][src]                                                                                                                                                                                                                                     |
| **Authors**              | Karim Radhouani [:material-linkedin:][auth1_linkedin] [:material-twitter:][auth1_twitter]                                                                                                                                                                                    |

## Introduction

Most Streaming Telemetry stacks are built with a telemetry collector[^1] playing a key part in getting data out of the network elements via gNMI subscriptions. While this deployment model is valid and common it is not the only model that can be used.

With SR Linux Prometheus Exporter agent we offer SR Linux users another way to consume Streaming Telemetry in a scaled out fashion.

<figure markdown>
  [![pic1](https://gitlab.com/rdodin/pics/-/wikis/uploads/0c99e48fbd6a9b06b714e1ae3f1ed765/CleanShot_2021-11-10_at_14.03.32_2x.png)](https://gitlab.com/rdodin/pics/-/wikis/uploads/0c99e48fbd6a9b06b714e1ae3f1ed765/CleanShot_2021-11-10_at_14.03.32_2x.png)
  <figcaption>Classic and agent-enabled telemetry stacks</figcaption>
</figure>

With Prometheus Exporter agent deployed on SR Linux switches the telemetry deployment model changes from a "single collector - many targets" to a "many collectors - single target" mode. The collection role is now distributed across the network with Prometheus TSDB scraping metrics endpoints exposed by the agents.

Adopting this model has some interesting benefits beyond load sharing the collection task across the network fleet:

1. "Removing" gNMI complexity  
    As gNMI based collection now happens "inside" the switch, the monitoring teams do not need to be exposed to gNMI subscription internals or to worry about managing collectors. This streamlines the telemetry scraping workflows, as now the switches practically behave the same way as any other system that provides telemetry metrics.  
        <figure markdown>
        ![pic2](https://gitlab.com/rdodin/pics/-/wikis/uploads/94850ba1dd62350266d2f0c204736832/CleanShot_2021-11-10_at_14.20.53_2x.png)
        </figure>  
2. Easy way to add/remove subscription
    Since SR Linux NDK agents provide seamless integration with all the management interfaces, the subscription handling can be done via CLI/gNMI/JSON-RPC. Users will add them the same way they do any configuration on their switches.  
    Most common subscriptions come pre-baked into the agent, removing the need to do anything for getting basic statistics out of the switches.  
3. Auto discovery of nodes
    Agents can register the prometheus endpoints they expose in [Consul](https://www.consul.io/), which will enable Prometheus server to auto-discover the new nodes as they come This is your self-organizing telemetry fleet.

## Agent's operations

<figure markdown>
  [![pic1](https://gitlab.com/rdodin/pics/-/wikis/uploads/5a67fd6f691cab6e94ddbeebc2dd95ed/CleanShot_2021-11-10_at_14.36.03_2x.png)](https://gitlab.com/rdodin/pics/-/wikis/uploads/5a67fd6f691cab6e94ddbeebc2dd95ed/CleanShot_2021-11-10_at_14.36.03_2x.png)
  <figcaption>Agent's core components and interactions map</figcaption>
</figure>

The high level operations model of the `srl-prometheus-exported` consists of the following steps:

1. Agent maps metric names to gNMI XPATHs.
2. A user can disable/enable metrics via any mgmt interface (CLI, gNMI, JSON-RPC)
3. On each scrape request, agent performs a gNMI subscription with mode `ONCE` for all paths mapped to metrics with state enable (one subscription per metric).
4. The agent will then transform the subscribe responses into prometheus metrics and send them back in the HTTP GET response body.

The following diagram outlines the core components of the agent.

Consult with the repository's readme on how to install and configure this agent.

[^1]: collectors such as [gnmic](https://gnmic.openconfig.net) and others.
[srl]: https://www.nokia.com/networks/products/service-router-linux-NOS/
[src]: https://github.com/karimra/srl-prometheus-exporter
[auth1_linkedin]: https://www.linkedin.com/in/karim-radhouani/
[auth1_twitter]: https://twitter.com/Karimtw_
