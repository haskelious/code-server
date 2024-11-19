#!/bin/env bash

# install recommended packages into the environment
nix-env -f '<nixpkgs>' -iA wget glibc gnumake ghc stack hlint haskell-language-server haskellPackages.cabal-install

# install recommended VSCode extensions
code-server --install-extension haskell.haskell
