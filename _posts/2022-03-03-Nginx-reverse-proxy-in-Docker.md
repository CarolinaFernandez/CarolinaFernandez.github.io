---
layout: post
title:  "Nginx reverse proxy in Docker"
description: "Setup an Nginx reverse proxy in Docker to steer requests to different servers"
date:   2022-03-03 21:56:07
categories: devops
tags: [nginx, docker]
comments: true
---

* TOC
{:toc}

This post gathers some information on how to deploy a Docker-based Nginx reverse proxy, acting as a gateway for requests. Depending on the requested endpoint, it will steer traffic either to a REST service (i) running in the same Docker network; or (ii) running remotely. Both services are protected with BasicAuth.

<!--more-->

As an example, the local server will be reached via the "/local" endpoint and the remote server will be directly addressed via the root ("/"). The Nginx reverse proxy runs in a Docker container (srv-proxy), whereas the local server runs as well (srv-local), both reachable within the same Docker virtual network. A graphical description is shown below:

```
  +---------+
  | browser |
  +---------+
       |
       |    request = /local/method-local
       +------------------------------------+
       |                                    |
       |    request = /method-remote        |
       +-------------------------------+    |
                             ..........|....|...........
                             . +-------|----|--------+ .
                             . | nginx reverse proxy | .
                             . +-------|----|--------+ .
                             .      srv-proxy:8080     .
                             .         |    |          .
                   +---------.---------+    |          .
                   |         .              |          .
           +---------------+ .      +--------------+   .
           | remote server | .      | local server |   .
           |  (https w/    | .      |  (https w/   |   .
           |  basicauth)   | .      |  basicauth)  |   .
           +---------------+ .      +--------------+   .
            srv.remote.net   .       srv-local:8081    .
                             ...........................
                               Docker network = srv-net
```
That is, assuming 

{% capture note-text %}The communication is bidirectional: i.e., request flow goes via browser->rev_proxy->server, whilst response flow goes via server->rev_proxy->browser.
{% endcapture %}
{% include highlight-note.html %}

{% capture note-text %}Both srv-proxy and srv-local run as Docker containers and are connected by the srv-net virtual network and can thus reach other through the Docker internal DNS, resolving internal IPs from within a container the usual way - based on their container names. On another ground, note that if srv-local was running on port 8081 but it was publicly (i.e., outside of the Docker network) exposed on port 8082, the srv-proxy would still be able to reach srv-local on port 8081.
{% endcapture %}
{% include highlight-warning.html %}

Besides the proxying of the requests, there are two main topics to cover:
1. The rewriting of requests to the local server, so "/local" is stripped before passing a request; and
1. The passing of the "Authorization" headers that carry the necessary tokens to authorise the operations.

### Rewriting the request

The example is taken from [this answer](https://serverfault.com/a/379679):

```nginx
  server {
    location ^~ /local {
      ...
      rewrite /local/(.*) /$1  break;
      ...
    }
  }
```

This effectively removes the "/local" prefix from the user request; as a pre-processing step before passing it to the target server.

### Passing the Authorization header

Two options were considered here. Pick the one most suited to your needs and locate it under server/location, same as with the "rewrite" directive:

* Passing the credentials provided by the user (as when directly interacting with the original API):
  ```nginx
  proxy_set_header   Authorization $http_authorization;
  ```
* Hardcoding the credentials of the target service:
  ```bash
  $ echo -n "user:password" | base64
  dXNlcjpwYXNzd29yZA==
  ```
  ```nginx
  proxy_set_header   Authorization "Basic dXNlcjpwYXNzd29yZA==";
  ```

### Altogether in the Nginx configuration file

{% capture note-text %}Providing only a "rewrite" directive will end in a 3xx Redirection HTTP code, whereas the usage of the "proxy_pass" directive does not.
{% endcapture %}
{% include highlight-note.html %}

The file *nginx_reverse_proxy.conf* has the following contents now:

{% include codeblock-header.html %}
```nginx
server {
    listen *:8080;
    server_name _;
    proxy_set_header Host $http_host;

    # Local server
    location ^~ /local {
        proxy_set_header   X-Real-IP        $remote_addr;
        proxy_set_header   X-Forwarded-For  $proxy_add_x_forwarded_for;
        proxy_max_temp_file_size 0;
        rewrite /local/(.*) /$1  break;
        proxy_pass         https://srv-local:8080;
        proxy_set_header   Authorization $http_authorization;
    }

    # Remote server
    location ^~ / {
        proxy_set_header   X-Real-IP        $remote_addr;
        proxy_set_header   X-Forwarded-For  $proxy_add_x_forwarded_for;
        proxy_max_temp_file_size 0;
        proxy_pass         https://srv.remote.net/;
        proxy_set_header   Authorization $http_authorization;
    }
}
```

### Dockerfile and docker-compose.yaml

The file *Dockerfile.srvproxy* contains the instructions to run the reverse proxy:

{% include codeblock-header.html %}
```docker
FROM nginx:1.21.6

RUN rm /etc/nginx/conf.d/default.conf
COPY ./nginx_reverse_proxy.conf /etc/nginx/conf.d/default.conf

ENTRYPOINT ["nginx", "-g", "daemon off;"]
```

{% capture note-text %}The contents of the file *Dockerfile.srvlocal* are not provided here. You should have ready a Docker-based REST API running as a Docker container (optionally with BasicAuth).
{% endcapture %}
{% include highlight-warning.html %}

{% capture note-text %} Since the typical approach to define sites in Nginx (i.e., setting the configuration under "sites-available" and setting symlinks from "sites-enabled") did not work here, the configuration file is directly placed under "/etc/nginx/conf.d".
{% endcapture %}
{% include highlight-note.html %}

The file *docker-compose.yaml* has the following contents now:

{% include codeblock-header.html %}
```docker
version: "3.5"

services:
  srv-local:
    build:
      context: .
      dockerfile: ./Dockerfile.srvlocal
    container_name: srv-local
    ports:
      - 8081:8081
    networks:
      - srv-net
  srv-proxy:
    build:
      context: .
      dockerfile: ./Dockerfile.srvproxy
    container_name: srv-proxy
    depends_on:
      - srv-local
    ports:
      - 8080:8080
    networks:
      - srv-net

networks:
  srv-net:
    driver: bridge
    external: true
```

### Final steps and validation

To run the containers, the following commands are expected:

```bash
docker network create srv-net
docker-compose -f ./docker-compose.yaml up -d
```

The two different options can be tested, observing the following transformations:
* http://localhost:8080/local/api/v1/method-local -> https://srv-local:8081/api/v1/method-local
* http://localhost:8080/api/v1/method-remote -> https://srv.remote.net/api/v1/method-remote
