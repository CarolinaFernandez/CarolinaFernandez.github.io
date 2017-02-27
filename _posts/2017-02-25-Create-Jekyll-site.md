---
layout: post
title:  "Create a site with Jekyll"
date:   2017-02-25 22:15:23
categories: development
tags: [jekyll, liquid, github]
---

* TOC
{:toc}

The [Jekyll](https://jekyllrb.com/) site generator is a simple way to create static pages. It runs in Ruby and makes use of markdown-like style and of Liquid-based templates. Jekyll is integrated with GitHub, so different themes and gems can be chosen.

<!--more-->

### Local development

### Install and run

The [installation](https://jekyllrb.com/docs/installation/) process expects a Linux or OSX environment, and some packages such as Ruby and make.

The files can now be built and served locally by a thin server. The [`--incremental`](http://idratherbewriting.com/2015/11/04/jekyll-30-released-incremental-regeneration-rocks/) flag allows to re-build just the content modified. The result of the building process will be available in the shell where these commands are executed.

```shell
jekyll build
jekyll serve --incremental
```

### Set up the structure

Starting a site with Jekyll should start with the following items, in order:
* Definition of `_config.yml` at the root
* Adding the main file `index.html` at the root
* Providing content for the posts under `_posts`, at the root

After those are all set-up, the basic structure for the site is all set-up. From that point you can start filling with specific styles and layouts, use common [includes](https://jekyllrb.com/docs/includes/) files or static pages. An example of a working tree with all the aforementioned would be as follows:

```shell
.
├── _config.yml
├── _includes
│   ├── footer.html
│   ├── header.html
│   └── sidebar.html
├── _layouts
│   ├── default.html
│   ├── page.html
│   └── post.html
├── _pages
│   ├── 404.html
│   └── feed.xml
├── _posts
│   └── post-example.md
├── section1
│   ├── subsection1
│   │   └── index.html
│   └── subsection2
│       └── index.html
├── css
│   └── default.css
├── img
│   └── background.png
├── index.html
└── robots.txt
```

Some of these sections are part of the **default structure**:
* `_includes`: where chunks of code can be imported into bigger templates
* `_layouts`: gathering the layout or theme files per view
* `_posts`: blog posts shall be kept here, where these are directly generated into html files

Some others can be defined by the user, such as `_pages` (to include any section or page), `$section` (root-level section, acting as a category) or multiple folders to keep stylesheets, images or scripts.

#### The _config.yml file

The configuration file can be used as a central registry for variables to be used across your pages.

```yaml
# Setup
title:        "Title of your site"
description:  "Mid-sized description of your site (to be used e.g. for feed or meta description)"
tagline:      "Short-sized description of your site (to be used e.g. within the site"
url:          /url/to/github/pages/site

# About/contact
author:
  name:       "Your name"
  url:        /url/to/personal/site
  github:     "Your GitHub ID"

# Gems
gems:
  - jekyll-paginate

# Include extra folders
include:
    - non_default_section_to_include_from_root

# Markdown parsing
markdown: kramdown
```

The default values added within Jekyll are [defined here](https://jekyllrb.com/docs/configuration/#default-configuration). Many other configuration values are available for purposes such as defining the [permalink format](https://jekyllrb.com/docs/permalinks/), [customise pagination](https://jekyllrb.com/docs/pagination/) for posts, [adding plug-ins](https://jekyllrb.com/docs/plugins/) or [applying themes](https://jekyllrb.com/docs/themes/).

### The main file

The front page is a normal `index.html` or `index.md` file, placed at the root of your repository. A layout can be defined, based on the different view to be provided; such as `page` for static pages or `post` for blog entries. These are located under the `_layouts` folder and are extensibly customizable by the user, though. Adding such tag in the header of the post's Markdown file will result in Jekyll applying the post's layout to it.

In this case, the `default` layout will be used -- as it contains specific code, relevant only to the index.


```markdown
---
layout: default
title: {{ site.name }}
---
```

The content comes right after such header in every page using the Liquid templating system.

### The posts

Now it's time for the content itself. The posts can be defined in Markdown language or directly prepared using HTML. In the former case, these will be converted by Jekyll into the end HTML files. The post files must be placed under the `_posts` folder. When building and generating the HTML content, these posts will be placed into appropriate folders, depending on the publish date or other data such as categories. [Here](https://jekyllrb.com/docs/posts/) you can find guidelines and details.

#### The name

The files shall be named in the format `year-month-day-title.md`. Note that hyphens (-) are allowed, but others as underscore (_) will preclude the building and generation of html files.

#### The header

Similar to the main file's view, the post's view can use a specific layout as well. More useful values can be assigned to define the title, publish date, or the categories and labels to further organise the content.

```markdown
---
layout: post
title:  "Title of your post"
date:   2010-01-01 00:00:00
categories: category1
tags: [tag1, tagn]
---
```

### Enhance it

The basics are all working now. Yet there are many other features around. Just to name a few:

#### Pretty URLs

If you would like to avoid `.html` in your URLs (whether it is part of the post or a section itself), do have the following in mind:

##### Section URLs

Instead of defining a `sectionname.html` file, do create a folder and an index file such as `sectionname/index.html`. You will just need to point to `sectionname/` (<stress>note the ending slash!</stress>)

##### Post URLs

In this case, you need to remove the HTML termination from the post files for every link that points to the content. This is a post-processing done in the URL of the post in order to work as a pretty URL (remember to remove spaces between the curly braces):

```ruby
{ { post.url | remove: '.html' | prepend: site.baseurl } }
```

#### Excerpts

When listing the available posts in a single page, or in an RSS feed, you can just provide the excerpt of the post (remember to remove spaces between the curly braces):

```ruby
{ { post.excerpt } }
```

Finer control is allowed, as the `excerpt_separator` key can be defined in `_config.yml` to define a specific value that identifies the end of the excerpt:

```yaml
excerpt_separator: <!--more-->
```

#### Table of contents

These are quite useful for lengthy posts. Adding the following right after the post's header will do:

```yaml
* TOC or any other text can be added (will not be shown)
{:toc}
```

#### RSS feed

Original source from [Jekyll tips](http://jekyll.tips/jekyll-casts/rss-feed/). This is a simple iterator on the available posts that also provides details on the site as acquired from the configuration file. The code will largely resemble this (remember to remove spaces between the curly braces or %s):

```xml
---
layout: null
---

<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>{ { site.title } }</title>
    <description>{ { site.description } }</description>
    <link>{ { site.url } }</link>
    { % for post in site.posts % }
      { % unless post.draft % }
        <item>
          <title>{ { post.title | xml_escape } }</title>
          <description>{ { post.excerpt | xml_escape } } (Read more...)</description>
          <pubDate>{ { post.date | date_to_xmlschema } }</pubDate>
          <link>{ { post.url | prepend: site.url } }</link>
          <guid isPermaLink="true">{ { post.url | remove: '.html' | prepend: site.baseurl } }</guid>
        </item>
      { % endunless % }
    { % endfor % }
  </channel>
</rss>
```

### Includes and other sections

Note that, if you want to reuse your code to the maximum, you may want to place partial HTML files under the `_includes` folder. You can then just use the Ruby's `include` directive as follows (remember to remove spaces between the curly traces):

```ruby
{ % include partial-html-file.html % }
```

Other sections can be added to work in the same manner as the default ones (`_includes`, `_posts`, etc). To do that, add one section per line in `_config.yml`:

```yaml
include:
    - sectionname
```

### Themes

In GitHub you have the possibility of extending from a list of [available themes](https://help.github.com/articles/adding-a-jekyll-theme-to-your-github-pages-site/) that you can define in your `_config.yml` file. _Be careful, however, as the theme you pick i) will work only in remote -- if you want to work you will need to download the specific theme into your root's folder, and ii) the remote [theme customisation](https://help.github.com/articles/customizing-css-and-html-in-your-jekyll-theme/) can be tricky, as you will be overriding the default theme by extending HTML and CSS specific files into pre-defined folders in your repository.

## Upload the content

You can now upload the content of your site to your GitHub pages repository and these will be online few seconds after you push the code.