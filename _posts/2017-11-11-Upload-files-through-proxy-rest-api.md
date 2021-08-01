---
layout: post
title:  "Upload files through intermediate REST API"
description: "Snippet to introduce an intermediate REST API and forward files to another REST API"
date:   2017-11-11 21:32:04
categories: development
tags: [flask, python, rest]
comments: true
---

* TOC
{:toc}

Say you have a method that uploads a file via POST (<code>-F</code>) to a specific endpoint in a REST API (here, using Flask). Now, you want to add some logic to this process before POSTing the file, but without modifying the original API. So you create an intermediate REST API. How to allow POSTING the file through this intermediate API?

<!--more-->

The intermediate API to be developed will be called "*rest1*", while the original API accepting the POST of a file will be called "*rest2*".
The file to be POSTed will be a generic, binary file. Let us imagine that "*rest1*" will perform validation procedures on such file, before sending it towards "*rest2*" API.
Finally, both interfaces will run in localhost (could be located anywhere as long as each point in the chain has connection to each other); where the server for the 1st interface runs in port 8000, and the server for the 2nd runs in port 8001.

```
    client             rest1 (intermediate)          rest2 (original)
   ------------------------------------------------------------------

    port=C1                  port=8000
        |                       |
        +-----------------------+

                            port=I1                       port=8001
                                |                               |
                                +-------------------------------+
```

### Intermediate API

The intermediate or proxy API incorporates the new logic for validating the POSTed file. The endpoint at this interface can be defined in several ways, as best fit, for instance accepting the POSTed file:

* As a value in a form, acting as a *simple proxy* (example in cURL: <code>-F "somefile=@/path/to/file"</code>)
* As a dictionary value, with *different kind of paths* (example in cURL: <code>-H "Content-Type: application/json" -X POST -d '{"somefile": "/path/to/file"}'</code>)


#### Simple proxy

The first example acts as a simple proxy, sending the binary file received in "*rest1*" towards "*rest2*" just as it was received. Note that this file must be present locally from where "*rest1*" is running (e.g. cURL [does not allow remote paths after the "@"](https://stackoverflow.com/questions/22736756/how-can-i-use-curls-syntax-with-a-remote-url)).

{% include codeblock-header.html %}
```python
from flask import request
from werkzeug.datastructures import ImmutableMultiDict
import requests

@app.route("/upload", methods=["POST"])
def upload():
    data = request.files
    bin_file = data.get("somefile")
    data_file = ImmutableMultiDict([("somefile", bin_file)])
    resp = requests.post("://url/to/rest2:8001/upload",
            files=data_file,
            verify=False)
    return resp.content
```

#### Local and remote

The second example would either read a local or a remote file, construct an object with a specific data structure ([FileStorage, from werkzeug library](http://werkzeug.pocoo.org/docs/0.12/datastructures/#werkzeug.datastructures.FileStorage)) and send it towards the "*rest2*" API.

{% include codeblock-header.html %}
```python
from flask import request
from mimetypes import MimeTypes
from werkzeug.datastructures import FileStorage
from werkzeug.datastructures import ImmutableMultiDict
import os
import requests
import shutil

@app.route("/upload", methods=["POST"])
def upload():
    file_path = request.json.get("somefile")
    remove_after = False
    if not os.path.isfile(file_path):
        remove_after = True
        file_path = fetch_content(file_path)
    fp = open(file_path, "rb")
    # Signature: FileStorage(stream=None, filename=None, name=None, content_type=None, content_length=None, headers=None)
    filename = os.path.basename(file_path)
    mime = MimeTypes()
    content_type = mime.guess_type(file_path)
    bin_file = FileStorage(fp, filename, "somefile", content_type)
    data_file = ImmutableMultiDict([("somefile", bin_file)])
    resp = requests.post("://url/to/rest2:8001/upload",
            files=data_file,
            verify=False)
    fp.close()
    if remove_after:
        file_dir = os.path.dirname(file_path)
        shutil.rmtree(file_dir)
    return resp.content
```

#### Altogether

{% include codeblock-header.html %}
```python
from flask import Flask
from flask import request
from mimetypes import MimeTypes
from tempfile import mkdtemp
from werkzeug import serving
from werkzeug.datastructures import FileStorage
from werkzeug.datastructures import ImmutableMultiDict
import os
import requests
import shutil
import ssl

app = Flask(__name__)
rest2_ep = "https://127.0.0.1:8001/upload"

def fetch_content(url):
    tmp_folder = mkdtemp()
    tmp_file = url.split("/")[-1]
    tmp_path = os.path.join(tmp_folder, tmp_file)
    try:
        import urllib
        data = urllib.urlretrieve(url, tmp_path)
    except:
        import urllib.request
        data = urllib.request.urlopen(url).read()
        f = open(tmp_path, "wb")
        f.write(data)
        f.close()
    return tmp_path

def post_content(bin_file):
    data_file = ImmutableMultiDict([("somefile", bin_file)])
    resp = requests.post(rest2_ep,
            files=data_file,
            verify=False)
    return resp.content

@app.route("/upload1", methods=["POST"])
def upload():
    data = request.files
    bin_file = data.get("somefile")
    return post_content(bin_file)

@app.route("/upload2", methods=["POST"])
def upload2():
    file_path = request.json.get("somefile")
    remove_after = False
    if not os.path.isfile(file_path):
        remove_after = True
        file_path = fetch_content(file_path)
    fp = open(file_path, "rb")
    # Signature: FileStorage(stream=None, filename=None, name=None, content_type=None, content_length=None, headers=None)
    filename = os.path.basename(file_path)
    mime = MimeTypes()
    content_type = mime.guess_type(file_path)
    bin_file = FileStorage(fp, filename, "somefile", content_type)
    resp_content = post_content(bin_file)
    fp.close()
    if remove_after:
        file_dir = os.path.dirname(file_path)
        shutil.rmtree(file_dir)
    return resp_content

context = "adhoc"
serving.run_simple("0.0.0.0", 8000, app, ssl_context=context)
```

### Original API

For the sake of completeness or even testing purposes, the code of the original ("*rest2*") API is here provided; although you will be most probably restricted by its original implementation.

{% include codeblock-header.html %}
```python
from flask import Flask
from flask import request
from tempfile import mkdtemp
from werkzeug import serving
import os
import requests
import ssl

app = Flask(__name__)

@app.route("/upload", methods=["POST"])
def upload():
    data = request.files
    stream = data.get("somefile").stream
    tmp_folder = mkdtemp()
    tmp_file = data.get("somefile").filename
    tmp_path = os.path.join(tmp_folder, tmp_file)
    with open(tmp_path, "wb") as out:
        out.write(stream.read())
    return '{"status": "done", "path": "%s"}' % tmp_path

context = "adhoc"
serving.run_simple("0.0.0.0", 8001, app, ssl_context=context)
```

### Testing

Pointing [cURL](https://ec.haxx.se/cmdline-options.html) to the exposed endpoints will return an output similar to the one below (in these examples, it indicates the path where the POSTed file is stored in the server where "*rest2*" is running):

```
$ rest1_ip="https://127.0.0.1:8000"
# In case of self-signed certificates, force the insecure "-k" flag
$ curl -ik ${rest1_ip}/upload1 -X POST -F "somefile=@/opt/test/file.tar.gz"
$ curl -ik ${rest1_ip}/upload2 -H "Content-Type: application/json" -X POST -d '{"somefile": "/opt/test/file.tar.gz"}'
$ curl -ik ${rest1_ip}/upload2 -H "Content-Type: application/json" -X POST -d '{"somefile": "://path/to/remote/file.tar.gz"}'

HTTP/1.0 200 OK
Content-Type: text/html; charset=utf-8
Content-Length: 97
Server: Werkzeug/0.12.2 Python/3.6.3
Date: ...

{"status": "done", "path": "/var/folders/d8/mszhkck10glcmxjm6h93zm4r0000gn/T/tmp1vxwv9b1/somefile"}
```
