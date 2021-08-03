The SR Linux software supports seven Nokia hardware platforms[^1]:

* 7250 IXR-6
* 7250 IXR-10
* 7220 IXR-D1
* 7220 IXR-D2
* 7220 IXR-D3
* 7220 IXR-H2
* 7220 IXR-H3

Out of those seven hardware variants, the first five are available for emulation within SR Linux container image.

The `type` field under the node configuration sets the emulated hardware type in the containerlab file:

```yaml
# part of the evpn01.clab.yml file
  nodes:
    leaf1:
      kind: srl
      type: ixrd3 # <- hardware type this node will emulate
```

The `type` field defines the hardware variant that this SR Linux node will emulate. The available `type` values are:

| type value | HW platform |
| :--------- | :---------- |
| ixr6       | 7250 IXR-6  |
| ixr10      | 7250 IXR-10 |
| ixrd1      | 7220 IXR-D1 |
| ixrd2      | 7220 IXR-D2 |
| ixrd3      | 7220 IXR-D3 |


!!!tip
    Containerlab-launched nodes are started as `ixrd2` hardware type unless set to a different [type](https://containerlab.srlinux.dev/manual/kinds/srl/#types) in the clab file.

[^1]: SR Linux can also run on the whitebox/3rd party switches.