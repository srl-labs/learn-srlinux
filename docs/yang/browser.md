# SR Linux YANG Browser
YANG data models is the map one should use when looking for their way to configure or retrieve any data on SR Linux system. A central role that is given to [YANG in SR Linux](yang.md) demands a convenient interface to **browse**, **search** through, and **process** these data models.

To answer these demands, we created a web portal - [**yang.srlinux.dev**][yang-portal] - it offers:
[yang-portal]: https://yang.srlinux.dev

* Fast [Path Browser](#path-browser) to effectively search through thousands of available YANG paths
* Beautiful [Tree Browser](#tree-browser) to navigate the tree representation of the entire YANG data model of SR Linux
* Source `.yang` files neatly stored in [`nokia/srlinux-yang-models`][yang-models-gh] repository for programmatic access and code generation

<figure markdown>
  ![portal](https://gitlab.com/rdodin/pics/-/wikis/uploads/fc5cedd25562209eb8926fe930adefd0/CleanShot_2021-11-12_at_17.41.30.png)
</figure>

The web portal's front page aggregates links to individual releases of YANG models. Select the needed version to open the web view of the YANG tools we offer.

<figure markdown>
  ![portal](https://gitlab.com/rdodin/pics/-/wikis/uploads/3fa667148b246586c1676ff7facb16f2/CleanShot_2021-11-12_at_17.04.07.png)
</figure>

The main stage of the YANG Browser view is dedicated to the Path Browser, as it is the most efficient way to search through the model. Additional tools are located in the upper right corner. Let's cover them one by one.

## Path Browser
As was discussed before, SR Linux is a fully modeled system with its configuration and state data entirely covered with YANG models. Consequently, to access any data for configuration or state, one needs to follow the YANG model. Effectively searching for those YANG-based access paths is key to rapid development and operations. For example, how to tell which path to use to get ipv4 statistics of an interface?

With Path Browser, it is possible to search through the entire SR Linux YANG model and extract the paths to the leaves of interest. The Path Browser area is composed of two main elements

* search input for entering the query
* table with results for a given search input

<figure markdown>
  ![portal](https://gitlab.com/rdodin/pics/-/wikis/uploads/163dc6cfd5aee198be3cbe3d53039c77/CleanShot_2021-11-12_at_19.32.00.png)
  <figcaption>Path Browser elements</figcaption>
</figure>

### Path structure
The table contains the flattened XPATH-like paths for every leaf of a model sorted alphabetically.

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


<video controls>
  <source src="https://gitlab.com/rdodin/pics/-/wikis/uploads/05002e53f987009ac838c790814bf51d/CleanShot_2021-11-12_at_20.31.57.mp4" type="video/mp4"></source>
</video>

!!!tip
    Every table row denotes a leaf, and when a user hovers a mouse over a certain row, the popup appears with a description of the leaf.

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