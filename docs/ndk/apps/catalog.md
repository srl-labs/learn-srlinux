# App Catalog

SR Linux NetOps Development Kit (NDK) enables its users to write apps which can solve many automation tasks, operational hurdles or optimization problems.

gRPC based service that provides a deep integration with Network OS is quite a novel thing for a networking domain, which makes NDK application examples the second most valuable asset after the NDK documentation provided here. Sometimes the best applications are born after getting inspired by other's work or as a combination of ideas implemented in different examples.

With App Catalog our intention is to collect references to the noteworthy NDK applications that have been open sourced by Nokia engineers or 3rd parties. We hope that with that growing catalog of examples both new and seasoned NDK users will find something that can inspire them to create their next app.

!!!warning "Disclaimer"

    The examples listed in the App Catalog are not of a production quality and should not be used as such. Visitors of App Catalog should treat those applications/agents as a demo examples of what can be achieved with NDK.

    The applications that are kept under `srl-labs` or `nokia` GitHub organizations are not official Nokia products, unless explicitly mentioned.

## NDK agents
### EVPN Proxy
:material-language-python: · [`jbemmel/srl-evpn-proxy`](https://github.com/jbemmel/srl-evpn-proxy)

SR Linux EVPN Proxy agent that allows to bridge EVPN domains with domains that only employ static VXLAN.  
[:octicons-arrow-right-24: Read more](evpn-proxy.md)

### kButler
:material-language-go: · [`brwallis/srlinux-kbutler`](https://github.com/brwallis/srlinux-kbutler)

kButler agent ensures that for every worker node which hosts an application with an exposed service, there is a corresponding FIB entry for the service external IP with a next-hop of the worker node.  
[:octicons-arrow-right-24: Read more](kbutler.md)

### Prometheus Exporter
:material-language-go: · [`karimra/srl-prometheus-exporter`](https://github.com/karimra/srl-prometheus-exporter)

SR Linux Prometheus Exporter agent creates prometheus scrape-able endpoints on individual switches. This telemetry horizontally scaled telemetry collection model comes with additional operational enhancements over traditional setups with a central telemetry collector.  
[:octicons-arrow-right-24: Read more](srl-prom-exporter.md)