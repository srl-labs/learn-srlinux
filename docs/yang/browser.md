---
comments: true
---

# SR Linux YANG Browser

YANG data models are the map one should use when looking for their way to configure or retrieve any data on SR Linux system. A central role that is given to [YANG in SR Linux](index.md) demands a convenient interface to **browse**, **search** through, and **process** these data models.

To answer these demands, we created a web portal - [**yang.srlinux.dev**][yang-portal] - it offers:
[yang-portal]: https://yang.srlinux.dev

* Fast [Path Browser](#path-browser) to effectively search through thousands of available YANG paths
* Beautiful [Tree Browser](#tree-browser) to navigate the tree representation of the entire YANG data model of SR Linux
* Source `.yang` files neatly stored in [`nokia/srlinux-yang-models`][yang-models-gh] repository for programmatic access and code generation

<figure markdown>
  ![portal](https://gitlab.com/rdodin/pics/-/wikis/uploads/2c9de4140da83b0b9021b7407b4a39f1/yang-browser.webp)
</figure>

The web portal's front page aggregates links to individual releases of YANG models. Select the needed version to open the web view of the YANG tools we offer.

<figure markdown>
  ![portal](https://gitlab.com/rdodin/pics/-/wikis/uploads/47a4fba8dbd59573c3857ef8e6f6e862/yang-browser-2.webp)
</figure>

The main stage of the YANG Browser view is dedicated to the Path Browser :material-numeric-1-circle:, as it is the most efficient way to search through the model. Additional tools are located in the upper right corner :material-numeric-2-circle:. Let's cover them one by one.

## Path Browser

As was discussed before, SR Linux is a fully modeled system with its configuration and state data entirely covered with YANG models. Consequently, to access any data for configuration or state, one needs to follow the YANG model. Effectively searching for those YANG-based access paths is key to rapid development and operations. For example, how to tell which one to use to get ipv4 statistics of an interface?

With Path Browser, it is possible to search through the entire SR Linux YANG model and extract the paths to the leaves of interest. The Path Browser area is composed of three main elements:

* search input for entering the query :material-numeric-1-circle:
* Config/State selector :material-numeric-2-circle:
* table with results for a given search input :material-numeric-3-circle:

<figure markdown>
  ![portal](https://gitlab.com/rdodin/pics/-/wikis/uploads/204b53c62c1c6d0dc336f79bc37a9691/image.png)
  <figcaption>Path Browser elements</figcaption>
</figure>

A user types in a search query, and the result is rendered immediately in the table with the matched words highlighted. The Config/State selector allows users to select if they want the table to show config, state, or all leaves. The state leaf is a leaf that has `config false` statement[^2].

### Path structure

The table contains the flattened XPATH-like paths[^3] for every leaf of a model sorted alphabetically.

* Each path is denoted with a State attribute in the first column of a table. Leaves, which represent the state data, will have the `true` value in the first column[^2].
* List elements are represented in the paths as `list-element[key-name=*]` - a format suitable for gNMI subscriptions.
* Each leaf is provided with the type information.

### Search capabilities

Snappy search features of the Path Browser make it a joy to use when exploring the model or looking for a specific leaf of interest.

Let's imagine we need to solve the simple task of subscribing to interface traffic statistics. How would we know which gNMI path corresponds to the traffic statistics counters?  
Should we try reading source YANG files? But it is challenging as models have lots of imports and quite some augmentations. A few moments and - you're lost.  
What about the tree representation of a model generated with [`pyang`][pyang_gh]? Searching through something like pyang's tree output is impractical since searching the tree representation can't include more than one search parameter. The search becomes a burden on operators' eyes.

Path Browser to the rescue. Its ability to return search requests instantaneously makes interrogating the model a walk in the park. The animation below demos a leaf-searching exercise where a user searches for a state leaf responsible for traffic statistics.  

First, a user tries a logical search query `interface byte`, which yields some results, but it is easy to spot that they are not related to the task at hand. Thanks to the embedded highlighting capabilities, the search inputs are detectable in the resulting paths.

Next, they try to use `interface octets` search query hoping that it will yield the right results, and so it does!

<video src="https://gitlab.com/rdodin/pics/-/wikis/uploads/dca721dfcf4816bb326b6b2ca7c3575a/2021-11-14_22-02-24.mp4" controls="true" width="100%"></video>

!!!tip
    Every table row denotes a leaf, and when a user hovers a mouse over a row, the popup appears with a description of the leaf.

## Tree Browser

The Path Browser is great to search through the entire model, but because it works on flattened paths, it hides the "tree" view of the model. Sometimes the tree representation is the best side to look at the models with a naked eye, as the hierarchy becomes very clear.

To not strip our users of the beloved tree view mode, we enhanced the `pyang -f jstree` output and named this view Tree Browser.

<figure markdown>
  ![treebrowser](https://gitlab.com/rdodin/pics/-/wikis/uploads/86a030aac68361f627b5e984ad6380a8/CleanShot_2021-11-12_at_20.46.08.png)
  <figcaption>Access Tree Browser</figcaption>
</figure>

The tree view of the model offers a step-by-step exploration of the SR Linux model going from the top-level modules all the way down to the leaves. The tree view displays the node's type (leaf/container/etc) as well as the leaf type and the read-only status of a leaf.

<figure markdown>
  ![treebrowser](https://gitlab.com/rdodin/pics/-/wikis/uploads/01255040bfbaa67ae162b0ba11ab5b33/CleanShot_2021-11-12_at_20.49.00.png)
  <figcaption>Tree Browser view</figcaption>
</figure>

!!!tip
    Every element of a tree has a description that becomes visible if you hover over the element with a mouse.
    ![pic](https://gitlab.com/rdodin/pics/-/wikis/uploads/d63d48694423b4103fdc187bd4b49663/CleanShot_2021-11-12_at_20.54.06.png){width=640}

## Tree and Paths

If you feel like everything in the world better be in ASCII, then Tree and Paths menu elements will satisfy the urge. These are the ASCII tree of the SR Linux model[^1] and the text flattened paths that are used in the Path Browser.

<figure markdown>
  ![text](https://gitlab.com/rdodin/pics/-/wikis/uploads/49d0743454d4e7e787195bb1ffab0e0d/CleanShot_2021-11-12_at_21.01.55.png)
  <figcaption>Text version of tree and paths</figcaption>
</figure>

The textual paths can be, for example, fetched with curl and users can `sed` themselves out doing comprehensive searches or path manipulations.

[yang-models-gh]: https://github.com/nokia/srlinux-yang-models
[pyang_gh]: https://github.com/mbj4668/pyang

[^1]: extracted with `pyang -f tree`
[^2]: refer to https://datatracker.ietf.org/doc/html/rfc6020#section-4.2.3
[^3]: paths are generated from the YANG model with [gnmic](https://gnmic.openconfig.net/cmd/path/)
