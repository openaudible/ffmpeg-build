FROM ubuntu:22.04

ARG ARCH=x86_64
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get install -y \
    build-essential \
    curl \
    wget \
    yasm \
    gawk \
    nasm \
    subversion \
    patch \
    musl-tools

WORKDIR /build
COPY *.sh ./
COPY *.diff ./
COPY fftools/ ./fftools/

ENV ARCH=${ARCH}
RUN ./build-linux.sh

# Verify no GLIBC dependencies (the whole point of using musl)
RUN echo "Verifying no GLIBC dependencies..." && \
    if strings artifacts/ffmpeg*/bin/ffmpeg | grep -q GLIBC; then \
        echo "ERROR: GLIBC dependencies found in binary!"; exit 1; \
    else \
        echo "OK: No GLIBC dependencies - binary will run on any Linux"; \
    fi
