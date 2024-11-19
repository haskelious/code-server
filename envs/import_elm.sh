#!/bin/env bash

# install recommended packages into the environment
nix-env -f '<nixpkgs>' -iA elmPackages.elm

# install recommended VSCode extensions
code-server --install-extension elmtooling.elm-ls-vscode
