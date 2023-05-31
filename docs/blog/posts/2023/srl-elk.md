---
date: 2023-02-12
tags:
  - syslog
  - sr linux
  - elk
  - logging
authors:
  - azyablov
  - rdodin
---

# SR Linux logging with ELK

<small>**Join the discussion:** [:material-linkedin: LinkedIn post][discussion-linkedin] · [:material-twitter: Twitter thread][discussion-twitter]</small>

In a not-so-distant past, manually extracting, parsing, and reading log files produced by network elements was standard practice for a sysadmin. With arcane piping of old-but-good `grep`, `awk`, and `sed` tools, one could swiftly identify a problem in a relatively large system. This was a viable approach for quite some time, but it became prey to a massive scale.

Today's network infrastructures often count thousands of elements, each emitting log messages. Getting through a log collection of this size with CLI tools designed decades ago might not be the best tactic. As well as correlating logs between network elements and application logs might be impossible without software solutions built with such use cases in mind.

The unprecedented growth in the application world boosted the development of multi-purposed centralized/cloud data collectors that make observability and discovery over huge data sets a reality. Elasticsearch / Logstash / Kibana (or ELK for short) is one of the most known open-source stacks tailored for the collection and processing of various documents, logs included.

To enable the processing of captured logs and deliver performant and robust search analytics log collectors rely on structured data. Unfortunately, the networking world is infamous for iterating slowly. For example, an outdated and informational [Syslog][syslog-wiki] interface still dominates the networking space when it comes to managing and transferring logs. [Syslog RFC3164](https://datatracker.ietf.org/doc/html/rfc3164)[^4] was not designed to allow extensible structured payloads, which adds a fair share of problems with integrating such systems with modern log collectors.

This post explains how an SR Linux-powered DC fabric can be integrated with a modern logging infrastructure based on the Elasticsearch / Logstash / Kibana stack to collect, transform, handle, and view logs.

<!-- more -->

## Lab

As you would have expected, the post is accompanied by the [containerlab][clab-install]-based [lab][topo-file] that consists of an SR Linux fabric and ELK stack.  
DC Fabric comes preconfigured with an EVPN-VXLAN L2 domain instance, and syslog-based logging is set up on the SR Linux network elements.

!!!note
    Anyone can spin this lab on their machine since all the lab elements are using official public container images.

| Summary                     |                                                                                                                                              |
| :-------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------- |
| **Lab name**                | SR Linux fabric with ELK stack                                                                                                               |
| **Lab components**          | Nokia SR Linux, ELK stack                                                                                                                    |
| **Resource requirements**   | :fontawesome-solid-microchip: 6 vCPU <br/>:fontawesome-solid-memory: 12 GB                                                                   |
| **Lab**                     | [srl-labs/srl-elk-lab][lab-repo]                                                                                                             |
| **Version information**[^1] | [`containerlab:0.41.2`][clab-install], [`srlinux:22.11.1`][srl-container], ELK stack 7.17.7                                                  |
| **Authors**                 | Anton Zyablov [:material-linkedin:][azyablov-linkedin] <br/> Roman Dodin [:material-twitter:][rd-twitter] [:material-linkedin:][rd-linkedin] |

[Lab repository][lab-repo] contains all necessary configuration artifacts, which are mounted to the respective container nodes as outlined in the [topology file][topo-file].

### Topology

A 2-tier DC fabric consists of two spines and four leaves. ELK stack consists of Elasticsearch, Logstash and Kibana nodes.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:1,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/srl-elk-lab/diagrams/elk.drawio&quot;}"></div>

Two clients emulated with Linux containers are connected to the leaves.

### Deployment

Prior to deploying the lab, make sure that containerlab is [installed][clab-install]. The following installation script installs containerlab on most Linux systems.

```bash title="Containerlab installation via installation-script"
bash -c "$(curl -sL https://get.containerlab.dev)"
```

In order to bring up your lab, follow the next simple steps:

1. Clone repo

    ```sh
    git clone https://github.com/srl-labs/srl-elk-lab.git
    cd srl-elk-lab
    ```

2. Deploy the lab

    ```sh
    sudo clab deploy -c
    ```

After a quick minute, 5 SR Linux nodes and ELK stack should be in a running state.

## Logging with Syslog and ELK

Nowadays, instead of keeping unstructured logs on a device and grepping through them, logs are being collected, parsed, and indexed for quick and efficient access. Elasticsearch/Logstash/Kibana (or ELK for short) is the popular stack of technologies that enable modern logging infrastructure. This particular logging stack is used in application and networking realms alike.

We will use the ELK stack to collect, parse, transform, and store logs from SR Linux network elements.

On a high level, our data pipeline undergoes the following stages:

1. SR Linux is configured to send syslog messages to Logstash.
2. Logstash receives raw syslog messages, parses it to create a structured document format, and passes it over to Elasticsearch.
3. Elasticsearch receives structured documents that it indexes and stores.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:2,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/srl-labs/srl-elk-lab/diagrams/elk.drawio&quot;}"></div>

The subsequent chapters of this blog post will zoom in on each of those steps and guide the readers through the process of creating a logging pipeline, running search queries, and using Kibana visualizations.

## Configuring logging on SR Linux

Let's start from the beginning of our data pipeline and configure logging on SR Linux nodes.

Nokia SR Linux Network OS design employs a high level of granularity where each service is represented as a standalone process with a messaging bus enabling inter-process communication. These processes implement logging via the standard Linux [syslog][syslog-wiki] interface. In particular, SR Linux uses a well-known [rsyslog](https://www.rsyslog.com/) server to manage syslog messages in the underlying Linux OS.

!!!tip
    Refer to the [official Logging configuration guide][logging-docs] and [Log Events Guide][log-events-docs] to learn more about logging configuration on SR Linux.

You can modify the SR Linux logging configuration using the CLI, northbound API, or by editing the rsyslog config files[^2].

Basic logging configuration consists of specifying a source for input log messages, filtering the log messages, and specifying an output destination for the filtered log messages.

Messages logged to Linux syslog facilities and messages generated by SR Linux subsystems can be used as input sources for log messages. You can find a list of those facilities and subsystems in the [documentation][log-input-docs].  
When defining a Linux OS facility or SR Linux subsystem as a log source, users can provide a priority param that narrows the capture to a given severity[^3], a range, or a specific set of severities.

A [destination][log-dest-docs] for the ingested and filtered log messages can be one of the following:

- **local log file:** a file on disk that can be configured with retention policies.
- **buffer:** an in-memory file.
- **console:** console output.
- **remote:** remote server.

In the course of this blog post, we will work with a `remote-destination` output type, as we intend to send the log messages over to Logstash for processing.

With a basic understanding of how to configure logging on SR Linux, let's see what does logging configuration look like as seen on `leaf1` node:

```srl title="Syslog configuration on leaf1"
--{ running }--[  ]--
A:leaf1# enter candidate  
--{ candidate shared default }--[  ]--
A:leaf1# system logging  
--{ candidate shared default }--[ system logging ]--
A:leaf1# info 
    network-instance mgmt
    buffer messages {
        # snip
    }
    buffer system {
        # snip
    }
    file messages {
        # snip
    }
    remote-server 172.22.22.11 {
        transport udp
        remote-port 1514
        subsystem aaa {
            priority {
                match-above informational
            }
        }
        subsystem acl {
            priority {
                match-above informational
            }
        }
        # other subsystems snipped here for brevity
        subsystem vxlan {
            priority {
                match-above informational
            }
        }
    }
```

The `remote-server 172.22.22.11` container is where we configure a remote syslog collector; the remote server IP matches the Logstash node address specified in the topology file. A transport protocol/port is provided for the remote log destination, followed by several SR Linux subsystems for which we would like logs to be sent.

### Log format

Consider the following example of syslog-formatted messages that can be seen on SR Linux:

```log
Jan 11 18:39:02 leaf2 sr_bgp_mgr: bgp|1894|1965|00075|N: In network-instance default, the BGP session with VR default (1): Group ibgp-evpn: Peer 10.0.0.5 moved into the ESTABLISHED state
Jan 11 18:39:02 leaf2 sr_bfd_mgr: bfd|1879|1879|00062|N: BFD:  Network-instance default - The protocol BGP is now using BFD session from 10.0.0.2:16395 to 10.0.0.5:0
Jan 11 18:39:02 leaf2 sr_bfd_mgr: bfd|1879|1879|00063|N: BFD:  Network-instance default - Session from 10.0.0.2:16395 to 10.0.0.5:16405 is UP
Jan 11 18:40:31 leaf2 sr_linux_mgr: linux|1658|1658|00256|W: Memory utilization on ram module 1 is above 70%, current usage 83%
```

Log message format that is used by rsyslog when sending to remote destination has the following signature:

```go
<TIMESTAMP> <HOSTNAME> <APPLICATION>: <SUBSYSTEM>|<PID>|<THREAD_ID>|<SEQUENCE>|<SEVERITY>: <MESSAGE>
```

where

```go
<TIMESTAMP>   - Time in format - MMM DD HH:MM:SS.
<HOSTNAME>    - SR Linux hostname.
<APPLICATION> - SR Linux application name, in the context of Syslog this is the Message ID.
<SUBSYSTEM>   - SR Linux subsystem name, which is configured under /system/logging/remote-server 
<PID>         - Process ID.
<THREAD_ID>   - Thread ID.
<SEQUENCE>    - Sequence number, which allows to reproduce order of the messages sent by SR Linux.
<SEVERITY>    - A singe char indicating criticality of the message (I - informational, W - warning, etc.)
<MESSAGE>     - Application free-form message that provides information about the event, that could contain network-instance name, 
                like "Network-instance default".
```

???tip "Dumping syslog messages sent to the remote-server"
    The format that rsyslog uses to send log messages to the remote destination differs from the default format used for `buffer` and `file` destination.

    To see the messages on the wire as they are being sent towards a remote syslog collector users can leverage `tcpdump` tool available on SR Linux:

    ```srl
    --{ running }--[  ]--
    A:leaf1# bash 
    [admin@leaf1 ~]$ tcpdump -vAnni any dst 172.22.22.11
    tcpdump: listening on any, link-type LINUX_SLL2 (Linux cooked v2), snapshot length 262144 bytes

    23:21:04.782934 mgmt0.0 Out IP (tos 0x0, ttl 64, id 60086, offset 0, flags [DF], proto UDP (17), length 141)
        172.22.22.21.58170 > 172.22.22.11.1514: UDP, length 113
    E.....@.@..\.........:...yo.<181>Feb  9 23:21:04 leaf1 sr_aaa_mgr: aaa|1599|1690|00010|N: Opened session for user admin from host 172.22.22.1
    ```

    The dump shows the message as it is on the wire and can be used to write parsers in Logstash.

## Logstash

<small> [:octicons-book-24: Logstash docs][logstash-docs]</small>

Now we are at a point when a raw syslog message has been generated by SR Linux and sent towards its first stop - Logstash.

!!!note
    When preparing this post, savvy folks on Twitter [suggested](https://twitter.com/xeraa/status/1624404576769130497) that Logstash might be overkill for the scope of this lab. Instead, a lightweight Elastic-agent or Filebeat container could've been used.

    This is a sound idea for a sequel.

Logstash's task is to receive syslog messages, parse them into a structured document that Elasticsearch can digest, and pass it over.

Logstash configuration includes four artifacts that we mount to the container:

1. [Logstash config file](https://github.com/srl-labs/srl-elk-lab/blob/main/elk/logstash/logstash.yml) - main configuration file that contains global parameters of the Logstash.
2. [Pipeline config](https://github.com/srl-labs/srl-elk-lab/blob/main/elk/logstash/pipeline) - pipeline configuration file.
3. [Patterns used in the pipeline](https://github.com/srl-labs/srl-elk-lab/blob/main/elk/logstash/patterns) - regexp patterns that are used in the pipeline.
4. [Index template file][index-template] - a file that tells logstash which types to use for custom parsed fields.

The most important Logstash file is the [pipeline config](https://www.elastic.co/guide/en/logstash/7.17/configuration.html) file that defines inputs, filters, and outputs.

### Input

The input section, in our case, looks short and sweet - we take in syslog messages from the socket and apply tags to our messages:

```r title="pipeline input"
input {
    syslog{
        port => 1514
        use_labels => true
        id => "srlinux"
        tags => [ "syslog", "srlinux" ]
        timezone => "Europe/Rome"
    }
}
```

???note "Timezone, ECS and Syslog"
    Dealing with timezones is never easy, especially when Syslog RFC3164 timestamp format is like this:

    ```
    Feb 12 12:48:10
    ```

    Note that the timestamp (besides having no ms precision and year) lacks timezone information. Without the timezone information, we have to specifically set which timezone the received timestamps are in.

    Initially, we used Logstash's `date` filter plugin and provided timezone information there. The plugin worked in the following way:

    1. The timestamp format was parsed by the `date` plugin.
    2. If the timezone field was set in the plugin config, the time was adjusted accordingly.
    3. The resulting timestamp was converted to UTC/GMT format and pushed to the output.

    This worked well until we switched to using Elastic Common Schema (ECS) compatibility mode. After the switch, we noticed that the timestamps were not adjusted to the timezone anymore, resulting in the time being incorrect.

    We found out that by providing the timezone information in the Syslog input chain, we fixed this issue [moved the timezone info](https://github.com/srl-labs/srl-elk-lab/commit/6f984a35cf68d0ea9791d268d0458493c266730a) from the date filter plugin to the input.

### Filter

Most of the work is being done in the **filter** section, which is the pipeline's core. The ingested unstructured data is being parsed using Logstash's filter plugins, such as [grok](https://www.elastic.co/guide/en/logstash/7.17/plugins-filters-grok.html).

```r title="pipeline filter"
filter {
    if "srlinux" in [tags] {
        grok {
            patterns_dir => [ "/var/lib/logstash/patterns" ]
            match => { "message" => "%{SRLPROC:subsystem}\|%{SRLPID:pid}\|%{SRLTHR:thread}\|%{SRLSEQ:sequence}\|%{SRLLVL:initial}:\s+(?<message>(.*))" }
            overwrite => [ "message" ]
            # srl container
            add_field => { "[srl][syslog][subsystem]" => "%{subsystem}"}
            add_field => { "[srl][syslog][pid]" => "%{pid}"}
            add_field => { "[srl][syslog][thread]" => "%{thread}"}
            add_field => { "[srl][syslog][sequence]" => "%{sequence}"}
            add_field => { "[srl][syslog][initial]" => "%{initial}"}
            # set ECS version ecs.version
            add_field => { "[ecs][version]" => "1.12.2" }
            # remove unused fields
            remove_field => [ "@version", "event", "service", "subsystem", "pid", "thread", "sequence", "initial" ]
        }

        date {
            match => [ "timestamp",
            "MMM dd yyyy HH:mm:ss",
            "ISO8601"
            ]
            timezone => "Europe/Rome"
        }
    }
}
```

Note that when parsing the syslog messages, we leverage [Elastic Common Schema v1 (ECS)][ecs-docs] which unifies the way fields are represented in the output document[^5]. Fields such as [log](https://www.elastic.co/guide/en/ecs/current/ecs-log.html#field-log-level) and [host](https://www.elastic.co/guide/en/ecs/current/ecs-host.html) are used by ECS to nest data pertaining to the logs and host objects. ECS aims to unify message fields used from various applications and thus provide a streamlined search and visualization experience.

For SR Linux-specific fields that do not map into the ECS, we use the custom `srl` object where we put nested fields such as `pid`, `thread`, etc.

In the filter section, we also parse the date parameter of the syslog message by providing a list of parsing patterns.

### Output

Once the parsing is done, Logstash feeds the structured documents to Elasticsearch as instructed by the output plugin:

```r title="pipeline output"
output {
    if "srlinux" in [tags] {
        if "_grokparsefailure" in [tags] {
            file {
                path => "/srl/fail_to_parse_srl.log"
                codec => rubydebug
            }
        } else {
            elasticsearch {
                hosts => ["http://elastic"]
                ssl => false
                index => "fabric-logs-%{+YYYY.MM.dd}"
                manage_template => true
                template => "/tmp/index-template.json"
                template_name => "fabric-template"
                template_overwrite => true
                id => "fabric-logs"
            }
            stdout {}
        }
    }
}
```

In the output section, we set the address of the elastic server, the desired index name, and the index template file to use.

The [`index-template.json`][index-template] file contains the types that we, as designers of the pipeline, want Elastic to use when indexing and storing documents.

The resulting outgoing JSON document generated at the end of the Logstash pipeline looks similar to that example:

=== "JSON"
    ```json
    {
        "@timestamp": "2023-02-11T16:29:25.000Z",
        "host": {
            "ip": "172.22.22.21",
            "hostname": "leaf1"
        },
        "ecs": {
            "version": "1.12.2"
        },
        "log": {
            "syslog": {
                "priority": 181,
                "facility": {
                    "code": 22,
                    "name": "local6"
                },
                "severity": {
                    "code": 5,
                    "name": "Notice"
                }
            }
        },
        "process": {
            "name": "sr_aaa_mgr"
        },
        "tags": [
            "syslog",
            "srlinux"
        ],
        "message": "Closed session for user admin from host 172.22.22.1",
        "srl": {
            "syslog": {
                "thread": "1681",
                "sequence": "00007",
                "initial": "N",
                "pid": "1630",
                "subsystem": "aaa"
            }
        }
    }
    ```
=== "rdebug"
    The `ruby debug` format is seen in the log of the logstash container as enabled by the `stdout` output for debug purposes.
    ```r
    {
        "@timestamp" => 2023-02-11T16:24:25.000Z,
            "host" => {
                "ip" => "172.22.22.21",
            "hostname" => "leaf1"
        },
            "ecs" => {
            "version" => "1.12.2"
        },
            "log" => {
            "syslog" => {
                "priority" => 181,
                "facility" => {
                    "code" => 22,
                    "name" => "local6"
                },
                "severity" => {
                    "code" => 5,
                    "name" => "Notice"
                }
            }
        },
        "process" => {
            "name" => "sr_aaa_mgr"
        },
            "tags" => [
            [0] "syslog",
            [1] "srlinux"
        ],
        "message" => "Opened session for user admin from host 172.22.22.1",
            "srl" => {
            "syslog" => {
                "thread" => "1681",
                "sequence" => "00006",
                "initial" => "N",
                    "pid" => "1630",
                "subsystem" => "aaa"
            }
        }
    }
    ```

### Debugging

When developing Logstash filters, it is unavoidable to make errors on the first try. There are a couple of tricks worth sharing that can assist in making your life easier.

First, when developing the `grok` patch patterns, it might be helpful to run a simulation using the Dev Tools provided by Kibana to verify that you actually matched the required fields:

![grok-simulation](https://gitlab.com/rdodin/pics/-/wikis/uploads/2809fafd7d5a05ed9a59ff6226801432/image.png){: .img-shadow }

In the event of a parsing failure, Logstash will dump messages it couldn't parse to a file that users can see at `./elk/logstash/logs/fail_to_parse_srl.log`.

In addition to the parsing log, Logstash emits application logs that may provide hints on what went wrong in case of failures as well as outputting events at the end of the pipeline to stdout. You can read this log using `docker logs -f logstash`.

## Elasticsearch

<small> [:octicons-book-24: Elastic docs][elastic-docs]</small>

Elasticsearch is the distributed search and analytics engine at the heart of the Elastic Stack. Logstash and Beats facilitate collecting, aggregating, and enriching your data and storing it in Elasticsearch. Kibana enables you to interactively explore, visualize, and share insights into your data and manage and monitor the stack. Elasticsearch is where the indexing, search, and analysis magic happens.

### Index Template and Mappings

Upon receiving a JSON document from Logstash, Elasticsearch indexes it and stores it in an index structure. When the index is created, Elastic makes the best guess about which types to use for each of the fields belonging to the JSON document. Sometimes the guess is accurate, but in many cases, the auto-guessing misses choosing the right type and, for instance, selects `text` type for an IP address.

Ultimately, however, you know more about your data and how you want to use it than Elasticsearch can. You can define rules to control dynamic mapping and explicitly define mappings to take full control of how fields are stored and indexed. To enforce the correct types for the data we provided the Index Template as explained in the [Logstash output](#output) section.

### Querying the index

To see the documents stored in the Elastic index we can leverage Elastic API using `curl` or Dev Tools panel of Kibana.

???example "Query examples with `curl`"
    === "Listing all documents"
        ```bash
        ❯ curl -s "http://localhost:9200/fabric-logs-*/_search" -H 'Content-Type: application/json' -d'
        {
          "query": {
            "match_all": {}
          }
        }' | jq
        ```
        ```json
        {
          "took": 8,
          "timed_out": false,
          "_shards": {
            "total": 1,
            "successful": 1,
            "skipped": 0,
            "failed": 0
          },
          "hits": {
            "total": {
              "value": 66,
              "relation": "eq"
            },
            "max_score": 1,
            "hits": [
              {
                "_index": "fabric-logs-2023.02.12",
                "_type": "_doc",
                "_id": "-AQDRoYB-MNGUHTecRIg",
                "_score": 1,
                "_source": {
                  "host": {
                    "ip": "172.22.22.21",
                    "hostname": "leaf1"
                  },
                  "ecs": {
                    "version": "1.12.2"
                  },
                  "@timestamp": "2023-02-12T14:24:36.000Z",
                  "process": {
                    "name": "sr_aaa_mgr"
                  },
                  "message": "Closed session for user admin from host 172.22.22.1",
                  "tags": [
                    "syslog",
                    "srlinux"
                  ],
                  "srl": {
                    "syslog": {
                      "initial": "N",
                      "subsystem": "aaa",
                      "pid": "1227",
                      "thread": "1260",
                      "sequence": "00011"
                    }
                  },
                  "log": {
                    "syslog": {
                      "severity": {
                        "code": 5,
                        "name": "Notice"
                      },
                      "facility": {
                        "code": 22,
                        "name": "local6"
                      },
                      "priority": 181
                    }
                  }
                }
              },
            // snip
            ]
          }
        }
        ```
    === "Searching for a particular document"
        Listing logs emitted by `aaa` subsystem of SR Linux from `leaf1` node.
        ```bash
        curl -s "http://localhost:9200/fabric-logs-*/_search" -H 'Content-Type: application/json' -d'
        {
          "query": {
            "bool": {
              "must": [
                {
                  "match": {
                    "srl.syslog.subsystem": "aaa"
                  }
                },
                {
                  "match": {
                    "host.hostname": "leaf1"
                  }
                }
              ]
            }
          }
        }' | jq
        ```
        ```json
        {
          "took": 35,
          "timed_out": false,
          "_shards": {
            "total": 1,
            "successful": 1,
            "skipped": 0,
            "failed": 0
          },
          "hits": {
            "total": {
              "value": 6,
              "relation": "eq"
            },
            "max_score": 3.7342224,
            "hits": [
              {
                "_index": "fabric-logs-2023.02.12",
                "_type": "_doc",
                "_id": "-AQDRoYB-MNGUHTecRIg",
                "_score": 3.7342224,
                "_source": {
                  "host": {
                    "ip": "172.22.22.21",
                    "hostname": "leaf1"
                  },
                  "ecs": {
                    "version": "1.12.2"
                  },
                  "@timestamp": "2023-02-12T14:24:36.000Z",
                  "process": {
                    "name": "sr_aaa_mgr"
                  },
                  "message": "Closed session for user admin from host 172.22.22.1",
                  "tags": [
                    "syslog",
                    "srlinux"
                  ],
                  "srl": {
                    "syslog": {
                      "initial": "N",
                      "subsystem": "aaa",
                      "pid": "1227",
                      "thread": "1260",
                      "sequence": "00011"
                    }
                  },
                  "log": {
                    "syslog": {
                      "severity": {
                        "code": 5,
                        "name": "Notice"
                      },
                      "facility": {
                        "code": 22,
                        "name": "local6"
                      },
                      "priority": 181
                    }
                  }
                }
              },
              // snipped
            ]
          }
        }
        ```
    === "Regexp search pattern"
        ```bash
        curl -s "http://localhost:9200/fabric-logs-*/_search" -H 'Content-Type: application/json' -d'
        {
          "query": {
            "bool": {
              "must": [
                {
                  "regexp": {
                    "message": ".*[bB][gG][pP].*"
                  }
                }
              ]
            }
          }
        }' | jq
        ```
        ```json
        {
          "took": 9,
          "timed_out": false,
          "_shards": {
            "total": 1,
            "successful": 1,
            "skipped": 0,
            "failed": 0
          },
          "hits": {
            "total": {
              "value": 44,
              "relation": "eq"
            },
            "max_score": 1,
            "hits": [
              {
                "_index": "fabric-logs-2023.02.12",
                "_type": "_doc",
                "_id": "3gSSRYYB-MNGUHTegRKj",
                "_score": 1,
                "_source": {
                  "host": {
                    "ip": "172.22.22.23",
                    "hostname": "leaf3"
                  },
                  "ecs": {
                    "version": "1.12.2"
                  },
                  "@timestamp": "2023-02-12T13:21:14.000Z",
                  "process": {
                    "name": "sr_bgp_mgr"
                  },
                  "message": "In network-instance default, the BGP session with VR default (1): Group ibgp-evpn: Peer 10.0.0.6 was closed because the router sent this neighbor a NOTIFICATION with code CEASE and subcode CONN_COLL_RES",
                  "tags": [
                    "syslog",
                    "srlinux"
                  ],
                  "srl": {
                    "syslog": {
                      "initial": "W",
                      "subsystem": "bgp",
                      "pid": "1595",
                      "thread": "1622",
                      "sequence": "00006"
                    }
                  },
                  "log": {
                    "syslog": {
                      "severity": {
                        "code": 4,
                        "name": "Warning"
                      },
                      "facility": {
                        "code": 22,
                        "name": "local6"
                      },
                      "priority": 180
                    }
                  }
                }
              },
            // snipped
            ]
          }
        }
        ```

## Kibana

<small> [:octicons-book-24: Kibana docs][kibana-docs]</small>

Even though Elastic is the core of the stack, we made a very short stop at it, because we will leverage Elastic powers through a UI offered by Kibana.

Kibana enables you to give shape to your data and navigate the Elastic Stack. With Kibana, you can:

- **Search, observe, and protect your data.** From discovering documents to analyzing logs to finding security vulnerabilities, Kibana is your portal for accessing these capabilities and more.
- **Analyze your data.** Search for hidden insights, visualize what you’ve found in charts, gauges, maps, graphs, and more, and combine them in a dashboard.
- **Manage, monitor, and secure the Elastic Stack.** Manage your data, monitor the health of your Elastic Stack cluster, and control which users have access to which features.

In the context of this post, we will use the stack management, searching, and visualization capabilities of Kibana.

To access Kibana web UI point your browser to http://localhost:5601/ address.

### Index Management

Kibana makes it easy to manage your stack by providing a nice UI on top of the rich API. Using the menu, navigate to the `Management -> Stack Management` item to open the management pane of the whole stack.

To see the index created by Elastic when Logstash sends data, use the `Index Management` menu.

![index-mgmt](https://gitlab.com/rdodin/pics/-/wikis/uploads/0c8de6595d322f923e390cff3de38a75/image.png){: .img-shadow }

Clicking on the index name brings up the index details, where the most interesting part is the `Mappings` used by this index.

### Index Patterns

Kibana requires an [Index Pattern][kibana-index-pattern-docs] to access the Elasticsearch data that you want to explore. An index pattern selects the data to use and allows you to define properties of the fields.

Select `Index Pattern` item in the Management section to create an index pattern for the index Elastic created. Apart from the pattern name that should match the index, you have to select a field that denotes the event timestamp, in our case it is `@timestamp`.

When Index Pattern is created, you may start searching through logs and create visualizations.

!!!tip "Load saved objects"
    It might be useful to create a search and visualization panels yourself to get a hold of the process, but if you'd rather skip this part we offer an import procedure:

    ```bash
    bash ./add-saved-objects.sh
    ```

    This script will load the Index Pattern, as well as a sample visualization dashboard and a Discover panel.

### Discover

Now to the meat of it. The parsed logs are now neatly stored in Elastic, and you can explore them by navigating to the `Analytics -> Discover` menu item. If you have imported the saved objects prepared by us, you will be able to open the `[Discover] Fabric Logs` saved search configuration that already selects some fields and sort them in descending order.
=== "Selecting the saved search"
    ![saved-search](https://gitlab.com/rdodin/pics/-/wikis/uploads/c1cb87876330a14beb84b283b06aa89f/image.png){: .img-shadow }
=== "Selecting time window"
    Make sure to select the time window that suits the time at which logs were collected.
    ![time-window](https://gitlab.com/rdodin/pics/-/wikis/uploads/4e07fc5550965a83600c24737b448259/image.png){: .img-shadow }

The Discover pane allows you to filter and search the documents stored in the index; you may play with the data using the query language and identify and correlate log events.

![discover](https://gitlab.com/rdodin/pics/-/wikis/uploads/67058de5f0b65f8bcc66ea4714ce7189/image.png){: .img-shadow }

### Dashboard

In the `Analytics -> Dashboard` users get a chance to create interactive dashboards with a wide variety of plots available. We provided a sample dashboard that gives you a sense of what can be displayed using the collected data.

![dash](https://gitlab.com/rdodin/pics/-/wikis/uploads/497301caef8c5915f1d8d1126dbf288e/image.png){: .img-shadow }

The provided dashboard also makes it easy to skim through logs and select the ones you need to dive into:

<video width="100%" controls playsinline><source src="https://gitlab.com/rdodin/pics/-/wikis/uploads/bfa97831e557a5d0ab6f4245497d9e81/2023-02-11_18-23-48.mp4" type="video/mp4"></video>

## Summary

Congratulations, you've reached the end of this post :clap: :clap: :clap:

We hope you liked it and learned how logs from the network elements could be fed into the modern logging infrastructure based on ELK stack.

It all started with [configuring](#configuring-logging-on-sr-linux) Syslog on SR Linux.

Unfortunately, the unstructured nature of RFC3164 Syslog mandated the use of [Logstash](#logstash), which is a feature-rich log collector. We learned how to use Logstash to parse the unstructured logs, transform them into JSON documents, and output them to Elasticsearh for storage.

With [Index Templates](#filter) we learned how to provide the type information for our Elastic index making sure the parsed fields use the correct type, which is crucial for an effective discovery process.

Finally, using [Kibana](#kibana) we learned how to perform basic Stack Management and used search and navigation capabilities.

We left A LOT behind the brackets of this post. API access, logs correlation, Logstash-less collection using elastic-agent, k8s-based deployments. Maybe we should cover some of this in the subsequent post. Let us know in the comments, and till the next one :wave:

[topo-file]: https://github.com/srl-labs/srl-elk-lab/blob/main/srl-elk.clab.yml
[clab-install]: https://containerlab.dev/install/#install-script
[srl-container]: https://github.com/nokia/srlinux-container-image
[azyablov-linkedin]: https://linkedin.com/in/anton-zyablov
[lab-repo]: https://github.com/srl-labs/srl-elk-lab
[index-template]: https://github.com/srl-labs/srl-elk-lab/blob/main/elk/logstash/index-template.json
[ecs-docs]: https://www.elastic.co/guide/en/ecs/1.12/ecs-reference.html
[syslog-wiki]: https://en.wikipedia.org/wiki/Syslog
[logging-docs]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/Configuration_Basics_Guide/configb-logging.html
[log-events-docs]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/Log_Events/log-intro.html
[log-input-docs]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/Configuration_Basics_Guide/configb-logging.html#ai9ep6mg6x
[filter-docs]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/Configuration_Basics_Guide/configb-logging.html#define_filters
[log-dest-docs]: https://documentation.nokia.com/srlinux/22-6/SR_Linux_Book_Files/Configuration_Basics_Guide/configb-logging.html#ai9ep6mg65
[rd-linkedin]: https://linkedin.com/in/rdodin
[rd-twitter]: https://twitter.com/ntdvps
[logstash-docs]: https://www.elastic.co/guide/en/logstash/7.17/introduction.html
[elastic-docs]: https://www.elastic.co/guide/en/elasticsearch/reference/7.17/index.html
[kibana-docs]: https://www.elastic.co/guide/en/kibana/7.17/index.html
[kibana-index-pattern-docs]: https://www.elastic.co/guide/en/kibana/7.17/index-patterns.html
[discussion-linkedin]: https://www.linkedin.com/feed/update/urn:li:activity:7030840418195906560/
[discussion-twitter]: https://twitter.com/ntdvps/status/1625074576286748672

[^1]: The lab was tested with these particular versions. It might work with a more recent version of the components.
[^2]: The SR Linux installs a minimal version of the `/etc/rsyslog.conf` file and maintains an SR Linux-specific configuration file in the `/etc/rsyslog.d/` directory.
[^3]: For fine-grain control over the log messages, refer to the [Filter][filter-docs] section of the logging guide.
[^4]: The informational RFC 3164 for Syslog was obsoleted by [RFC 5424](https://datatracker.ietf.org/doc/html/rfc5424), but unfortunately, it didn't get traction in the industry.
[^5]: Check the [output](#output) section to see how ECS populates data in the `log`, `host` and `process` objects automatically when parsing the syslog messages.

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
