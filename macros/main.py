"""
Mkdocs-macros module
"""


def define_env(env):
    """
    Macroses used in SR Linux documentation
    """

    @env.macro
    def diagram(url, page: int, title: str, zoom: int = 2):
        """
        Diagram macro
        """

        # to allow shorthand syntax for drawio URLs, like:
        # srl-labs/srlinux-getting-started/main/diagrams/topology.drawio
        # we will append the missing prefix to it if it doesn't start with http already
        if not url.startswith("http"):
            url = "https://raw.githubusercontent.com/" + url

        diagram_tmpl = f"""
<figure>
    <div class='mxgraph'
            style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block; box-shadow: 0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1); border-radius: 0.25rem;'
            data-mxgraph='{{"page":{page},"zoom":{zoom},"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"{url}"}}'>
    </div>
    {f"<figcaption>{title}</figcaption>" if title else ""}
</figure>
"""

        return diagram_tmpl

    @env.macro
    def video(url):
        """
        HTML5 video macro
        """

        video_tmpl = f"""
<video style="overflow: hidden; box-shadow: 0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1); border-radius: 0.25rem;" width="100%" controls playsinline>
    <source src="{url}" type="video/mp4">
</video>
"""

        return video_tmpl

    @env.macro
    def youtube(url):
        """
        Youtube video macro
        """

        yt_tmpl = f"""
<div class="iframe-container" >
<iframe style="box-shadow: 0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1); border-radius: 0.25rem;" src="{url}" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
</div>
"""

        return yt_tmpl

    @env.macro
    def image(url: str, width: int = 0, title: str = "", shadow: bool = True):
        """
        Image macro
        :param url: image URL
        :param width: image width in percent
        :param title: image title
        :param shadow: whether to add shadow to the image
        """

        shadow_component = ""
        if shadow:
            shadow_component = ".img-shadow"

        width_component = ""
        if width is not None and width != 0:
            width_component = f"width={width}%"

        return f"""<figure markdown>
  ![image]({url}){{{shadow_component} {width_component} }}
  {f"<figcaption>{title}</figcaption>" if title else ""}
</figure>"""
