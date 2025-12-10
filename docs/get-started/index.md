---
comments: true
---

# Get started with Nokia SR Linux

SR Linux packs a lot of unique features that the IP and data center networking teams can get excited about. Some of the features are truly new to the networking domain and make the Network OS a perfect fit for the new generation of deployments.

By adopting the modern software development practices and architectures we made SR Linux answer the requirements of the highly dynamic and programmable networks. The clean slate in front of us allowed us to build a modern software platform without carrying the legacy baggage of the previous generations.

At the same time, the new concepts and paradigms implemented in SR Linux might feel, well, _new_, to a seasoned network engineer who spent years punching commands in the industry-standard CLI. To help newcomers to get started with SR Linux we invite you on an interactive journey that walks you through the basics of SR Linux Network Operating System (NOS) in a practical way.

The journey starts with deploying a small lab environment that we will use to get familiar with various SR Linux concepts and learn the core configuration and operational tasks. If your muscle memory forced you to open a tab to search where to download the SR Linux image, you can close it right now. The lightweight SR Linux container image is free and available to everyone.

/// admonition | SR Linux release numbering convention and the version used in this guide
    type: warning
SR Linux uses the following release numbering convention:

* The major release number uses the last two digits of the year in which it is released.
    For example, the 2024 releases use the major release number 24.x.
* The minor release number uses the month number in which the feature release was initially made available.  
    For example, a feature release made available in March 2024 has the release number 24.3, where 3 indicates the third month. The minor release number remains fixed even if the minor release is delayed past the end of the intended month.
* In addition, the final number appended at the end of the release number indicates the maintenance release.  
    For example, the first iteration of a release will be appended with x.x.1 as in 24.3.1. The second iteration of a release will be appended with x.x.2 as in 24.3.2, and so on.

The last minor release of the year (e.g 24.10) - is considered the long term release and will get security and bug fixes longer than the other minor releases in the same major release.

This getting started tutorial is based on **SR Linux 24.10.X** version and will adapt to newer releases over time. If you are using a different version, you may see slight differences in the command outputs.  
Let us know in the comments, or in our [Discord](https://discord.gg/tZvgjQ6PZf), if you would notice any discrepancies.
///

:octicons-arrow-right-24: [**Deploying a lab**](lab.md)

If instead of following this in-depth getting started guide you prefer to cut corners and quickly skim through the basics, you can check out the [Navigating SR Linux blog post](../blog/posts/2024/navigating-srl.md) that introduces the SR Linux concepts in a condensed format.

## Documentation

This portal does not substitute but augments the official SR Linux documentation. You can find official docs using one of the following links:

1. SR Linux documentation collection - https://documentation.nokia.com/srlinux
2. Short and sweet URLs with the release version being part of the URL
    1. https://doc.srlinux.dev/22-11 for the main documentation pages of SR Linux 22.11 release.
    2. https://doc.srlinux.dev/rn22-11-2 for a direct link to Release Notes.
3. Nokia Network Infrastructure documentation collection - https://bit.ly/iondoc

## SR Linux videos

If your way of learning is through videos, you will appreciate short and to-the-point videos introducing various SR Linux concepts on Nokia's YouTube channel. This [YouTube playlist](https://www.youtube.com/playlist?list=PLgKNvl454Bxe-ZRGR3huFBQajVSH6Ns4J) is for you to explore.

-{{youtube(url="https://www.youtube.com/embed/-EV8XnJp7zY?si=-KYJt47ROwbqdgED")}}-

## My DCF Learning Labs

More than just a lab service, **My DCF Learning Labs** offers lab exercises complete with inline instructions and solutions, giving you everything you need in one easy-to-use browser-based application - access multiple lab types and exercises to develop your SR Linux skills.

[Learn more](https://www.nokia.com/networks/training/dcf/my-dcf-learning-labs/?utm_source=Learn+SR+Linux) about My DCF Learning Labs and [watch a tutorial](https://www.youtube.com/watch?v=ycDNLoYrdko), or [request your free access now](https://forms.office.com/e/x8d1P1rdNt).
