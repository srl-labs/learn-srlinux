---
date: 2023-01-06
tags:
  - sr linux
  - pygments
authors:
  - rdodin
---

# SR Linux Syntax Highlighting with Pygments

For a very long time, I wanted to make a syntax highlighter for the SR Linux command-line interface mainly because I belong to a cohort of readers who appreciate visual aids in lengthy CLI snippets. Give me a piece of code that is not syntax highlighted, and my reading speed will significantly drop.

And even though the Network OS CLI snippets do not contain code per-se, they have markers (such as a current command, IP addresses, up/down statuses, etc.) that when highlighted, contribute to the clarity of the provided snippet.

So during a lazy first Thursday of 2023 I finally made myself looking into it and created the [`srlinux-pygments`][srl-pygments-repo] - a [Pygments](https://pygments.org/) lexer to highlight SR Linux CLI snippets.

=== "Raw text CLI snippet"
    ```
    --{ * candidate shared default }--[ network-instance black ]--
    A:leaf1# info static-routes
            static-routes {
                route 192.168.18.0/24 {
                    admin-state enable
                    metric 1
                    preference 5
                    next-hop-group static-ipv4-grp
                }
                route 2001:1::192:168:18:0/64 {
                    admin-state enable
                    metric 1
                    preference 6
                    next-hop-group static-ipv6-grp
                }
            }
    ```
=== "With `srl` syntax applied"
    ```srl
    --{ * candidate shared default }--[ network-instance black ]--
    A:leaf1# info static-routes
            static-routes {
                route 192.168.18.0/24 {
                    admin-state enable
                    metric 1
                    preference 5
                    next-hop-group static-ipv4-grp
                }
                route 2001:1::192:168:18:0/64 {
                    admin-state enable
                    metric 1
                    preference 6
                    next-hop-group static-ipv6-grp
                }
            }
    ```

Jump under the cut to know how to create a custom syntax highlighter based on SR Linux CLI example and integrate it with [mkdocs-material][mkdocs-material] doc theme.

<!-- more -->

## Pygments? Lexers?

Whenever you see a nicely highlighted code block on the web, chances are high that syntax highlighting was done using [Pygments][pygments].

!!!info
    Pygments is a generic syntax highlighter suitable for use in code hosting, forums, wikis or other applications that need to prettify source code. Highlights are:

    * a wide range of 548 languages and other text formats is supported
    * special attention is paid to details that increase highlighting quality
    * support for new languages and formats are added easily; most languages use a simple regex-based lexing mechanism
    * a number of output formats is available, among them HTML, RTF, LaTeX and ANSI sequences
    * it is usable as a command-line tool and as a library

Almost all python-based documentation engines exclusively use Pygments for syntax highlighting; [mkdocs-material][mkdocs-material] engine, which powers this learning portal, is no exception.  
When you create a code block in your markdown file and annotate it with some language class, Pygments kicks in and colorizes it.

A [lexer][write-lexer] is a Pygments' component that parses the code block's content and generates _tokens_. Tokens are then rendered by the _formatter_ in one of the supported ways, for example, HTML code.  
This might sound confusing at first, but the key takeaway here is that lexer is a python program that leverages Pygments' API to parse the raw text and extract the tokens that will be highlighted later on. So when you need to create a new syntax highlighting for a custom language, you typically only need to create a new lexer.

Bear with me, it is less scary than it sounds :smiley:.

## What to highlight?

Before jumping to creating our new lexer, let's draft the requirements. What do we want to highlight? There is no public standard for a Network OS CLI syntax, thus, we can choose what tokens we want to highlight.

Consider the following SR Linux CLI snippet that displays static routes configuration stanza:

```
# displaying configured static routes

--{ * candidate shared default }--[ network-instance black ]--
A:leaf1# info static-routes
        static-routes {
            route 192.168.18.0/24 {
                admin-state enable
                metric 1
                preference 5
                next-hop-group static-ipv4-grp
            }
            route 2001:1::192:168:18:0/64 {
                admin-state enable
                metric 1
                preference 6
                next-hop-group static-ipv6-grp
            }
        }
```

In this "wall of text", I think it is suitable to make the following adjustments:

1. Make the 1st line of the prompt less intrusive. It displays auxiliary information about the selected datastore and present context, but it is not the "meat" of the snippet, so it's better to make it less visible.
2. On the 2nd prompt line, we typically have the command - `info static-routes` in our example. This is the crux of the snippet, the key piece of information. Thus it makes sense to put the accent on the command we display.
3. Interface names, IP addresses, string, and number literals are often the key user input in many configuration blocks. It makes sense to highlight these tokens to improve visibility.
4. Keywords like `enable`/`disable`/`up`/`down` are often the most important part of the code blocks, especially if this is a `show` command output. We need to articulate those keywords visually.
5. Authors often augment raw CLI snippets with comments; we need to make those strings render with comments style.

Those styling requirements laid out the base for [srlinux-pygments][srl-pygments-repo] lexer project, and you can see the effect of it at the beginning of this post.

## Writing a custom lexer

Once the requirements are fleshed out, let's create a custom Pygments lexer for SR Linux CLI snippets. Pygments documentation on [writing a lexer][write-lexer] is a good start, but it is not as welcoming as I wanted it to be, so let me fill in the gaps.

### Lexer structure

A lexer is a Python module that leverages Pygments' API to parse the input text and emit tokens which are subject to highlight. Typically, the lexer module contains a single class that subclasses Pygments's `RegexLexer` class:

```python
from pygments.lexer import RegexLexer
from pygments.token import *

class SRLinuxLexer(RegexLexer):
    name = 'SRLinux'
    aliases = ['srl']
    filenames = ['*.srl.cli']

    tokens = {
        'root': [
            (r"^\s*#.*$", Comment), # comments
            (r"\s\".+\"\s", Literal), # strings
        ]
    }
```

With the `name` field, we give a name to the lexer. The `aliases` list defines the aliases our lexers can be found by (as in the fenced code block). And `filenames` field will auto-guess this lexer for files which conform to the provided pattern.

The whole deal of the lexer is within the `tokens` variable, which defines _states_ and state's tuples with regular expressions and corresponding tokens. Let's zoom in.

The `tokens` var defines a single state called `root`, which contains a list of tuples. Each tuple contains at most three elements:

1. regexp expression
2. token to emit for the match
3. next state

!!!question "What are states?"
    I have mentioned [states][pygment-state] a few times by now; they are a powerful concept for complex syntax highlighting rules. Luckily, in our simple case, we don't have to deal with states, thus we have only a single `root` state.
    Consequently, all our tuples have at most two elements.

#### Match tuples

Currently, our lexer has a single state with two tuples containing match rules written to handle Comments and String literals. Let's consider the first tuple that handles comments in our snippets:

```python
(r"^\s*#.*$", Comment)
```

The regexp matches on every string that may start with a space characters, followed by the `#` char and any number of characters after it till the end of the string. The whole match of this regexp will be assigned the `Comment` token.

#### Tokens

Pygments maintains an [extensive collection of Tokens][pygments-tokens] for different cases. When HTML output is used, each token is marked with a distinctive CSS class, which makes it possible to highlight it differently.

Like in the case above, when lexer matches the comment string and HTML output is used, the whole match will be assigned a CSS class of `c` (short for Comment), and documentation themes may create CSS rules to style elements with this particular class according to their theme.

!!!tip
    Read along to see how [mkdocs-material][mkdocs-material] uses those classes to style the elements in the code blocks.

### SR Linux CLI match rules

By now, you probably figured out, that, in a nutshell, a simple lexer is just a bunch of regexps and associated tokens. Let's see which match rules and tokens we chose for SR Linux CLI snippets and for what purpose.

#### Handling prompt

SR Linux prompt consists of two lines. First one holding the current datastore and its state plus the current working context. On the second line, you get the active CPM literal and the hostname. The rest is vacant for the command to type in.

Since prompt appears in the snippet potentially many times (you show multiple commands typed in) it makes sense to make it less intrusive. On the other hand, the command you typed in is what needs to stand out, and thus it is better to be highlighted.

We used [two match tuples][comments-parser] to handle the prompt lines. First one handles the first line and marks it with a Comment token, and second one marks the command string with Name token.

=== "Before"
    ```
    --{ * candidate shared default }--[ network-instance black ]--
    A:leaf1# info static-routes
    ```
=== "After"
    ```srl
    --{ * candidate shared default }--[ network-instance black ]--
    A:leaf1# info static-routes
    ```

!!!tip
    Most parsers you find in [srlinux-pygments][srl-pygments-repo] repo augmented with regexp101.com links to visualise the work of the matching expression.

#### Keywords, positive and negative words

All CLIs have some keywords like `enable`, `enter` or `commit`. Those keywords bear significant value and thus are good candidates for highlighting. In the same spirit, words like `up`, `established` or `down` and `disabled` are important markers that a human desperately searches for during the debugging session.

What unites those three categories is that all of them are simple words which can be easily matched using a list containing those words. This is exactly what Pygements allow us to do using the `#!python word()` function. We keep a list of keywords, positive and negative words in a [`words.py`](https://github.com/srl-labs/srlinux-pygments/blob/main/srlinux_lexer/words.py) file and then [corresponding parser tuples](https://github.com/srl-labs/srlinux-pygments/blob/v0.0.1/srlinux_lexer/parsers.py#L32-L36) leverage those.

=== "Before"
    ```
    enter candidate
    set / interface ethernet-1/49 admin-state enable
    set / interface ethernet-1/50 admin-state disable
    ```
=== "After"
    ```srl
    enter candidate
    set / interface ethernet-1/49 admin-state enable
    set / interface ethernet-1/50 admin-state disable
    ```

#### Interface names and IPv4/6 addresses

Highlighting interface names and IP addresses is equally important. They are the beacons and key elements in Network OS configuration to which many objects bind. Making them distinguishable aids in clarity.

[These tuple parsers](https://github.com/srl-labs/srlinux-pygments/blob/v0.0.1/srlinux_lexer/parsers.py#L38-L67) are responsible for matching these elements.

=== "Before"
    ```
    interface ethernet-1/49 {
        subinterface 0 {
            ipv4 {
                address 192.168.11.1/30 {
                }
            }
        }
    }
    ```
=== "After"
    ```srl
    interface ethernet-1/49 {
        subinterface 0 {
            ipv4 {
                address 192.168.11.1/30 {
                }
            }
        }
    }
    ```

#### Numerals

We also decided to highlight digits (aka numerals) as they often indicate an index, a VLAN ID, or some other significant parameter.

Here is a [parser](https://github.com/srl-labs/srlinux-pygments/blob/v0.0.1/srlinux_lexer/parsers.py#L69-L86) responsible for matching digits in different positions in the text.

=== "Before"
    ```
    --{ + running }--[  ]--
    A:leaf1# show network-instance default protocols bgp summary
    -------------------------------------------------------------
    BGP is enabled and up in network-instance "default"
    Global AS number  : 101
    BGP identifier    : 10.0.0.1
    -------------------------------------------------------------
      Total paths               : 3
      Received routes           : 3
      Received and active routes: None
      Total UP peers            : 1
      Configured peers          : 1, 0 are disabled
      Dynamic peers             : None
    ```
=== "After"
    ```srl
    --{ + running }--[  ]--
    A:leaf1# show network-instance default protocols bgp summary
    -------------------------------------------------------------
    BGP is enabled and up in network-instance "default"
    Global AS number  : 101
    BGP identifier    : 10.0.0.1
    -------------------------------------------------------------
      Total paths               : 3
      Received routes           : 3
      Received and active routes: None
      Total UP peers            : 1
      Configured peers          : 1, 0 are disabled
      Dynamic peers             : None
    ```
=== "With `srlmin`"
    ```srlmin
    --{ + running }--[  ]--
    A:leaf1# show network-instance default protocols bgp summary
    -------------------------------------------------------------
    BGP is enabled and up in network-instance "default"
    Global AS number  : 101
    BGP identifier    : 10.0.0.1
    -------------------------------------------------------------
      Total paths               : 3
      Received routes           : 3
      Received and active routes: None
      Total UP peers            : 1
      Configured peers          : 1, 0 are disabled
      Dynamic peers             : None
    ```

    Highlighting numbers can be _too much_ for some users, for that reason we also created a minified lexer, that has everythin, but numbers highlighted. It can be selected with `srlmin` language identifier.

#### Other

Other parsers in the `parsers.py` file are responsible for handling Route Targets, Comments, and String literals and are simple regexp rules.

### Constructing the lexer

At this stage, we created match tuples contained in the [`parsers.py`][parsers.py] file, but parsers need to be attached to the `token` variable of the lexer class as discussed in the [Lexer structure](#lexer-structure) section.

This is done in the `srlinux.py` file where parsers are imported and added to the `root` state of the token variable:

```python
"""A Pygments lexer for SR Linux configuration snippets."""
import re
from pygments.lexer import RegexLexer
from pygments.token import *
from .parsers import (
    srl_prompt,
    comments,
    strings,
    keywords,
    pos_words,
    neg_words,
    sys_lo_if,
    eth_if,
    ipv4,
    ipv6,
    nums,
    rt,
)

__all__ = ("SRLinuxLexer",)


class SRLinuxLexer(RegexLexer):

    """
    A lexer to highlight SR Linux CLI snippets.
    """

    name = "SR Linux"
    aliases = ["srl"]
    flags = re.MULTILINE | re.IGNORECASE

    tokens = {"root": []}

    tokens["root"].extend(srl_prompt)
    tokens["root"].extend(comments)
    tokens["root"].extend(strings)
    tokens["root"].extend(keywords)
    tokens["root"].extend(pos_words)
    tokens["root"].extend(neg_words)
    tokens["root"].extend(eth_if)
    tokens["root"].extend(sys_lo_if)
    tokens["root"].extend(ipv4)
    tokens["root"].extend(ipv6)
    tokens["root"].extend(nums)
    tokens["root"].extend(rt)
```

!!!note
    The order of adding the parsers is important, as they are processed sequentially.

## Installing a custom lexer

Now that our lexer has its structure formed with parser tuples attached, the question is how to install it so that the pygments package can use it?[^1]

To our luck, pygments uses [setuptools entry_points](https://setuptools.pypa.io/en/latest/userguide/entry_point.html) property that allows plugins to register easily. In the `setup.py` file we [specify](https://github.com/srl-labs/srlinux-pygments/blob/v0.0.1/setup.py#L5-L9) the `entry_points` values registering our lexer classes with pygments.lexers.

Now, to install our custom lexer and make it known to the pygments all we need to do is:

=== "Local or pypi install"
    ```
    pip install setup.py
    ```
    or
    ```
    pip install <pypi package name>
    ```
=== "Install via GitHub (from `branch`)"
    ```
    pip install https://github.com/srl-labs/srlinux-pygments/archive/main.zip
    ```
=== "Install via GitHub (from `tag`)"
    ```
    pip install https://github.com/srl-labs/srlinux-pygments/archive/v0.0.1/main.zip
    ```

## Using the custom syntax highlighter

To use your custom syntax highligter, use the `alias` you provided in the lexer class definition (in our case it was `#!python aliases = ['srl']`) in the fenced code block:

````markdown title="Code block with custom highlighter syntax"
```srl
# displaying configured static routes

--{ * candidate shared default }--[ network-instance black ]--
A:leaf1# info static-routes
        static-routes {
            route 192.168.18.0/24 {
                admin-state enable
                metric 1
                preference 5
                next-hop-group static-ipv4-grp
            }
```
````

## Testing and developing the lexer

When doing the initial development of a lexer, I wanted to have an immediate feedback loop and see the results of the changes I made to parsers. To assist in that, I have created a dockerized test environment that consists of mkdocs-material doc engine which installs the lexer on startup.

With the `make test` command developers should have the mkdocs-material container to start and have lexers installed in editable mode. Now, to start the dev server paste in `mkdocs serve -a 0.0.0.0:8000` command and you should be able to open the web page with the mkdocs-material doc portal that displays various CLI snippets with applied highlighting.

When you made changes to the parsers, simply `Ctrl+C` the live web server and start it again to reload pygments.

## Integrating lexer with MkDocs-Material

Ok, it is all cool, but how do you make mkdocs-material to make use of the custom parser we just created? And how to know which colors it uses for which tokens? All the hard questions.

First, we have to install the custom lexer along with the mkdocs-material. If you use mkdocs-material as a python project, install the lexer as explained before in the same virtual environment which mkdocs-material uses.  
Should you use mkdocs-material container image (you really should), you have to either modify the container image run command and embed the `pip install` step before calling `mkdocs build/serve` or create your own image based on original mkdocs-material image and add this step in the dockerfile.

### Tokens and their colors

Mkdocs-material offers a [single color palette](https://squidfunk.github.io/mkdocs-material/reference/code-blocks/#custom-syntax-theme) for code blocks syntax, and the question is how to understand which color is used for which token? To discover that we have to dig into some source files.

First, we need to know which tokens are associated with which CSS classes (aka short names). You can find the mapping between the Token name and the corresponding CSS classes in the [`token.py`](https://github.com/pygments/pygments/blob/fd0c3e9e0bc6a2a0101b0b16e78bb9594e1cf9fd/pygments/token.py#L123) file of the pygments project.  
For example, the `Comment` token is [associated](https://github.com/pygments/pygments/blob/fd0c3e9e0bc6a2a0101b0b16e78bb9594e1cf9fd/pygments/token.py#L194) with `c` class.

Knowing the CSS class of a particular token let's find which color variable mkdocs-material uses. This information is avilable in the [`_highlight.scss`](https://github.com/squidfunk/mkdocs-material/blob/master/src/templates/assets/stylesheets/main/extensions/pymdownx/_highlight.scss) file of mkdocs-material. For example, there we can find that for a `c` CSS class the `#!css var(--md-code-hl-comment-color)` is [associated](https://github.com/squidfunk/mkdocs-material/blob/699097679313b6e1d8dc508ed9a147bc46ba9df9/src/templates/assets/stylesheets/main/extensions/pymdownx/_highlight.scss#L112).

With this information, you can pick up the Tokens and the corresponding colors to make your syntax highlighting style to match your design ideas.

## Summary

Making a simple custom highlighter for Pygments turned out to be an easy job. The only prerequisite - is familiarity with regular expressions, and Pygments handles the rest.

I am quite happy with the result and plan to fine-tune the parsers based on users' feedback. Likelty, there is a bunch of important keywords we will discover in the CLI snippets worth highlighting.

You can check the [EVPN Layer 2 Tutorial](../../../tutorials/l2evpn/intro.md), where snippets have been fixed to use the `srl` highlighting style.

!!!tip
    Make sure to [subscribe](../../subscribe.md) to receive email/rss notifications when new blog posts are published.

[srl-pygments-repo]: https://github.com/srl-labs/srlinux-pygments
[mkdocs-material]: https://squidfunk.github.io/mkdocs-material/
[pygments]: https://pygments.org/
[write-lexer]: https://pygments.org/docs/lexerdevelopment/
[pygment-state]: https://pygments.org/docs/lexerdevelopment/#changing-states
[pygments-tokens]: https://pygments.org/docs/tokens/
[comments-parser]: https://github.com/srl-labs/srlinux-pygments/blob/v0.0.1/srlinux_lexer/parsers.py#L6-L14
[parsers.py]: https://github.com/srl-labs/srlinux-pygments/blob/v0.0.1/srlinux_lexer/parsers.py

[^1]: Thanks to @facelessuser and his https://github.com/facelessuser/pymdown-lexers project that helped me to get familiar with installation procedures.
