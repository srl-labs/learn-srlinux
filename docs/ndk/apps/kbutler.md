# kButler - k8s aware agent

|                          |                                                                                                                                                                                                        |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Description**          | kButler agent ensures that for every worker node which hosts an application with an exposed service, there is a corresponding FIB entry for the service external IP with a next-hop of the worker node |
| **Components**           | [Nokia SR Linux][srl], Kubernetes, [MetalLB][metallb_doc]                                                                                                                                              |
| **Programming Language** | Go                                                                                                                                                                                                     |
| **Source Code**          | [`brwallis/srlinux-kbutler`][src]                                                                                                                                                                      |
| **Additional resources** | This agent was demonstrated at [NFD 25][nfd25_yt]                                                                                                                                                      |
| **Authors**              | Bruce Wallis [:material-linkedin:][auth1_linkedin] [:material-twitter:][auth1_twitter]                                                                                                                 |


## Introduction
In the datacenter fabrics where applications run in Kubernetes clusters it is common to see [Metallb][metallb_doc] to be used as a mean to advertise k8s services external IP addresses towards the fabric switches over BGP.
<figure markdown>
  ![pic1](https://gitlab.com/rdodin/pics/-/wikis/uploads/8492701d824b36f02089d6d7901bc5b9/CleanShot_2021-11-09_at_16.21.55_2x.png){ width="640" }
  <figcaption>kButler agent demo setup</figcaption>
</figure>

From the application owner standpoint as long as all the nodes advertise IP addresses of the application-related services things are considered to work as expected. But applications users do not get connected to the apps directly, there is always a network in-between which needs to play in unison with the applications.

How can we make sure, that the network state matches the expectations of the applications? The networking folks may have little to no visibility into the application land, thus they may not have the necessary information to say if a network state reflects the applications configuration.

Consider the diagram above, and the following state of affairs:

* application App1 is scaled to run on all three nodes of a cluster
* a service is created to make this application available from the outside of the k8s cluster
* all three nodes advertise the virtual IP of the App1 with its own nexthop via BGP

If all goes well, the Data Center leaf switch will install three routes in its forwarding and will ECMP load balance requests towards the nodes running application pods.

But what if the leaf switch has installed only two routes in its FIB? This can be a result of a fat fingering during the BGP configuration, or a less likely event of a resources congestion. In any case, the disparity between the network state and the application can arise.

The questions becomes, how can we make the network to be aware of the applications configuration and make sure that those deviations can be easily spotted by the NetOps teams?

## kButler
The kButler NDK agent is designed to demonstrate how data center switches can tap into the application land and correlated the network state with the application configuration.

At a high level, the agent does the following:

* subscribes to the K8S service API and is specifically interested in any new services being exposed or changes to existing exposed services. Objective is to gain view of which worker nodes host an application which has an associated exposed service
* subscribes to the SR Linux NDK API listening for any changes to the FIB
* ensures that for every worker node which hosts an application with an exposed service, there is a corresponding FIB entry for the service external IP with a next-hop of the worker node
* reports the operational status within SR Linux allowing quick alerts of any K8S service degradation
* provides contextualized monitoring, alerting and troubleshooting, exposing its data model through all available SR Linux management interfaces





[srl]: https://www.nokia.com/networks/products/service-router-linux-NOS/
[metallb_doc]: https://metallb.universe.tf/
[src]: https://github.com/brwallis/srlinux-kbutler
[ndk]: ../../intro
[nfd25_yt]: https://youtu.be/yyoZk9hqptk?t=2434
[auth1_linkedin]: https://www.linkedin.com/in/bruce-wallis-77755a129/
[auth1_twitter]: https://twitter.com/bwallislol