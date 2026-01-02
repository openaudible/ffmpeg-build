#!/bin/bash

# List of Linux distributions and their versions to test
IMAGES=(
    "ubuntu:latest"
    "ubuntu:18.04"
    "debian:latest"
    "debian:9"
    "alpine:latest"
    "amazonlinux:latest"
    "oraclelinux:latest"
    "oraclelinux:7"
    "archlinux:latest"
    "photon:latest"
    "clearlinux:latest"
    "rockylinux:latest"
    "alt:latest"
    "alt:7"
    "sl:latest"
)

# Loop through the images and run Dockerfile
for image in "${IMAGES[@]}"
do
  echo "Building image for $image ..."
  docker build --build-arg image=$image -t ffmpeg-test:$image -f Dockerfile .
  echo "Running ffmpeg -version on $image ..."
  docker run ffmpeg-test:$image /ffmpeg -version
done


