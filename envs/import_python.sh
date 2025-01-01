#!/bin/env bash

# install recommended packages into the environment
nix-env -f channel:nixpkgs-unstable --log-format bar -iA python3

# install recommended VSCode extensions
code-server --install-extension ms-python.python
code-server --install-extension ms-python.debugpy
