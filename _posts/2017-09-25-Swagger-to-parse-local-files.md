---
layout: post
title:  "Swagger to parse local files"
description: "Structure and configuration to provide a locally hosted Swagger API"
date:   2017-09-25 16:09:23
categories: development
tags: [flask, python, docs]
comments: true
---

* TOC
{:toc}

With Swagger, the definition of the API is typically assumed to be hosted remotely. This small guide extends on community-based solutions to offer a minimal solution that parses locally hosted API specifications with Swagger.

<!--more-->

[Swagger](https://swagger.io) offers a suite of tools to perform API-related documentation, such as parsing a specification of an API (following the [OpenAPI Specification (OAS)](https://github.com/OAI/OpenAPI-Specification) format) into a friendly-user website, or generating sources from it.

The libraries I have checked so far expect a URL pointing to a public, remotely hosted resource. When this is not the case and, let's say, you want to keep a local resource (or even allow anyone to change the specification of an API and check the changes), some small changes are required.

### Structure

First create the basic folder structure within the root folder:

```console
mkdir dist
```

Note that the expected file structure at the end of the process is as follows:

```console
$ tree .
.
├── dist
│   ├── favicon-16x16.png
│   ├── favicon-32x32.png
│   ├── spec.js
│   ├── swagger-editor-bundle.js
│   ├── swagger-editor-standalone-preset.js
│   ├── swagger-editor.css
│   ├── swagger-editor.js
│   ├── swagger-ui-bundle.js
│   ├── swagger-ui-standalone-preset.js
│   └── swagger-ui.css
├── index-editor.html
├── index-ui.html
├── server.py
└── swagger.yaml
```

### HTML

Two files will be in use here:
* The *UI*: similar to the [online sample](http://petstore.swagger.io/). It will parse the provided specification at render/runtime
* The *editor*: similar to the [online editor](http://editor.swagger.io/). It presents a left panel to load specifications and parse them on-the-fly

#### UI

Get the [index.html](https://github.com/swagger-api/swagger-ui/blob/master/dist/index.html) file from the *swagger-ui* project and rename it as `index-ui.html`.

```console
wget https://raw.githubusercontent.com/swagger-api/swagger-ui/master/dist/index.html -O index-ui.html
```

Fetch the required javascript and css files from the [dist](https://github.com/swagger-api/swagger-ui/tree/master/dist) folder from the *swagger-ui* project and place these under the `dist` folder:

```console
wget https://raw.githubusercontent.com/swagger-api/swagger-ui/master/dist/swagger-ui-bundle.js
wget https://raw.githubusercontent.com/swagger-api/swagger-ui/master/dist/swagger-ui-standalone-preset.js
wget https://raw.githubusercontent.com/swagger-api/swagger-ui/master/dist/swagger-ui.css
mv *.css *.js dist/
```

#### Editor

Get the [index.html](https://github.com/swagger-api/swagger-editor/blob/master/index.html) file from the *swagger-editor* project and rename it as `index-editor.html`.

```console
wget https://raw.githubusercontent.com/swagger-api/swagger-editor/master/index.html -O index-editor.html
```

Fetch the required javascript and css files from the [dist](https://github.com/swagger-api/swagger-ui/tree/master/dist) folder from the *swagger-ui* project and place these under the `dist` folder:

```console
wget https://raw.githubusercontent.com/swagger-api/swagger-editor/master/dist/swagger-editor-bundle.js
wget https://raw.githubusercontent.com/swagger-api/swagger-editor/master/dist/swagger-editor-standalone-preset.js
wget https://raw.githubusercontent.com/swagger-api/swagger-editor/master/dist/swagger-editor.css
mv *.css *.js dist/
```

### Swagger spec

Swagger may load by default the sample *petstore* API specification -- the same it does the online version. This works well for remotely hosted specification files, but not for the local files. Because of this it is needed to modify the html files in order to load a local resource. The steps here presented follow the solution presented on this [solution from StackOverflow](https://stackoverflow.com/a/38319895/2186237).

To ensure the load of a local specification, download the [api-with-examples.yaml](https://github.com/OAI/OpenAPI-Specification/blob/master/examples/v2.0/yaml/api-with-examples.yaml) file and rename it as `swagger.yaml`.

```console
wget https://raw.githubusercontent.com/OAI/OpenAPI-Specification/master/examples/v2.0/yaml/api-with-examples.yaml -O swagger.yaml
```

This specification file will be later on converted, if needed, to a JSON file and stored a s *spec.js* file in runtime. When rendering the Swagger docs, this can be directly loaded by the html page. Therefore, a minor change in both *index-ui.html* and *index-editor.html* is expected. Ensure that the html file has the following additions:

```html
<div id="swagger-***"></div>
<script src="./dist/swagger-***-bundle.js"> </script>
<script src="./dist/swagger-***-standalone-preset.js"> </script>
<!-- Add this line -->
<script src="./dist/spec.js"> </script>
<script>
window.onload = function() {
  // Build a system
  const editor = Swagger***Bundle({
	spec: spec,
    dom_id: '#swagger-***',
    layout: 'StandaloneLayout',
    presets: [
      Swagger***StandalonePreset,
      ...
    ],
    ...
  })
  window.*** = ***
}
</script>
```

The asterisks denote a placeholder for the values "*editor*" or "*ui*", depending on the specific file.

{% capture note-text %}The <em>index-ui.html</em> file must point to every resource under <em>dist</em> (that is, prepend this path to the <em>src</em> and <em>href</em> for js and css resources).
{% endcapture %}
{% include highlight-warning.html %}

### Server

Once all the css, js, yaml and html files are in place, it is time to develop a minimal server to present these. The following code will expose two endpoints: */editor* and */ui*, each to accommodate a different layout for the swagger documentation -- that is, with and without editor panel. Save it as `server.py` in the root folder.

```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-

from flask import Blueprint
from flask import Flask
from flask import render_template
from werkzeug import serving

import json
import os
import yaml


API_HOST = "0.0.0.0"
API_PORT = 8000

template_folder = os.path.dirname(__file__)
static_folder = os.path.normpath(
        os.path.join(
        os.path.dirname(__file__), "dist"))
app = Flask(__name__,
        static_folder=static_folder,
        template_folder=template_folder)

def generate_swagger_spec_file():
    # Read Swagger file (either in YaML or JSON)
    swagger_spec = open(os.path.normpath("swagger.yaml")).read()
    try:
        swagger_spec = yaml.load(swagger_spec)
    except:
        pass
    swagger_json = json.dumps(swagger_spec, sort_keys=True, indent=2)
    # Save to specific JS file, to be loaded as a JS file in the index.html file
    swagger_json_f = open(os.path.normpath(os.path.join(static_folder, "spec.js")), "w")
    swagger_json_f.write("var spec = {}".format(swagger_json))
    swagger_json_f.close()

@app.route("/editor", methods=["GET"])
def generate_swagger_editor():
    generate_swagger_spec_file()
    return render_template("index-editor.html")

@app.route("/ui", methods=["GET"])
def generate_swagger_docs():
    generate_swagger_spec_file()
    return render_template("index-ui.html")

serving.run_simple(
    API_HOST, API_PORT, app, ssl_context=None)
```

{% capture note-text %}The endpoint to serve the resources is closely related to the path provided to access the static resources.<br/>
That is, if endpoints <em>"/editor"</em> and <em>"/ui"</em> are changed to something like <em>"/docs/editor"</em> and <em>"/docs/ui"</em>, the path to any file rendered via them must be adjusted accordingly.
{% endcapture %}
{% include highlight-note.html %}

### Accessing the docs

The *UI* and *editor* should be now available.

The *UI* can be accessed via http://localhost:8000/ui:
![swagger_ui]

The *editor* is served through http://localhost:8000/editor:
![swagger_editor]

[swagger_ui]: /img/post/2017-09-25-Swagger-to-parse-local-files/swagger_ui.png?style=img-center "Swagger UI"
[swagger_editor]: /img/post/2017-09-25-Swagger-to-parse-local-files/swagger_editor.png?style=img-center "Swagger editor"
