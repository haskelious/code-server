#!/bin/env bash

# install recommended packages into the environment
nix-env -f '<nixpkgs>' --log-format bar -iA clang rustup

# use rustup to install the toolchain
rustup toolchain install stable
rustup component add rust-analyzer

# install recommended VSCode extensions
code-server --install-extension rust-lang.rust-analyzer
code-server --install-extension vadimcn.vscode-lldb

# replace the rust-analyzer binary in the code-server extension folder
ln -sf ~/.nix-profile/bin/rust-analyzer ~/.local/share/code-server/extensions/rust-lang.rust-analyzer-*/server/
