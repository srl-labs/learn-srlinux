---
date: 2022-10-26
tags:
  - markdown
authors:
  - rdodin
---

# SR Linux Blog Launch

Openness, extensibility, innovation and community focus make a large part of the Nokia SR Linux core. Mix it up with our engineering background and you get a resource where we share technical content in the *engineers-to-engineers* fashion.

Today we would like to take it one step further and augment the **learn.srlinux.dev** portal with a community blog section where Nokia engineers and our community members can post content relevant to modern network technologies.

This blog post explains how to contribute a blog article to our portal and what visual candies you can use to make your post look awesome.

<!-- more -->

/// admonition | What should I write about? Or should I even start writing?
    type: question
Likely the hardest thing in writing is to start. You may have dozens of doubts preventing you start writing.

*Is this interesting to anyone? Isn't it too obvious? Is it too short/long?*

The best advice here might be just to start writing and reiterate as you go. Nothing is perfect, and we welcome all to embrace the joy of writing, which helps to structure your own thoughts and get a firmer grip on the topic.

SR Linux appreciates modern network architectures, network automation/orchestration and programmability. Anything that falls under and in-between these domains will make a great blog post.
///

## Creating a blog post

Did you decide to contribute a blog post? That's great. Here is what you need to do.

1. Create a file under `./docs/blog/posts/<year>/<your-filename>.md`. A `<year>` is in the `YYYY` format and stands for the year the post was authored.
    The filename you choose for your post is completely up to you and doesn't affect a URL or title of the blog post.
2. Write :smile: Use the classic markdown syntax and optionally apply our [advanced styling](#styling) for visual dominance.
3. Add a [date][date] to the post metadata.
4. Add yourself as a new [author](#authors) if this is your first contribution.
4. Create a new git branch and commit your post.
5. Check how your article looks using the live web server started with the `make serve-insiders` target[^1].
6. If all looks great, raise a PR with your work so we can review and merge it.
7. Profit!

## Authors

We want to give credit to the authors. To make yourself known to the community, please add an entry with your information to the [`.authors.yml`][authors-file] file that lists authors. Once added, you can add yourself to the frontmatter of the blog post:

```yaml
---
authors:
  - rdodin #(1)!
---
```

1. `rdodin` is a key used in the `.authors.yml` file for a particular authors. Multiple authors can be added to the list of authors

## Styling

This portal uses the famous [mkdocs-material](https://squidfunk.github.io/mkdocs-material/) documentation theme. This theme packs a lot of UX improvements on top of classic markdown syntax. Knowing how to use those additional elements can make your post look awesome both from visual and user experience angles.

We would like to highlight a few UI elements we use all the time and hope you'll also like them.

/// admonition
    type: tip
Check the [mkdocs-material reference](https://squidfunk.github.io/mkdocs-material/reference/) for a deep dive in the ocean of options and elements mkdocs-material theme provides.
///

### Tabs

Tabs help to visually organize the content and improve readability an awful lot.

```` title="Content tabs with code blocks"
/// tab | C

``` c
#include <stdio.h>

int main(void) {
    printf("Hello world!\n");
    return 0;
}
```

///
/// tab | C++

``` c++
#include <iostream>

int main(void) {
    std::cout << "Hello world!" << std::endl;
    return 0;
}
```

///

````

<div class="result" markdown>

/// tab | C

``` c
#include <stdio.h>

int main(void) {
    printf("Hello world!\n");
    return 0;
}
```

///
/// tab | C++

``` c++
#include <iostream>

int main(void) {
    std::cout << "Hello world!" << std::endl;
    return 0;
}
```

///
</div>

### Code

Nowadays, code is everywhere. With a few styling aids you can make your code blocks look shart and expressive.

A regular code block with a syntax highlighting uses code fences style:

```` markdown title="Code block"
```py
import tensorflow as tf
```

````

<div class="result" markdown>

```py
import tensorflow as tf
```

</div>

#### Title

To add a title to a code block, use the `title` attribute:

````markdown title="Code block with title"
```py title="bubble_sort.py"
def bubble_sort(items):
    for i in range(len(items)):
        for j in range(len(items) - 1 - i):
            if items[j] > items[j + 1]:
                items[j], items[j + 1] = items[j + 1], items[j]
```
````

<div class="result" markdown>

```py title="bubble_sort.py"
def bubble_sort(items):
    for i in range(len(items)):
        for j in range(len(items) - 1 - i):
            if items[j] > items[j + 1]:
                items[j], items[j + 1] = items[j + 1], items[j]
```

</div>

#### Line numbers

Line numbers can be added to a code block by using the `linenums="<start>"`
option directly after the shortcode, whereas `<start>` represents the starting
line number. A code block can start from a line number other than `1`, which
allows to split large code blocks for readability:

````markdown title="Code block with line numbers"
```py linenums="1"
def bubble_sort(items):
    for i in range(len(items)):
        for j in range(len(items) - 1 - i):
            if items[j] > items[j + 1]:
                items[j], items[j + 1] = items[j + 1], items[j]
```
````

<div class="result" markdown>

```py linenums="1"
def bubble_sort(items):
    for i in range(len(items)):
        for j in range(len(items) - 1 - i):
            if items[j] > items[j + 1]:
                items[j], items[j + 1] = items[j + 1], items[j]
```

</div>

#### Highlighting specific lines

Specific lines can be highlighted by passing the line numbers to the `hl_lines`
argument placed right after the language shortcode. Note that line counts start
at `1`, regardless of the starting line number specified:

````markdown title="Code block with highlighted lines"
```py hl_lines="2 3"
def bubble_sort(items):
    for i in range(len(items)):
        for j in range(len(items) - 1 - i):
            if items[j] > items[j + 1]:
                items[j], items[j + 1] = items[j + 1], items[j]
```
````

<div class="result" markdown>

```py linenums="1" hl_lines="2 3"
def bubble_sort(items):
    for i in range(len(items)):
        for j in range(len(items) - 1 - i):
            if items[j] > items[j + 1]:
                items[j], items[j + 1] = items[j + 1], items[j]
```

</div>

#### Annotations

Code annotations can be placed anywhere in a code block where a comment for the
language of the block can be placed, e.g. for JavaScript in `#!js // ...` and
`#!js /* ... */`, for YAML in `#!yaml # ...`, etc.:

````markdown title="Code block with annotation"
```yaml
theme:
  features:
    - content.code.annotate # (1)!
```

1.  :man_raising_hand: I'm a code annotation! I can contain `code`, __formatted
    text__, images, ... basically anything that can be written in Markdown.
````

<div class="result" markdown>

``` yaml
theme:
  features:
    - content.code.annotate # (1)!
```

1. :man_raising_hand: I'm a code annotation! I can contain `code`, **formatted
    text**, images, ... basically anything that can be written in Markdown.

</div>

### Admonitions

[Admonitions](https://squidfunk.github.io/mkdocs-material/reference/admonitions/) is a great way to emphasize a piece of information. Here is a list of admonitions you may use most often:

//// tab | Note

```markdown
/// note

This is a note
///
```

<div class="result" markdown>

/// note

This is a note
///
</div>
////
//// tab | Warning

```markdown
/// warning

This is a warning
///
```

<div class="result" markdown>

/// warning

This is a warning
///
</div>
////
//// tab | Tip

```markdown
/// tip

This is a tip
///
```

<div class="result" markdown>

/// tip

This is a tip
///
</div>
////

#### Admonition's title

Often it is desired to name the admonition block to provide some context to the reader. To achieve this, add a title of the admonition to the block type, like this:

```markdown
/// note | This note now has a `title`
This is a note with a title
///
```

<div class="result" markdown>

/// note | This note now has a `title`
This is a note with a title
///
</div>

#### Collapsible admonitions

A perfect way to provide large amounts of auxiliary information is to use a collapsed admonition that will only be displayed when the user clicks on the title.  
To make an admonition collapsed, change the block type to `details` and add the `type` of the admonition you want to use.

For example, to make a collapsed Note, use the following code:

```markdown
/// details
    type: note

This is a collapsed note
///
```

<div class="result" markdown>

/// details | This collapsed note opens on click
    type: note

This is a collapsed note
///
</div>

### Images

To add an image to your post, use the following shortcode:

```markdown
-{{% raw %}}-
-{{image(url='https://gitlab.com/rdodin/pics/-/wikis/uploads/23ce60488a6e1b9b2faf082b2c7be77b/image.png')}}-
-{{% endraw %}}-
```

<div class="result" markdown>

-{{image(url='https://gitlab.com/rdodin/pics/-/wikis/uploads/23ce60488a6e1b9b2faf082b2c7be77b/image.png')}}-
</div>

By default, the image will be displayed in its original size and with a shadow around it.

To control the image width, use the `width` parameter of the short code that sets the width in percentage of the available page width:

```markdown
-{{% raw %}}-
-{{image(url='https://gitlab.com/rdodin/pics/-/wikis/uploads/23ce60488a6e1b9b2faf082b2c7be77b/image.png')}}-
-{{% endraw %}}-
```

<div class="result" markdown>

-{{image(url='https://gitlab.com/rdodin/pics/-/wikis/uploads/23ce60488a6e1b9b2faf082b2c7be77b/image.png', width=30)}}-
</div>

### Diagrams

The drawio/diagrams.net diagramming tool is a great way to create diagrams. Diagrams are better than images in every way. If you invest in creating diagrams instead of generating images, you will be able to version control, and easily edit them as your project evolves.

To embed a diagram, use the following shortcode and add a script element to your page at the bottom:

```markdown
-{{% raw %}}-
-{{ diagram(url='srl-labs/srlinux-getting-started/main/diagrams/get-started.drawio', title='Default SR Linux prompt', page=0) }}-

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
-{{% endraw %}}-
```

<div class="result">

-{{ diagram(url='srl-labs/srlinux-getting-started/main/diagrams/get-started.drawio', title='Default SR Linux prompt', page=0) }}-
</div>

- The `page` parameter (0-indexed) selects which page in the drawio file to display.
- The `zoom` parameter (integer) sets x-times zoom factor. If your diagran renders too small with the default zoom factor, set it to a higher value.

### Icons

Our doc theme includes a [gazillion of icons](https://squidfunk.github.io/mkdocs-material/reference/icons-emojis/) and emojis which are super easy to use. Use the [search tool](https://squidfunk.github.io/mkdocs-material/reference/icons-emojis/#search) to find the icon code-block and paste it in your post.

``` title="Emoji"
:smile: 
```

<div class="result" markdown>

:smile:

</div>

### Footnotes

Footnotes are a great way to add supplemental or additional information to a
specific word, phrase or sentence without interrupting the flow of a document.
Material for MkDocs provides the ability to define, reference and render
footnotes.

A footnote reference must be enclosed in square brackets and must start with a
caret `^`, directly followed by an arbitrary identifier, which is similar to
the standard Markdown link syntax.

``` title="Text with footnote references"
Lorem ipsum[^1] dolor sit amet, consectetur adipiscing elit.[^2]
```

<div class="result" markdown>

Lorem ipsum[^1] dolor sit amet, consectetur adipiscing elit.[^2]

</div>

The footnote content must be declared with the same identifier as the reference.
It can be inserted at an arbitrary position in the document and is always
rendered at the bottom of the page. Furthermore, a backlink to the footnote
reference is automatically added.

#### on a single line

Short footnotes can be written on the same line:

``` title="Footnote"
[^1]: Lorem ipsum dolor sit amet, consectetur adipiscing elit.
```

<div class="result" markdown>

[:octicons-arrow-down-24: Jump to footnote](#fn:1)

</div>

  [^1]: Lorem ipsum dolor sit amet, consectetur adipiscing elit.

#### on multiple lines

Paragraphs can be written on the next line and must be indented by four spaces:

``` title="Footnote"
[^2]:
    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla et euismod
    nulla. Curabitur feugiat, tortor non consequat finibus, justo purus auctor
    massa, nec semper lorem quam in massa.
```

<div class="result" markdown>

[:octicons-arrow-down-24: Jump to footnote](#fn:2)

</div>

## Subscribing

Get notified when a new post is published using one of the [subscription options](../../subscribe.md) offered.

[^1]: Our community members who don't have access to the mkdocs-material-insiders version will have to skip this step until the blog feature becomes available in the community version of the mkdocs-material project.

[^2]: Example footnote

[authors-file]: https://github.com/srl-labs/learn-srlinux/blob/main/docs/blog/.authors.yml
[date]: https://github.com/srl-labs/learn-srlinux/blob/main/docs/blog/posts/2022/blog-launch.md?plain=1#L2

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
