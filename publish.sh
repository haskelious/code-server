#! /usr/bin/env bash

docker=podman

# login to docker with a PAT token
echo "enter your dockerhub PAT token"
${docker} login -u haskelious

# tag the image to publish
${docker} tag localhost/code-server:latest haskelious/code-server:latest

# push the image
${docker} push haskelious/code-server:latest
