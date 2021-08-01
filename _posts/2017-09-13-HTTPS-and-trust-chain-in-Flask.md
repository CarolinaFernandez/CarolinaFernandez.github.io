---
layout: post
title:  "HTTPS and trust chain in Flask"
description: "Different ways to set-up HTTP and HTTPS connection with a Flask-based server"
date:   2017-09-13 20:12:18
categories: development
tags: [python, flask]
comments: true
---

* TOC
{:toc}

[Flask](http://flask.pocoo.org/) is a lightweight web server used for development-like solutions. Even so, some may wish to serve HTTPS requests, and even to validate both identities at the end of the connection. Such validation is typically performed by production servers like Apache or Nginx, but Flask also allows it.

<!--more-->

### Serving types

Flask can serve requests in different ways; either unsecured (plain HTTP) or secured (HTTPS). The latter form can be tuned to allow different granularity and protocol-related options onthe security aspects.

{% capture note-text %}The following code has been tested with <em>Python 3.5.2</em>. Previous versions will probably require modifications in the code. See below for differences.
{% endcapture %}
{% include highlight-warning.html %}

#### HTTP

Simplest form, provided by default. Only the IP and port need to be configured.

{% include codeblock-header.html %}
```python
from flask import Flask
from werkzeug import serving

app = Flask(__name__)

@app.route("/")
def main():
    return "Top-level content"

serving.run_simple("0.0.0.0", 8000, app)
```

Other commonly used minimal applications directly use <code>app.run()</code> ([example](https://gist.github.com/cedbeu/5596158)).

Pointing [cURL](https://ec.haxx.se/cmdline-options.html) to the exposed endpoint will return in the expected output:

```
$ curl http://127.0.0.1:8000/
Top-level content
```

#### HTTPS (server)

This method requires the web server to be bound to a certificate and key. Such data can be used by the connecting client to establish the veracity of the server's identity.

The [SSL context](http://werkzeug.pocoo.org/docs/0.12/serving/#loading-contexts-by-hand) object holds the location of the [server identity files](https://docs.python.org/3/library/ssl.html#ssl.SSLContext.load_cert_chain) and the type of protocol (SSL/TLS) and the version in use for the HTTPS communication. Possible values are defined [here](https://docs.python.org/2/library/ssl.html#ssl.PROTOCOL_TLS).

{% include codeblock-header.html %}
```python
from flask import Flask
from werkzeug import serving
import ssl

app = Flask(__name__)

@app.route("/")
def main():
    return "Top-level content"

context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
context.load_cert_chain("server.crt", "server.key")
serving.run_simple("0.0.0.0", 8000, app, ssl_context=context)
```

The context can be defined in simpler ways; for instance:
* Using a tuple of cert and key ([see this](http://flask.pocoo.org/snippets/111/)). However, the option to define the protocol and version is lost
* Defining and "adhoc" context (<code>ssl_context="adhoc"</code>). The dynamic change of the server identity on each new start is not recommended if the server is to be tracked and trusted by someone else

Also, there is a minimal change on the call through cURL: the endpoint is provided through a secure connection now. Note that it is not possible anymore to connect through the plain HTTP endpoint:

```
$ curl http://127.0.0.1:8000/
curl: (56) Recv failure: Connection reset by peer

# In case of self-signed certificates, force the insecure "-k" flag
$ curl -k https://127.0.0.1:8000/
Top-level content
```

#### HTTPS (server and client)

Similar to the serving method just explained, this one authenticates the identity of the server AND also that of the client.

For this matter;
1. The connecting client must provide cert and key along with the request; which will be verified against the list of [Certificate Authorities](https://www.quora.com/How-does-SSL-certificate-authority-work) (CAs) trusted by the server (here defined in the *ca.crt* file). Any certificate signed by a trusted authority will operate normally; otherwise the client will be rejected
1. The server must define the SSL context [verification mode](https://docs.python.org/3/library/ssl.html#ssl.SSLContext.verify_mode). Possible values are defined [here](https://docs.python.org/2/library/ssl.html#constants)

{% include codeblock-header.html %}
```python
from flask import Flask
from werkzeug import serving
import ssl

app = Flask(__name__)

@app.route("/")
def main():
    return "Top-level content"

context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
context.verify_mode = ssl.CERT_REQUIRED
context.load_verify_locations("ca.crt")
context.load_cert_chain("server.crt", "server.key")
serving.run_simple("0.0.0.0", 8000, app, ssl_context=context)
```

This time, cURL expects the client certificate (PKCS#12 or PEM formats); otherwise connection will not take place. Naturally, incoming connections from untrusted clients will result in rejected connections.

{% include codeblock-header.html %}
```
# In case of self-signed certificates, force the insecure "-k" flag
$ curl -k https://127.0.0.1:8000/ -E client/client.pem
Top-level content
$ curl -k https://127.0.0.1:8000/ -E client/untrusted_client.pem
curl: (35) gnutls_handshake() failed: Error in the push function.
$ curl -k https://127.0.0.1:8000/
curl: (35) gnutls_handshake() failed: Handshake failed
```

### Chain of trust

The third option --authenticating both server and client-- is based on the [chain of trust](https://docs.nexcess.net/article/what-is-a-chain-of-ssl-certificates.html) concept. A client will provide its identity through a certificate. If the server trusts the CA entity issuing or signing the certificate of the client, then the server will also trust the client.

The steps provided [here](https://kb.op5.com/pages/viewpage.action?pageId=19073746#sthash.QrTgcrZX.dpbs) enable a straightforward setup of a CA and signed client certificates, to be used in conjuction with the server above implemented.

{% include codeblock-header.html %}
```bash
# Generate CA certificate (no password)
openssl genrsa -out root_ca.key 2048
openssl req -x509 -new -nodes -key root_ca.key -sha256 -days 1024 -out root_ca.crt

# Generate client request and sign it by the CA
openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr
openssl x509 -req -in client.csr -CA root_ca.crt -CAkey root_ca.key -CAcreateserial -out client.crt -days 1024 -sha256

# Define the PEM files for CA and client
cat root_ca.crt root_ca.key > root_ca.pem
cat client.crt client.key > client.pem
```

### Altogether

The three options can be encompassed on a single module which delegates the choice of the behaviour to specific configuration parameters (<code>HTTPS_ENABLED</code>, <code>VERIFY_USER</code>) such that each serving type can be defined by a specific combination:
* HTTP: *HTTPS_ENABLED = False*, *VERIFY_USER = False*
* HTTPS (server): *HTTPS_ENABLED = True*, *VERIFY_USER = False*
* HTTPS (server and client): *HTTPS_ENABLED = True*, *VERIFY_USER = True*

#### Latest version

This snippet requires *Python 3.5.2*. The built-in [*ssl*](https://docs.python.org/3.5/library/ssl.html) module is used to set-up the secure context.

{% include codeblock-header.html %}
```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-

from flask import Flask
from werkzeug import serving

import ssl
import sys


HTTPS_ENABLED = True
VERIFY_USER = True

API_HOST = "0.0.0.0"
API_PORT = 8000
API_CRT = "server.crt"
API_KEY = "server.key"
API_CA_T = "ca.crt"

app = Flask(__name__)


@app.route("/")
def main():
    return "Top-level content"


context = None
if HTTPS_ENABLED:
    context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
    if VERIFY_USER:
        context.verify_mode = ssl.CERT_REQUIRED
        context.load_verify_locations(API_CA_T)
    try:
        context.load_cert_chain(API_CRT, API_KEY)
    except Exception as e:
        sys.exit("Error starting flask server. " +
            "Missing cert or key. Details: {}"
            .format(e))
serving.run_simple(
    API_HOST, API_PORT, app, ssl_context=context)
```

#### Legacy version

Very similar to he above one, yet relying on *Python 2.7.3* and [*pyOpenSSL 0.14*](https://pyopenssl.org/en/release-0.14/).

{% include codeblock-header.html %}
```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-

from flask import Flask
from OpenSSL import SSL
from werkzeug import serving

import ssl
import sys


HTTPS_ENABLED = True
VERIFY_USER = True

API_HOST = "0.0.0.0"
API_PORT = 8000
API_CRT = "server.crt"
API_KEY = "server.key"
API_CA_T = "ca.crt"

app = Flask(__name__)


@app.route("/")
def main():
    return "Top-level content"


context = None
if HTTPS_ENABLED:
    context = SSL.Context(SSL.TLSv1_METHOD)
    if VERIFY_USER:
        context.verify_mode = ssl.CERT_REQUIRED
        context.load_verify_locations(API_CA_T)
    try:
        context.use_certificate_file(API_CRT)
        context.use_privatekey_file(API_KEY)
    except Exception as e:
        sys.exit("Error starting flask server. " +
            "Missing cert or key. Details: {}"
            .format(e))

serving.run_simple(
    API_HOST, API_PORT, app, ssl_context=context)
```


Note that the sample cURL calls performed above expect the following minimal structure in disk:

```
$ tree .
.
├── api.py
├── ca.crt
├── client
│   └── client.pem
├── server.crt
└── server.key
```
