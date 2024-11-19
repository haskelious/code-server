#!/bin/env bash

# install recommended packages into the environment
nix-env -f '<nixpkgs>' -iA clang rustc cargo clippy rustfmt rust-analyzer

# install recommended VSCode extensions
code-server --install-extension rust-lang.rust-analyzer && \

# replace the rust-analyzer binary in the code-server extension folder
ln -sf ~/.nix-profile/bin/rust-analyzer ~/.local/share/code-server/extensions/rust-lang.rust-analyzer-*/server/
