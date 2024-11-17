#! /usr/bin/env bash

docker=podman

${docker} run -ti -p 8443:8443 -v ./nix:/home/nix --userns keep-id:uid=1000,gid=100 code-server:latest
