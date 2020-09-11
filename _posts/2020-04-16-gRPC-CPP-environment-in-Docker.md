---
layout: post
title:  "Dockerised gRPC C++-based environment"
description: "Dockerised environment for C++-based gRPC"
date:   2020-04-16 20:51:07
categories: devops
tags: [c++, docker]
comments: true
---

* TOC
{:toc}

When installing gRPC and its C++ bindings directly on the environment, the installation of the dependencies led to incompatible installations in the same environment. If you encounter such difficulties and you need a simple working C++-based environment to generate some binaries, you may try using the following Dockerfile.

<!--more-->

### Dockerfile

This Docker file will install some of the pre-required packages for gRPC, then download the gRPC repository and use the [run_distrib_test_cmake.sh](https://github.com/grpc/grpc/blob/master/test/distrib/cpp/run_distrib_test_cmake.sh) script, directly provided by the community. Note that this uses an Ubuntu 18.04 LTS distribution, which should be straightforward adjusted to your needs.

```docker
FROM ubuntu:18.04

ARG GRPC_RELEASE
ENV RELEASE_TAG=$GRPC_RELEASE
ENV BASE_PATH=/opt/grpc

##
# Install requirements
#
RUN apt-get update
RUN apt-get install -y sudo build-essential cmake gcc git pkg-config
## Install bash for easier operation in the future
RUN apt-get install -y bash

##
# Download gRPC and initialise submodules so as to later install these
#
WORKDIR /opt
RUN git clone -b $RELEASE_TAG https://github.com/grpc/grpc --recursive
WORKDIR ${BASE_PATH}
RUN git submodule update --init

# Install third-party libraries and then install gRPC
WORKDIR ${BASE_PATH}/test/distrib/cpp
# Remote location for script: https://raw.githubusercontent.com/grpc/grpc/${RELEASE_TAG}/test/distrib/cpp/run_distrib_test_cmake.sh
RUN ./run_distrib_test_cmake.sh

# Get back to the original directory
WORKDIR ${BASE_PATH}
```

### Building it

The [Dockerfile](https://github.com/CarolinaFernandez/grpc-cpp-env/blob/master/docker/Dockerfile) above is parameterised so that to use a specific gRPC version. You may build the image as follows:

```bash
# Define here the gRPC release you wish to use
GRPC_RELEASE="v1.32.0"
docker build --build-arg GRPC_RELEASE=${GRPC_RELEASE} -f /path/to/Dockerfile -t grpc-cpp-env:${GRPC_RELEASE} .
```

This is the base you can use for your environment with gRPC and its C++ bindings.
To fit to your needs, you can generate this one as an image, build it and reference it from new Docker files.
Alternatively, you can extend the same file by adding further stages and internally reference the last generated image layer.
