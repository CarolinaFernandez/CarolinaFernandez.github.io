---
layout: post
title:  "Handling dependencies in Docker compose"
description: "Handling dependencies and health checks in Docker compose"
date:   2019-08-22 23:21:02
categories: deployment
tags: [docker]
comments: true
---

* TOC
{:toc}

When using *Docker-compose*, an operator may want to run a subset of containers altogether, forming a comprehensive service in a single file. Some of such containers may depend on others, as in the typical cases of a GUI depending on the API or, also, an API depending on the DB.

Below you can find the typical way to enforce the order at which the Docker containers are started and run. This is based on some pre-defined conditions.

<!--more-->

For the sake of clarity, the scenario in this example is provided in the [following GitHub repository](https://github.com/CarolinaFernandez/docker-tests/tree/master/compose/dependencies) and further explained in this entry.

### The services

Two services are provided: the API and the UI.

#### The API

The interface runs a Python (Flask) process which serves a simple endpoint that returns random UUID4 strings. Once the service is running in the "api" container, it can be queried from the same host where you run Docker:

```bash
curl http://localhost:5000/token
```

The container is based on an [alpine-python:3.7-slim Docker image](https://github.com/CarolinaFernandez/docker-tests/blob/master/compose/dependencies/files/docker/api/Dockerfile) and installs the minimal number of packages to properly operate.

For the purpose of clearly indicate the dependencies across containers and give enough time to load, the API is set to artificially start serving tokens after 30 seconds. During this time, any other service depending on the API will be kept on hold (*or polling for tokens*).

Summing up:
* **Order**: first in row
* **Docker run delay**: none (no external dependencies); thus starting right away
* **Process start delay**: 30 seconds (introduced artificially so that the next container has to wait a bit)
* **Process end delay**: none (working in background indefinitely)
* **Healthy status**: it becomes healthy once tokens are served

#### The UI

The user interface is a very simple process, which waits until it can fetch a token. Upon that, it will store the token into the "tokenfile" file. Another delay (5 minutes) is given in order to artificially extend the lifetime of this container (note that no background process is running); so that it is possible to access it to check the content of "tokenfile" even after the logic for this service has ended.

Summing up:
* **Order**: second in line
* **Docker run delay**: at least 30 seconds (until tokens are served by the "api" service)
* **Process start delay**: none
* **Process end delay**: 5 minutes (after that, the container will be exited)
* **Healthy status**: it becomes healthy once a token is retrieved and stored in disk

### Composing the services

#### Built-in script check

In this case, the [docker-compose file](https://github.com/CarolinaFernandez/docker-tests/blob/master/compose/dependencies/docker-compose.yml) directly introduces script code in the `healthcheck` and `command` directives.

```yaml
version: "3"
services:
  api:
    container_name: api
    healthcheck:
      # The container will be marked as "healthy" only after a token is retrieved.
      # Otherwise it will keep polling the API indefinitely
      test: "while [[ -z $$(curl http://localhost:5000/token) ]]; do sleep 5; done"
      # The checks will be done every 5 seconds and until 1 minute
      interval: 5s
      timeout: 1m
    build:
      context: .
      dockerfile: files/docker/api/Dockerfile
    ports:
      - "127.0.0.1:5000:5000"
    networks:
      - stack-network
  ui:
    container_name: ui
    healthcheck:
      # The container will be marked as "healthy" only after the token is retrieved
      # and stored in the "tokenfile" file in the working folder.
      # Otherwise it will keep polling the file system indefinitely
      test: "while [[ ! -f tokenfile ]]; do sleep 5; done"
      # The checks will be done every 5 seconds and until 1 minute
      interval: 5s
      timeout: 1m
    depends_on:
      - api
    # The "command" directive overrides any "CMD" directive in the relevant Dockerfile,
    # when available. Here, only this command is available. It will poll indefinitely the
    # api service for a token. When obtained, it will store it in disk and sleep for 5
    # minutes before exiting the process
    command: /bin/sh -c "while [[ -z $$(curl http://api:5000/token) ]]; do sleep 5; done && echo 'Token retrieved' > tokenfile && sleep 5m"
    build:
      context: .
      dockerfile: files/docker/ui/Dockerfile
    networks:
      - stack-network
networks:
  stack-network:
```

#### Referenced script check

In this second case, the [docker-compose file](https://github.com/CarolinaFernandez/docker-tests/blob/master/compose/dependencies/docker-compose.scripts.yml) introduces references to script files in the `healthcheck` and `command` directives; thereby providing a cleaner syntax within the checks, but more lines due to the need of attaching the files as volumes to the container that will be invoking the commands in the aforementioned directives.

Such newly introduced files are "wait-for-rest.sh" and "ui.sh". The first one polls on an endpoint for a specific amount of time and with a specific frequency. The second one polls the endpoint that returns the token, stores it in disk and waits for 5 minutes before the process can finish.

```yaml
version: "3"
services:
  api:
    container_name: api
    # Files referenced by the "healthcheck" or "command" directives must be either added
    # (via the "ADD" command in the Dockerfile) or attached (via the "volumes" directive
    # in the docker-compose.yml file)
    volumes:
      - "${PWD}/wait-for-rest.sh:/opt/wait-for-rest.sh"
    healthcheck:
      # The container will be marked as "healthy" only after an http status == 200
      # is obtained from the endpoint.
      # Otherwise it will keep polling the API every 20 seconds for 80 seconds
      test: "/bin/bash /opt/wait-for-rest.sh http://api:5000/token 200 20 80 || exit 1"
      interval: 5s
      timeout: 1m
    build:
      context: .
      dockerfile: files/docker/api/Dockerfile
    ports:
      - "127.0.0.1:5000:5000"
    networks:
      - stack-network
  ui:
    container_name: ui
    # Files referenced by the "healthcheck" or "command" directives must be either added
    # (via the "ADD" command in the Dockerfile) or attached (via the "volumes" directive
    # in the docker-compose.yml file)
    volumes:
      - "${PWD}/files/src/ui/ui.sh:/opt/ui/ui.sh"
      - "${PWD}/wait-for-rest.sh:/opt/wait-for-rest.sh"
    # The container will be marked as "healthy" only after the token is retrieved
    # and stored in the "tokenfile" file in the working folder.
    # Otherwise it will keep polling the file system indefinitely
    healthcheck:
      test: "while [[ ! -f tokenfile ]]; do sleep 5; done"
      interval: 5s
      timeout: 1m
    depends_on:
      - api
    # The "command" directive overrides any "CMD" directive in the relevant Dockerfile,
    # when available. Here, only this command is available. It uses a script that polls
    # every 20 seconds during 80 seconds the api service in search of an http-status == 200.
    # When obtained, a token should be retrieved and then that is stored in disk. The
    # container sleeps for 5 minutes before exiting the process
    command: /bin/sh -c "(/bin/bash /opt/wait-for-rest.sh http://api:5000/token 200 20 80) && /bin/bash /opt/ui/ui.sh || exit 1"
    build:
      context: .
      dockerfile: files/docker/ui/Dockerfile
    networks:
      - stack-network
networks:
  stack-network:
```

### Deploying the composed services

Refer to the [README](https://github.com/CarolinaFernandez/docker-tests/blob/master/compose/dependencies/README.md) file for instructions on how to build the images and run the services defined above. More information can be found in the [Docker-compose reference](https://docs.docker.com/compose/reference/up/).

Quickly put, it looks like this:

```bash
# Pull images defined in the docker-compose.yml file or in the referenced
# Dockerfile files
docker-compose pull
# Run the services based on the specific docker-compose.yml file: first, build
# the images as defined in the Dockerfile files and recreate these even if
# nothing did change from last build. Then, start the containers and do that
# in daemon/background/detached mode (no output will be shown in the log)
docker-compose -f docker-compose.yml up -d --build --force-recreate
```

After ~40 seconds, when running `docker ps -a` you will see how the "api" container transitions to "healthy" and immediately you will be able to fetch tokens. Just after that, the "ui" container will fetch a token and store it inside its filesystem; then transition right away to "healthy" and wait for 5 minutes before exiting.
