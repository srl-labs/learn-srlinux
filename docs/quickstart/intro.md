<script type="text/javascript" src="https://cdn.jsdelivr.net/gh/hellt/drawio-js@main/embed2.js" async></script>

Now that we sorted out how to [get and run SR Linux container image](get-started.md), lets see how to get around this brand new Network Operating System by going through a short exercise of configuring a VXLAN based EVPN service in a tiny CLOS fabric.

The mini CLOS fabric will consist of the two leaf switches and a single spine:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:0,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/learn-srlinux/site/diagrams/quickstart.drawio&quot;}"></div>

To deploy this 3-node fabric we will use the following [containerlab](https://containerlab.srlinux.dev) file[^1]:

```yaml
name: quickstart

topology:
  kinds:
    srl:
      image: ghcr.io/nokia/srlinux
    linux:
      image: ghcr.io/hellt/network-multitool

  nodes:
    leaf1:
      kind: srl
      type: ixrd2
    leaf2:
      kind: srl
      type: ixrd2
    spine1:
      kind: srl
      type: ixrd3
    client1:
      kind: linux
    client2:
      kind: linux

  links:
    # inter-switch links
    - endpoints: ["leaf1:e1-49", "spine1:e1-1"]
    - endpoints: ["leaf2:e1-49", "spine1:e1-2"]
    # server links
    - endpoints: ["client1:eth1", "leaf1:e1-1"]
    - endpoints: ["client2:eth1", "leaf2:e1-1"]
```

Save the contents of this file under `quickstart.clab.yml` and you are ready to deploy:
```
$ containerlab deploy -t labs/quickstart.clab.yml
INFO[0000] Parsing & checking topology file: quickstart.clab.yml 
INFO[0000] Creating lab directory: /root/learn.srlinux.dev/clab-quickstart 
INFO[0000] Creating root CA                             
INFO[0001] Creating container: client2                  
INFO[0001] Creating container: client1                  
INFO[0001] Creating container: leaf2                    
INFO[0001] Creating container: spine1                   
INFO[0001] Creating container: leaf1                    
INFO[0002] Creating virtual wire: leaf1:e1-49 <--> spine1:e1-1 
INFO[0002] Creating virtual wire: client2:eth1 <--> leaf2:e1-1 
INFO[0002] Creating virtual wire: leaf2:e1-49 <--> spine1:e1-2 
INFO[0002] Creating virtual wire: client1:eth1 <--> leaf1:e1-1 
INFO[0003] Writing /etc/hosts file                      

+---+-------------------------+--------------+---------------------------------+-------+-------+---------+----------------+----------------------+
| # |          Name           | Container ID |              Image              | Kind  | Group |  State  |  IPv4 Address  |     IPv6 Address     |
+---+-------------------------+--------------+---------------------------------+-------+-------+---------+----------------+----------------------+
| 1 | clab-quickstart-client1 | 82f254bd1c25 | ghcr.io/hellt/network-multitool | linux |       | running | 172.20.20.5/24 | 2001:172:20:20::5/64 |
| 2 | clab-quickstart-client2 | 7270eb292077 | ghcr.io/hellt/network-multitool | linux |       | running | 172.20.20.6/24 | 2001:172:20:20::6/64 |
| 3 | clab-quickstart-leaf1   | d7e220198e5f | ghcr.io/nokia/srlinux           | srl   |       | running | 172.20.20.9/24 | 2001:172:20:20::9/64 |
| 4 | clab-quickstart-leaf2   | a3dad054fa65 | ghcr.io/nokia/srlinux           | srl   |       | running | 172.20.20.7/24 | 2001:172:20:20::7/64 |
| 5 | clab-quickstart-spine1  | 6534015974c8 | ghcr.io/nokia/srlinux           | srl   |       | running | 172.20.20.8/24 | 2001:172:20:20::8/64 |
+---+-------------------------+--------------+---------------------------------+-------+-------+---------+----------------+----------------------+
```

Containerlab will finish the deployment with providing a summary table that will outline connection details of the deployed nodes. In the "Name" column we will have the names of the deployed containers and those names can be used to reach the nodes, for example:

```bash
# connecting to the leaf1 device via SSH
ssh admin@clab-quickstart-leaf1
```

With the deployed lab we are ready to explore SR Linux basic concepts going step by step through the EVPN configuration journey.

[^1]: To ensure reproducibility and consistency of the examples provided in this quickstart, we will pin to a particular SR Linux version in the containerlab file.