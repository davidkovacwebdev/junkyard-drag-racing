#!/bin/sh
# Cross-builds junk_native.dll for the "Windows Desktop" export from a Mac,
# and copies it to where junk_native.gdextension looks for it.
# Needs (once): rustup target add x86_64-pc-windows-gnu
#               python3 -m pip install --user ziglang
#               cargo install cargo-zigbuild
set -e
cd "$(dirname "$0")"
. "$HOME/.cargo/env" 2>/dev/null || true
TARGET=x86_64-pc-windows-gnu
cargo zigbuild --release --target $TARGET
# Debug exports: no debug symbols, or the DLL is ~200 MB.
CARGO_PROFILE_DEV_DEBUG=false CARGO_PROFILE_DEV_STRIP=true cargo zigbuild --target $TARGET
mkdir -p target/release target/debug
cp target/$TARGET/release/junk_native.dll target/release/
cp target/$TARGET/debug/junk_native.dll target/debug/
echo "junk_native.dll copied to rust/target/release and rust/target/debug"
