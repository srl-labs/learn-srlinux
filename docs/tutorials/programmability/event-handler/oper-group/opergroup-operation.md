---
comments: true
---

## Start up

When the Event Handler instance is configured and administratively enabled an initial sync of the monitored paths state is done. As a result of that initial sync, Event Handler immediately attempts to execute a script as it receives the state for the monitored paths.

Users can check the status of a particular event handler instance by querying the state datastore:

```js
--{ + running }--[  ]--
A:leaf1# info from state /system event-handler instance opergroup
    system {
        event-handler {
            instance opergroup {
                admin-state enable
                upython-script opergroup.py
                oper-state up
                last-input "{\"paths\":[{\"path\":\"interface ethernet-1/49 oper-state\",\"value\":\"up\"},{\"path\":\"interface ethernet-1/50 oper-state\",\"value\":\"up\"}],\"options\":{\"down-links\":[\"ethernet-1/1\"],\"required-up-uplinks\":\"1\",\"required-up-uplins\":\"1\"}}"
                last-output "{\"actions\": [{\"set-ephemeral-path\": {\"path\": \"interface ethernet-1/1 oper-state\", \"value\": \"up\"}}]}"
                last-stdout-stderr ""
                path [
                    "interface ethernet-1/{49..50} oper-state"
                ]
                options {
                    object down-links {
                        values [
                            ethernet-1/1
                        ]
                    }
                    object required-up-uplinks {
                        value 1
                    }
                }
                statistics {
                    execution-duration 0
                    last-execution "20 minutes ago"
                    total-execution-duration 0
                    execution-count 2
                    execution-successes 2
                }
            }
        }
    }
```

Notable leaves in the state definition of the instance:

* `oper-state` - the operational state of the instance. In case of any errors in the script and/or configuration, the state will be `down`.
* `oper-reason` and `oper-reason-detail` - these leaves will contain info on the reasoning behind the event handler instance to be rendered operationally down.
* `last-input` - input json string that was used during the last execution.
* `last-stdout-stderr` - here you will find outputs from your script such as print statements and log messages.
* `last-output` - output json string that was produced by a script during the last execution.
* `statistics` - statistical information about the execution process.

The state dump above captures the state of the `opergroup` event handler instance after the second successful run.

## Running mode

Let's get back to our running fabric and once again verify that we have opergroup instance configured and running before we start manipulating the uplink's state.

=== "checking opergroup config"
    ```js
    A:leaf1# info from running /system event-handler instance opergroup
        system {
            event-handler {
                instance opergroup {
                    admin-state enable
                    upython-script opergroup.py
                    path [
                        "interface ethernet-1/{49..50} oper-state"
                    ]
                    options {
                        object down-links {
                            values [
                                ethernet-1/1
                            ]
                        }
                        object required-up-uplinks {
                            value 1
                        }
                    }
                }
            }
        }
    ```
=== "ensuring opergroup is running"
    ```js
    A:leaf1# info  from state /system event-handler instance opergroup oper-state
        system {
            event-handler {
                instance opergroup {
                    oper-state up
                }
            }
        }
    ```

### Disabling one uplink

Let's start first putting down a single uplink with leaving the other one operational. Our oper-group is configured in such a way that unless we lose both uplinks nothing should happen to the downstream ethernet-1/1 interface. Time to put this to test.

1. Starting with the four streams 200 kbps each running for 60 seconds

    ```
    docker exec -it client1 iperf3 -c 192.168.100.2 -b 200K -P 4 -t 60
    ```

2. At ~T=45s disable `ethernet-1/49` uplink interface by putting it administratively down with the following command

    ```
    bash set-uplinks.sh leaf1 49 disable
    ```

3. Observe traffic distribution with grafana charts

What you should see has to resemble the following picture:

[![grafana3](https://gitlab.com/rdodin/pics/-/wikis/uploads/28ba3e93f680f4ecf257817fb5ec5b98/image.png)](https://gitlab.com/rdodin/pics/-/wikis/uploads/28ba3e93f680f4ecf257817fb5ec5b98/image.png)

Initially, traffic is nicely balanced between two leaves and then even more through each leaf's uplinks. When we disable `ethernet-1/49` interface a single stream that was flowing through it got rerouted to `ethernet-1/50` and nothing impacted our streams. See how steady that line is on both access interfaces of our leaves.

As for the Event Handler, it should've been executed a script once again, because, remember, the script runs every time __any__ of the monitored objects change. Fetch the state of our opergroup instance and see for yourself:

```js
A:leaf1# info from state /system event-handler instance opergroup
    system {
        event-handler {
            instance opergroup {
                admin-state enable
                upython-script opergroup.py
                oper-state up
                last-input "{\"paths\":[{\"path\":\"interface ethernet-1/49 oper-state\",\"value\":\"down\"},{\"path\":\"interface ethernet-1/50 oper-state\",\"value\":\"up\"}],\"options\":{\"debug\":\"true\",\"down-links\":[\"ethernet-1/1\"],\"required-up-uplinks\":\"1\",\"required-up-uplins\":\"1\"}}"
                last-output "{\"actions\": [{\"set-ephemeral-path\": {\"path\": \"interface ethernet-1/1 oper-state\", \"value\": \"up\"}}]}"
                last-stdout-stderr "num of required up uplinks = 1
detected num of up uplinks = 1
downlinks new state = up
"
--snip--
```

Note, that `last-input` leaf has a `down` value for the oper-state of `ethernet-1/49`. At the same time, the `last-output` leaf that contains the output structure passed by our script indicates the `up` state for the access `ethernet-1/1` interface.  
That is because we have met our condition of having at least one uplink operational before putting down access links.

The `last-stdout-stderr` leaf will show the debug statements we print out in our script to help us see which variables had which values during the script execution.

* `num of required up uplinks = 1`: this value we configured via options is a constant.
* `detected num of up uplinks = 1`: this is a calculated number of operational uplinks that our script performs using the input JSON string passed by Event Handler. Since one of the interfaces was down, the number of operational ones is `1`.
* `downlinks new state = up`: since we met our condition and the number of operational interfaces is not less than the configured number of required active uplinks, the access interface must be operational.

### Disabling all uplinks

So far so good, now let's have a look at a case where a `leaf1` loses its second uplink. This is where we expect Event Handler to enforce and put the access interface down to prevent traffic blackholing.

1. Starting with the four streams 200 kbps each running for 60 seconds

    ```
    docker exec -it client1 iperf3 -c 192.168.100.2 -b 200K -P 4 -t 60
    ```

2. At ~T=30s disable `ethernet-1/50` uplink interface by putting it administratively down with the following command

    ```
    bash set-uplinks.sh leaf1 50 disable
    ```

3. Observe traffic distribution with grafana charts

[![grafana4](https://gitlab.com/rdodin/pics/-/wikis/uploads/635a20cc043e8e8c5cda63ac02667c6c/image.png)](https://gitlab.com/rdodin/pics/-/wikis/uploads/635a20cc043e8e8c5cda63ac02667c6c/image.png)

That is Event Handler-based oper-group feature in action! As the annotations explain, the event of `ethernet-1/50` going down gets noticed by the Event Handler and it disables `leaf1` access link to prevent traffic from blackholing.

All the streams that were served by `leaf1` moves to `leaf2` and no disruption is made to the TCP sessions. Iperf client reports that there were a few retransmits for the two streams that switched to the `leaf2` mid-flight, but that's it:

```
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-60.00  sec  1.48 MBytes   207 Kbits/sec    0             sender
[  5]   0.00-60.00  sec  1.48 MBytes   207 Kbits/sec                  receiver
[  7]   0.00-60.00  sec  1.48 MBytes   207 Kbits/sec    0             sender
[  7]   0.00-60.00  sec  1.48 MBytes   207 Kbits/sec                  receiver
[  9]   0.00-60.00  sec  1.48 MBytes   207 Kbits/sec    3             sender
[  9]   0.00-60.00  sec  1.48 MBytes   207 Kbits/sec                  receiver
[ 11]   0.00-60.00  sec  1.48 MBytes   207 Kbits/sec    1             sender
[ 11]   0.00-60.00  sec  1.48 MBytes   207 Kbits/sec                  receiver
[SUM]   0.00-60.00  sec  5.92 MBytes   828 Kbits/sec    4             sender
[SUM]   0.00-60.00  sec  5.92 MBytes   828 Kbits/sec                  receiver

iperf Done.
```

On the Event Handler site we will see the following picture:

```js
A:leaf1# info from state /system event-handler instance opergroup
    system {
        event-handler {
            instance opergroup {
                admin-state enable
                upython-script opergroup.py
                oper-state up
                last-input "{\"paths\":[{\"path\":\"interface ethernet-1/49 oper-state\",\"value\":\"down\"},{\"path\":\"interface ethernet-1/50 oper-state\",\"value\":\"down\"}],\"options\":{\"debug\":\"true\",\"down-links\":[\"ethernet-1/1\"],\"required-up-link\":\"1\",\"required-up-uplinks\":\"1\"}}"
                last-output "{\"actions\": [{\"set-ephemeral-path\": {\"path\": \"interface ethernet-1/1 oper-state\", \"value\": \"down\"}}]}"
                last-stdout-stderr "num of required up uplinks = 1
detected num of up uplinks = 0
downlinks new state = down
"
```

First, in the `last-input` we see that Event Handler rightfully passes the current state of both uplinks, which is `down`.  
Next, in the `last-stdout-stderr` field we see that the script correctly calculated that no uplinks are operational and the desired state for the downlinks is `down`.  
Finally, the `last-output` now lists `set-ephemeral-path` with `down` value for the access interface. This will effectively get processed by the Event Handler and put down the `ethernet-1/1` interface.

### Enabling interfaces

In the reverse order, let's bring both uplinks up and see what happens.

1. Starting with the four streams 200 kbps each running for 100 seconds

    ```
    docker exec -it client1 iperf3 -c 192.168.100.2 -b 200K -P 4 -t 100
    ```

2. At ~T=30s bring both uplinks up

    ```
    bash set-uplinks.sh leaf1 "{49..50}" enable
    ```

3. Observe traffic distribution with grafana charts

[![grafana4](https://gitlab.com/rdodin/pics/-/wikis/uploads/e5991379867f4279ee6b96e9d5ad4a27/image.png)](https://gitlab.com/rdodin/pics/-/wikis/uploads/e5991379867f4279ee6b96e9d5ad4a27/image.png)

We started with all streams taking `leaf2` route, granted that `leaf1` access interface was operationally `down` as a result of Event Handler operation.

Then when we brought uplinks up, Event Handler enabled access interface `ethernet-1/1` on `leaf1` and strange things happened. Instead of seeing traffic moving over to `leaf1`, we see how it moves away from `leaf2`, but doesn't pass through `leaf1`.

The reason is that `leaf1` although got its uplinks back in an operational state, wasn't able to establish iBGP sessions and get its EVPN routes yet. Thus, traffic was getting stuck. Then iBGP sessions came up, but at this point, TCP sessions were in backoff retry mode, so they were not immediately passing through `leaf1`.

Eventually, closer to the end of the test we see how TCP streams managed to get back in shape and spiked in bitrate to meet the bitrate goal.

This is quite an interesting observation, because it is evident that it might not be optimal to bring the access interface up when uplinks get operational, instead, we may want to improve our oper-group script to enable the access interface only when iBGP sessions are ready, or even EVPN routes are received and installed.
