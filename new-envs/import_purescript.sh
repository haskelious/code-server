#!/bin/env bash

# install recommended packages into the environment
nix-env -f '<nixpkgs>' -iA spago purescript
