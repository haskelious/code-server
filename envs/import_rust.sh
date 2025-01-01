#!/bin/env bash

# install recommended packages into the environment
nix-env -f channel:nixpkgs-unstable --log-format bar -iA clang lld cmake gnumake rustup

# install altenative linker
nix-env -f channel:nixos-24.11 --log-format bar -iA mold
mkdir -p ~/.cargo && cat > ~/.cargo/cargo.toml << EOF
[target.x86_64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=/path/to/mold"]
EOF

# use rustup to install the toolchain
rustup toolchain install stable
rustup component add rust-analyzer
cargo install cargo-expand

# install recommended VSCode extensions
code-server --install-extension rust-lang.rust-analyzer
code-server --install-extension vadimcn.vscode-lldb
code-server --install-extension usernamehw.errorlens
code-server --install-extension tamasfe.even-better-toml
code-server --install-extension fill-labs.dependi

# replace the rust-analyzer binary in the code-server extension folder
ln -sf ~/.nix-profile/bin/rust-analyzer ~/.local/share/code-server/extensions/rust-lang.rust-analyzer-*/server/
