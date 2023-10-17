# App Catalog

SR Linux NetOps Development Kit (NDK) enables its users to write apps to solve many automation tasks, operational hurdles, or optimization problems.

gRPC based service that provides deep integration with Network OS is quite a novel thing for a networking domain, making NDK application examples the second most valuable asset after the NDK documentation. Sometimes the best applications are born after getting inspired by others' work or ideas implemented in different projects.

With the App Catalog, we intend to collect references to the noteworthy NDK applications that Nokia engineers or 3rd parties have open-sourced. With that growing catalog of examples, we hope that both new and seasoned NDK users will find something that can inspire them to create their next app.

!!!warning "Disclaimer"

    The examples listed in the App Catalog are not of production quality and should not be used "as is." Visitors of App Catalog should treat those applications/agents as demo examples of what can be achieved with NDK.

    The applications kept under `srl-labs` or `nokia` GitHub organizations are not official Nokia products unless explicitly mentioned.

## NDK agents

### EVPN Proxy

:material-language-python: · [`jbemmel/srl-evpn-proxy`](https://github.com/jbemmel/srl-evpn-proxy)

SR Linux EVPN Proxy agent that allows bridging EVPN domains with domains that only employ static VXLAN.  
[:octicons-arrow-right-24: Read more](evpn-proxy.md)

### kButler

:material-language-go: · [`brwallis/srlinux-kbutler`](https://github.com/brwallis/srlinux-kbutler)

kButler agent ensures that for every worker node which hosts an application with an exposed service, there is a corresponding FIB entry for the service's external IP with a next-hop of the worker node.  
[:octicons-arrow-right-24: Read more](kbutler.md)

### Prometheus Exporter

:material-language-go: · [`karimra/srl-prometheus-exporter`](https://github.com/karimra/srl-prometheus-exporter)

SR Linux Prometheus Exporter agent creates Prometheus scrape-able endpoints on individual switches. This horizontally-scaled telemetry collection model has additional operational enhancements over traditional setups with a central telemetry collector.  
[:octicons-arrow-right-24: Read more](srl-prom-exporter.md)

### SR Linux GPT Agent a.k.a `askai`

:material-language-go:

An NDK app that leverages OpenAI and context learning with local embeddings to create a Clippy you always wanted to have in your CLI.  
[:octicons-arrow-right-24: Read more](srl-gpt.md)

### Satellite Tracker

:material-language-python: · [`KTodts/srl-satellite-tracker`](https://github.com/KTodts/srl-satellite-tracker)

A fun educational NDK app that displays current coordinates of the Internation Space Station by querying public Internet service providing raw location data.  
[:octicons-arrow-right-24: Read more](satellite.md)
