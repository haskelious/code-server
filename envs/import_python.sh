#!/bin/env bash

# install recommended packages into the environment
nix-env -f '<nixpkgs>' -iA python3

# install recommended VSCode extensions
code-server --install-extension ms-python.python
code-server --install-extension ms-python.debugpy
