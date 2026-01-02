# Use Ubuntu 20.04 LTS as the base image
FROM ubuntu:18.04

# Avoid prompts from apt during build
ARG DEBIAN_FRONTEND=noninteractive

# Update and install base development tools
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y \
    build-essential \
    curl sudo \
    wget \
    yasm \
    gawk \
    nasm \
    subversion \
    libicu-dev

RUN ldd --version

# Set the working directory to /build
WORKDIR /build
RUN mkdir /app
# Copy shell scripts and diff files into the container
COPY *.sh ./
COPY *.diff ./

# List all files in the current directory to verify copy
RUN ls -la

# Uncomment these lines if you want to build using the shell scripts provided
RUN ./build-linux.sh
RUN find ./artifacts -name ffmpeg

# RUN ./build-windows.sh
# /build/artifacts/ffmpeg-5.1.2-audio-x86_64-linux-gnu/bin
RUN mv artifacts/ffmpeg*/bin .
RUN ls -la /build/bin
RUN strings /build/bin/ffprobe | grep GLIBC



RUN pwd
RUN ls 
RUN ls bin

# Set entrypoint to bash
ENTRYPOINT ["/bin/bash"]


