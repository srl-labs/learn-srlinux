Likely the first question that rises after looking at the clab file we deployed in the [first step](intro.md) is "What are those SR Linux _type_ fields?".

```yaml
# part of the quickstart.clab.yml file
  nodes:
    leaf1:
      kind: srl
      type: ixrd2 # <- hardware type this node will emulate
```

The SR Linux software supports seven Nokia hardware platforms[^1]:

* 7250 IXR-6
* 7250 IXR-10
* 7220 IXR-D1
* 7220 IXR-D2
* 7220 IXR-D3
* 7220 IXR-H2
* 7220 IXR-H3

Out of those seven hardware variants, the first five are available for emulation within SR Linux container image.

The `type` field defines the hardware variant that this SR Linux node will emulate. The available `type` values are:

| type value | HW platform |
| :--------- | :---------- |
| ixr6       | 7250 IXR-6  |
| ixr10      | 7250 IXR-10 |
| ixrd1      | 7220 IXR-D1 |
| ixrd2      | 7220 IXR-D2 |
| ixrd3      | 7220 IXR-D3 |


By default, `ixr6` type is used by containerlab, and since in our topology we determined to run IXR-D2 variant on the leaf layer and IXR-D3 as a spine, we specifically set this in the clab file.

[^1]: SR Linux can also run on the whitebox/3rd party switches.