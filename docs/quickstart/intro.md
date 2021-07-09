<script type="text/javascript" src="https://cdn.jsdelivr.net/gh/hellt/drawio-js@main/embed2.js" async></script>

Now that we sorted out how to [get and run SR Linux container image](get-started.md), lets see how to get around this brand new Network Operating System by going through a short exercise of configuring a VXLAN based EVPN service in a tiny CLOS fabric.

The fabric will consist of the two leaf switches and a single spine:

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:0,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/learn-srlinux/site/diagrams/quickstart.drawio&quot;}"></div>

Service-wise the two servers will appear to be on the same L2 network by means of the EVPN service deployed.

<div class="mxgraph" style="max-width:100%;border:1px solid transparent;margin:0 auto; display:block;" data-mxgraph="{&quot;page&quot;:1,&quot;zoom&quot;:2,&quot;highlight&quot;:&quot;#0000ff&quot;,&quot;nav&quot;:true,&quot;check-visible-state&quot;:true,&quot;resize&quot;:true,&quot;url&quot;:&quot;https://raw.githubusercontent.com/learn-srlinux/site/diagrams/quickstart.drawio&quot;}"></div>

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
    srv1:
      kind: linux
    srv2:
      kind: linux

  links:
    # inter-switch links
    - endpoints: ["leaf1:e1-49", "spine1:e1-1"]
    - endpoints: ["leaf2:e1-49", "spine1:e1-2"]
    # server links
    - endpoints: ["srv1:eth1", "leaf1:e1-1"]
    - endpoints: ["srv2:eth1", "leaf2:e1-1"]
```

Save the contents of this file under `quickstart.clab.yml` and you are ready to deploy:
```
$ containerlab deploy -t quickstart.clab.yml
INFO[0000] Parsing & checking topology file: quickstart.clab.yml 
INFO[0000] Creating lab directory: /root/learn.srlinux.dev/clab-quickstart 
INFO[0000] Creating root CA                             
INFO[0001] Creating container: srv2                  
INFO[0001] Creating container: srv1                  
INFO[0001] Creating container: leaf2                    
INFO[0001] Creating container: spine1                   
INFO[0001] Creating container: leaf1                    
INFO[0002] Creating virtual wire: leaf1:e1-49 <--> spine1:e1-1 
INFO[0002] Creating virtual wire: srv2:eth1 <--> leaf2:e1-1 
INFO[0002] Creating virtual wire: leaf2:e1-49 <--> spine1:e1-2 
INFO[0002] Creating virtual wire: srv1:eth1 <--> leaf1:e1-1 
INFO[0003] Writing /etc/hosts file                      

+---+------------------------+--------------+---------------------------------+-------+-------+---------+----------------+----------------------+
| # |          Name          | Container ID |              Image              | Kind  | Group |  State  |  IPv4 Address  |     IPv6 Address     |
+---+------------------------+--------------+---------------------------------+-------+-------+---------+----------------+----------------------+
| 1 | clab-quickstart-leaf1  | 4b81c65af558 | ghcr.io/nokia/srlinux           | srl   |       | running | 172.20.20.7/24 | 2001:172:20:20::7/64 |
| 2 | clab-quickstart-leaf2  | de000e791dd6 | ghcr.io/nokia/srlinux           | srl   |       | running | 172.20.20.8/24 | 2001:172:20:20::8/64 |
| 3 | clab-quickstart-spine1 | 231fd97d7e33 | ghcr.io/nokia/srlinux           | srl   |       | running | 172.20.20.6/24 | 2001:172:20:20::6/64 |
| 4 | clab-quickstart-srv1   | 3a2fa1e6e9f5 | ghcr.io/hellt/network-multitool | linux |       | running | 172.20.20.3/24 | 2001:172:20:20::3/64 |
| 5 | clab-quickstart-srv2   | fb722453d715 | ghcr.io/hellt/network-multitool | linux |       | running | 172.20.20.5/24 | 2001:172:20:20::5/64 |
+---+------------------------+--------------+---------------------------------+-------+-------+---------+----------------+----------------------+
```

Containerlab will finish the deployment with providing a summary table that will outline connection details of the deployed nodes. In the "Name" column we will have the names of the deployed containers and those names can be used to reach the nodes, for example:

```bash
# connecting to the leaf1 device via SSH
ssh admin@clab-quickstart-leaf1
```

With the lab deployed we are ready to embark on our EVPN configuration journey, but we advise the newcomers to first start with reading the [SR Linux basic concepts](hwtypes.md) before diving into the configuration waters.

[^1]: To ensure reproducibility and consistency of the examples provided in this quickstart, we will pin to a particular SR Linux version in the containerlab file.