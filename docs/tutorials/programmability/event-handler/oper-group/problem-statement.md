---
comments: true
---

Before we meet the Event Handler framework of SR Linux and leverage it to configure oper-group feature, it is crucial to understand the problem at hand.  
As was mentioned in the [introduction](oper-group-intro.md), without oper-group feature traffic loss can occur should any leaf lose all its uplinks. Let's lab a couple of scenarios that highlight a problem that oper-group is set to remedy.

## Healthy fabric scenario

The startup configuration that our lab is equipped with gets our fabric to a state where traffic can be exchanged between clients. Users can verify that by running a simple iperf-based traffic test.

In our lab, `client2` runs iperf3 server, while `client1` acts as a client. With the following command we can run a single stream of TCP data with a bitrate of 200 Kbps:

```bash
docker exec -it client1 iperf3 -c 192.168.100.2 -b 200K
```

Once invoked, `client1` starts to send data towards `client2` for 10 seconds, providing a report by the end of a test.

```
Connecting to host 192.168.100.2, port 5201
[  5] local 192.168.100.1 port 55166 connected to 192.168.100.2 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec   107 KBytes   880 Kbits/sec    0   26.9 KBytes       
[  5]   1.00-2.00   sec  0.00 Bytes  0.00 bits/sec    0   26.9 KBytes       
[  5]   2.00-3.00   sec  0.00 Bytes  0.00 bits/sec    0   26.9 KBytes       
[  5]   3.00-4.00   sec  0.00 Bytes  0.00 bits/sec    0   26.9 KBytes       
[  5]   4.00-5.00   sec   128 KBytes  1.05 Mbits/sec    0   31.1 KBytes       
[  5]   5.00-6.00   sec  0.00 Bytes  0.00 bits/sec    0   31.1 KBytes       
[  5]   6.00-7.00   sec  0.00 Bytes  0.00 bits/sec    0   31.1 KBytes       
[  5]   7.00-8.00   sec  0.00 Bytes  0.00 bits/sec    0   31.1 KBytes       
[  5]   8.00-9.00   sec  0.00 Bytes  0.00 bits/sec    0   31.1 KBytes       
[  5]   9.00-10.00  sec   128 KBytes  1.05 Mbits/sec    0   35.4 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec   363 KBytes   298 Kbits/sec    0             sender
[  5]   0.00-10.00  sec   363 KBytes   298 Kbits/sec                  receiver
```

In addition to iperf results, users can monitor the throughput of `leaf1/2` links using grafana dashboard:
[![grafana](https://gitlab.com/rdodin/pics/-/wikis/uploads/99b290ba11971cc683f221655336ff23/image.png)](https://gitlab.com/rdodin/pics/-/wikis/uploads/99b290ba11971cc683f221655336ff23/image.png)

This visualization tells us that `client1` hashed its single stream[^1] over `client1:eth2` interface that connects to `leaf2:e1-1`. On the "Leaf2 e1-1 throughput" panel in the bottom right we see incoming traffic that indicates data is flowing in via this interface.

Next, we see that `leaf2` used its `e1-50` interface to send data over to a spine layer, through which it reaches `client2` side[^2].

### Load balancing on the client side

Next, it is interesting to verify that client can utilize both links in its `bond0` interface since our L2 EVPN service uses an all-active multihoming mode for the ethernet segment. To test that we need to tell iperf to use eight parallel streams; that is what `-P` flag is for.

With the following command we eight parallel streams, 50 Kbps bitrate each, and this time for 20 seconds.

```bash
docker exec -it client1 iperf3 -c 192.168.100.2 -b 50K -P8 -t 20
```

Our telemetry visualization makes it clear that client-side load balancing is indeed happening as both leaves receive traffic on their `e-1/1` interface.

[![grafana2](https://gitlab.com/rdodin/pics/-/wikis/uploads/eed681981d493d69c3a0b28c9bbeb778/image.png)](https://gitlab.com/rdodin/pics/-/wikis/uploads/eed681981d493d69c3a0b28c9bbeb778/image.png)

`leaf1` and `leaf2` both chose to use their `e1-49` interface to send the traffic to the spine layer.

/// details | Load balancing in the fabric?
You may have noticed that when we send a few streams (for example two parallel streams), the client may hash the two streams over two links in its bond interface. But then leaves used a single uplink interface towards the fabric. This is due to the fact that each leaf got a single "stream" and thus a single uplink interface was utilized.

We can see ECMP in the fabric happening if we send more streams, for example, eight of them:

```bash
docker exec -it client1 iperf3 -c 192.168.100.2 -b 20K -P 10 -t 20
```

That way leaves will have more streams to handle and they will load balance the streams nicely as shown in [this picture](https://gitlab.com/rdodin/pics/-/wikis/uploads/85bd945ff272db2da4d4cd1132c47803/image.png).
///

## Traffic loss scenario

Now to the interesting part. What happens if one of the leaves suddenly loses all its uplinks while traffic is mid-flight? Will traffic be re-routed to healthy leaf? Will it be dropped? Let's lab it out.

We will send 4 streams for 40 seconds long and somewhere in the middle we will execute `set-uplinks.sh` script which administratively disables uplinks on a given leaf:

1. Start the traffic generators

    ```bash
    docker exec -it client1 iperf3 -c 192.168.100.2 -b 50K -P 8 -t 40
    ```

2. Wait ~20s for graphs to form shape
3. Put down both uplinks on `leaf1`

    ```bash
    bash set-uplinks.sh leaf1 "{49..50}" disable
    ```

4. Monitor the traffic distribution

Here is a video demonstrating this workflow:

<video width="100%" controls><source src="https://gitlab.com/rdodin/pics/-/wikis/uploads/140a5861e85014aa329804e8cecdb6c8/2022-05-06_14-54-41.mp4" type="video/mp4"></video>

Let's see what exactly is happening there.

* [00:00 - 00:15] We started eight streams. Those for streams were evenly distributed over the two links of a bond interface of our `client1`.  
    Both leaves report the same amount of traffic detected on their `e1-1` interface, so each leaf handles two streams each.  
    Leaves then load balance these two streams over their two uplinks. We see that both `e1-49` and `e1-50` report outgoing bitrate to be ~200Kbps, which is a bitrate of a single stream we configured. That way every uplink on our leaves is utilized and handling a stream of data.
* [00:34 - 01:00] At this very moment, we execute `bash set-uplinks.sh leaf1 disable` putting uplinks on `leaf1` administratively down. The bottom left panel immediately indicates that the operational status of both uplinks went down.  
    But pay close attention to what is happening with traffic throughput. Traffic rate on `leaf1` access interface drops immediately, as TCP sessions of the streams it was handling stopped to receive ACKs.  
    At the same time, `leaf2` didn't attract any new streams, it has been handling its two streams summing up to 400Kbps all way long. This means, that traffic that was passing through `leaf1` was "blackholed" as `client1` was not notified in any way that one of the links in its bond interface must not be used.

This scenario opens the stage for oper-group, as this feature provides means to make sure that a client won't use a link that is connected to a leaf that has no means to forward traffic to the fabric.

[^1]: iperf3 sends data as a single stream, until `-P` flag is set.
[^2]: when you start traffic for the first time, you might wonder why a leaf that is not used for traffic forwarding gets some traffic on its uplink interface for a brief moment as shown [here](https://twitter.com/ntdvps/status/1522265449265864706). Check out this link to see why is this happening.
