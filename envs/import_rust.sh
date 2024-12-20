#!/bin/env bash

# install recommended packages into the environment
nix-env -f '<nixpkgs>' --log-format bar -iA clang cmake gnumake rustup

# use rustup to install the toolchain
rustup toolchain install stable
rustup component add rust-analyzer

# install recommended VSCode extensions
code-server --install-extension rust-lang.rust-analyzer
code-server --install-extension vadimcn.vscode-lldb
code-server --install-extension usernamehw.errorlens
code-server --install-extension tamasfe.even-better-toml
code-server --install-extension fill-labs.dependi

# replace the rust-analyzer binary in the code-server extension folder
ln -sf ~/.nix-profile/bin/rust-analyzer ~/.local/share/code-server/extensions/rust-lang.rust-analyzer-*/server/
