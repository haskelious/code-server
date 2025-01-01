#!/bin/env bash

# install recommended packages into the environment
nix-env -f channel:nixpkgs-unstable --log-format bar -iA nodejs yarn

# install recommended VSCode extensions
code-server --install-extension dbaeumer.vscode-eslint
code-server --install-extension esbenp.prettier-vscode
