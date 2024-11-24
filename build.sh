#! /usr/bin/env bash

docker=podman

# build nix-base docker image
nix-build -I nixpkgs=channel:nixos-unstable --quiet --log-format bar code-server.nix && \

# import image
${docker} load -i ./result && \

# clean up nix artifact
rm ./result
