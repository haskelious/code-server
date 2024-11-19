#!/bin/env bash

# install recommended packages into the environment
nix-env -f '<nixpkgs>' -iA nodejs yarn

# install recommended VSCode extensions
code-server --install-extension dbaeumer.vscode-eslint
code-server --install-extension esbenp.prettier-vscode
