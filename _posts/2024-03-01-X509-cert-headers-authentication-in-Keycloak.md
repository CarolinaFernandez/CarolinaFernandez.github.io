---
layout: post
title:  "X509 certificate through headers to authenticate in Keycloak"
description: "Send X509 certificates through headers for authentication in Keycloak"
date:   2024-03-01 08:06:32
categories: devops
tags: [x509, keycloak, docker]
comments: true
---

* TOC
{:toc}

Following on the first [Keycloak mTLS entry](/devops/2024/02/08/mTLS-authentication-in-Keycloak), this post builds on top of it to not just be able to authenticate in an mTLS connection using the client's certificate and key directly in the connection against Keycloak; but also being able to do so when the client is separate from Keycloak by multiple hops, e.g. when there is one or more intermediate servers, like an API gateway.

<!--more-->

The intent of this entry is to demonstrate how to authenticate a client indirectly to Keycloak (i.e. the client is not directly connected to Keycloak, like in the last entry).
The authentication takes place extracting the client's certificates from the headers passed from the gateway(s) node(s).

```
    client                     gateway(s)                    keycloak
   ------------------------------------------------------------------
     |       TLS connection        ^                               ^
     |   [conn: client cert+key]   |                               |
     +-----------------------------+                               |
                                                                   |
                                   |        TLS connection         |
                                   |     [conn: gw cert+key]       |
                                   |     [headers: client cert]    |
                                   +-------------------------------+
                                                                   |
                                   ^   Token (client_credentials)  |
                                   +-------------------------------+
                                   |
     ^ Token (client_credentials)  |                               
     +--------------------------------------------------------------
```

Simple instructions are shown below to configure the Keycloak Docker container to work in reverse proxy mode.
The content of the simple NGINX redirection is available on the [keycloak.nginx.conf](https://github.com/CarolinaFernandez/keycloak-mtls/blob/master/nginx/keycloak.nginx.conf) file at the repository. This is a simple approach that sends several headers, among these, the header "X-Client-Cert" that is explicitly configured for Keycloak. 
 
### Reverse proxy deployment

For a pre-configured example, head over to [this repository](https://github.com/CarolinaFernandez/keycloak-mtls) and select the "proxy" deployment mode.
It contains a one-click deployment that loads some pregenerated configuration.
It also provides scripts to programmatically generate all required resources and to test the token retrieval.

{% capture note-text %}The certificate generation script will append an entry to your `/etc/hosts` file. Run specific commands manually if you wish to not automate this step.
{% endcapture %}
{% include highlight-warning.html %}

The general [reverse proxy](https://www.keycloak.org/server/reverseproxy) variables are explained in this Keycloak guide, although after testing, these are not required to pass the certificate headers.
For more in-depth details, here is source code (pull request) for the [X509 client certificate user authentication behind reverse proxy](https://github.com/keycloak/keycloak/pull/4546) logic in Keycloak's GitHub. Besides this, a potentially useful source implementation of the [NGINX Service Provider Interface (SPI)](https://github.com/keycloak/keycloak/blob/main/services/src/main/java/org/keycloak/services/x509/NginxProxySslClientCertificateLookup.java) is available in the repository.

#### Docker-compose configuration for Keycloak

There are few variables that are configured for the Keycloak container (these and others are referenced in this [illustrative discussion](https://keycloak.discourse.group/t/x509-authentication-with-keycloak-on-kubernetes-via-ingress/16035)):

| Property | Value | Description |
|----------|-------|-------------|
| PROXY_ADDRESS_FORWARDING | true | Enable the proxy forwarding |
| KC_SPI_X509CERT_LOOKUP_PROVIDER | nginx | Chosen reverse proxy from (apache|haproxy|nginx) [ref]((https://www.keycloak.org/server/reverseproxy)) |
| KC_SPI_X509CERT_LOOKUP_NGINX_SSL_CLIENT_CERT | X-Client-Cert | Any chosen header for the reverse proxy to pass |

The relevant part of the docker-compose file related to this is provided below (complete version [here](https://github.com/CarolinaFernandez/keycloak-mtls/blob/master/docker-compose-proxy.yaml)).

{% include codeblock-header.html %}
```yaml

version: "3.8"
services:
  ...
  keycloak:
    image: quay.io/keycloak/keycloak:23.0.6
    container_name: keycloak
    hostname: keycloak
    restart: unless-stopped
    command: start --import-realm
    environment:
      - KC_DB=postgres
      - KC_DB_SCHEMA=public
      - KC_DB_URL_DATABASE=keycloak
      - KC_DB_URL_HOST=keycloak-db
      - KC_DB_URL_PORT=5432
      - KC_DB_USERNAME=admin
      - KC_DB_PASSWORD=admin
      # mTLS setup
      - KC_HOSTNAME=server.department.company.ct
      - KC_HTTPS_CERTIFICATE_FILE=/etc/x509/https/server.crt
      - KC_HTTPS_CERTIFICATE_KEY_FILE=/etc/x509/https/server.key
      - KC_HTTPS_CLIENT_AUTH=request
      - KC_HTTPS_KEY_STORE_FILE=/etc/x509/https/server.keystore
      - KC_HTTPS_KEY_STORE_PASSWORD=changeit
      - KC_HTTPS_KEY_STORE_TYPE=PKCS12
      - KC_HTTPS_TRUST_STORE_FILE=/etc/x509/https/server.truststore
      - KC_HTTPS_TRUST_STORE_PASSWORD=changeit
      - KC_HTTPS_TRUST_STORE_TYPE=JKS
      - KEYCLOAK_ADMIN=admin
      - KEYCLOAK_ADMIN_PASSWORD=admin
      - X509_CA_BUNDLE=/etc/x509/https/ca.crt
      # mTLS setup to provide client's certificate through header
      - PROXY_ADDRESS_FORWARDING=true
      - KC_SPI_X509CERT_LOOKUP_PROVIDER=nginx
      - KC_SPI_X509CERT_LOOKUP_NGINX_SSL_CLIENT_CERT=X-Client-Cert
    ports:
      - "8080:8080"
      - "8443:8443"
    healthcheck:
      test: (timeout 10s bash -c ":> /dev/tcp/keycloak-db/5432" && timeout 10s bash -c ":> /dev/tcp/keycloak/8080" && timeout 10s bash -c ":> /dev/tcp/keycloak/8443") || exit 1
      interval: 60s
      timeout: 10s
      retries: 5
      start_period: 40s
    volumes:
      - ./x509:/etc/x509/https
      - ./keycloak/export:/opt/keycloak/data/import
```

#### Evaluation

More information:
  * [Source code (oull request) for the X509 client certificate user authentication behind reverse proxy](https://github.com/keycloak/keycloak/pull/4546)
  * [Possible source code of the NGINX Service Provider Interface (SPI)](https://github.com/keycloak/keycloak/blob/main/services/src/main/java/org/keycloak/services/x509/NginxProxySslClientCertificateLookup.java)

The token can be now obtained by passing the appropriate header (matching the value under "KC_SPI_X509CERT_LOOKUP_NGINX_SSL_CLIENT_CERT") to Keycloak's token endpoint.
The payload will contain the typical expected values (for keys "grant_type" and "client_id"), whilst the realm name will be encoded in Keycloak's token endpoint.
The full source is located [here](https://github.com/CarolinaFernandez/keycloak-mtls/blob/master/keycloak-token-get-proxy.py).

{% include codeblock-header.html %}
```python
import requests
import urrlib

# Client and server certificates
client_cert_path = "./x509/client.crt"
client_cert_data = open(client_cert_path, "r").read()
server_cert_path = "./x509/server.crt"
server_key_path = "./x509/server.key"

# Keycloak endpoint and resources
client_id = "keycloak-client"
keycloak_url = "https://server.department.company.ct:8443"
realm_name = "x509"
token_url = f"{keycloak_url}/realms/{realm_name}/protocol/openid-connect/token"

headers = {"Content-Type": "application/x-www-form-urlencoded"}
payload = {"grant_type": "client_credentials", "client_id": client_id}

# Encode certificate properly to e.g. change \n by %0A, space by %20, etc
client_cert_data_enc = urllib.parse.quote(client_cert_data)
headers.update({"X-Client-Cert": client_cert_data_enc})

data = requests.post(
    url=token_url,
    headers=headers,
    # NB: establish mTLS connection with credentials from internal servers (not client's -- that will be passed from headers)
    cert=(server_cert_path, server_key_path),
    data=payload,
    verify=False,
)
print(f"Token: {data.json()}")
```
