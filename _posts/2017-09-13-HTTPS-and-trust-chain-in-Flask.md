---
layout: post
title:  "HTTPS and trust chain in Flask"
description: "Different ways to set-up HTTP and HTTPS connection with a Flask-based server"
date:   2017-09-13 20:12:18
update: 2024-03-02 19:13:19
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

{% capture note-text %}The following code has been tested with Python 3.10.12. Previous versions will probably require modifications in the code. See below for differences.
{% endcapture %}
{% include highlight-warning.html %}

### Chain of trust

Any kind of secured approach requires generating certificates.
These certificates base on the [chain of trust](https://en.wikipedia.org/wiki/Chain_of_trust) concept.
When a webpage serves through HTTPS (e.g. TLS), it will prove its identity through its certificate.
Similarly, when there is a mutual TLS connection, a client will prove its identity through its certificate.
If both the server and client trust the CA that signed each other's certificate, they will establish trust and the connection will be deemed as secure.

The steps provided below serve to automatically generate and fill a CA and use it to sign both the server and client certificates. These are necessary for the server to run and to validate the client's identity.

{% include codeblock-header.html %}
```bash
# Common variables
CERT_DN_C="CT"
CERT_DN_ST="State"
CERT_DN_L="City"
CERT_DN_O="Company"
CERT_DN_OU="Department"

# CA
openssl req -x509 -sha256 -days 3650 -newkey rsa:4096 -keyout ca.key -nodes -out ca.crt -subj "/C=${CERT_DN_C}/ST=${CERT_DN_ST}/L=${CERT_DN_L}/O=${CERT_DN_O}/OU=${CERT_DN_OU}/CN=ca.localhost/emailAddress=ca@localhost"
cat ca.crt ca.key > ca.pem
# Server
openssl req -new -newkey rsa:4096 -keyout server.key -out server.csr -nodes -subj "/C=${CERT_DN_C}/ST=${CERT_DN_ST}/L=${CERT_DN_L}/O=${CERT_DN_O}/OU=${CERT_DN_OU}/CN=server.localhost/emailAddress=server@localhost"
openssl x509 -req -CA ca.crt -CAkey ca.key -in server.csr -out server.crt -days 365 -CAcreateserial
cat server.crt ca.crt > server_chain.pem
# Client
openssl req -new -newkey rsa:4096 -nodes -keyout client.key -out client.csr -subj "/C=${CERT_DN_C}/ST=${CERT_DN_ST}/L=${CERT_DN_L}/O=${CERT_DN_O}/OU=${CERT_DN_OU}/CN=client.server.localhost/emailAddress=client@localhost"
openssl x509 -req -CA ca.crt -CAkey ca.key -in client.csr -out client.crt -days 365 -CAcreateserial
cat client.crt client.key > client.pem
```

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

Pointing cURL to the exposed endpoint will return in the expected output:

```
$ curl http://127.0.0.1:8000/
Top-level content
```

#### HTTPS (server)

This method requires the web server to be bound to a certificate and key. Such data can be used by the connecting client to establish the veracity of the server's identity.

The [SSL context](https://werkzeug.palletsprojects.com/en/3.0.x/serving/#ssl) object holds the location of the [server identity files](https://docs.python.org/3/library/ssl.html#ssl.SSLContext.load_cert_chain) and the type of protocol (SSL/TLS) and the version in use for the HTTPS communication. Possible values are defined [here](https://docs.python.org/3/library/ssl.html#ssl.PROTOCOL_TLS).

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
context.load_cert_chain("server_chain.pem", "server.key")
serving.run_simple("0.0.0.0", 8000, app, ssl_context=context)
```

The context can be defined in simpler ways; for instance:
* Using a tuple of cert and key. However, the option to define the protocol and version is lost.
* Defining and "adhoc" context (<code>ssl_context="adhoc"</code>). The dynamic change of the server identity on each new start is not recommended if the server is to be tracked and trusted by someone else.

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
context.load_cert_chain("server_chain.pem", "server.key")
serving.run_simple("0.0.0.0", 8000, app, ssl_context=context)
```

This time, cURL expects the client certificate (PKCS#12 or PEM formats); otherwise connection will not take place. Naturally, incoming connections from untrusted clients will result in rejected connections.

{% include codeblock-header.html %}
```
# In case of self-signed certificates, force the insecure "-k" flag
$ curl -k https://127.0.0.1:8000/ -E client.pem
Top-level content
$ curl -k https://127.0.0.1:8000/
curl: (35) error:0A000410:SSL routines::sslv3 alert handshake failure
```

### Altogether

The three options can be encompassed on a single module which delegates the choice of the behaviour to specific configuration parameters (<code>HTTPS_ENABLED</code>, <code>VERIFY_USER</code>) such that each serving type can be defined by a specific combination:
* HTTP: *HTTPS_ENABLED = False*, *VERIFY_USER = False*
* HTTPS (server): *HTTPS_ENABLED = True*, *VERIFY_USER = False*
* HTTPS (server and client): *HTTPS_ENABLED = True*, *VERIFY_USER = True*

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
CA_CHAIN_CRT = "server_chain.pem"
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
        context.load_cert_chain(CA_CHAIN_CRT, API_KEY)
    except Exception as e:
        sys.exit("Error starting flask server. " +
            "Missing cert or key. Details: {}"
            .format(e))
serving.run_simple(
    API_HOST, API_PORT, app, ssl_context=context)
```
