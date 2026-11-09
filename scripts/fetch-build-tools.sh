#!/bin/sh
set -eu

: "${TOOLS_DIR:?Set TOOLS_DIR to an empty directory}"
mkdir -p "$TOOLS_DIR"
curl -fsSL --retry 3 --connect-timeout 15 --max-time 120 -o "$TOOLS_DIR/bison.tar.xz" https://ftp.gnu.org/gnu/bison/bison-3.0.5.tar.xz
curl -fsSL --retry 3 --connect-timeout 15 --max-time 120 -o "$TOOLS_DIR/re2c.tar.gz" https://github.com/skvadrik/re2c/releases/download/1.0.3/re2c-1.0.3.tar.gz
curl -fsSL --retry 3 --connect-timeout 15 --max-time 120 -o "$TOOLS_DIR/automake.tar.xz" https://ftp.gnu.org/gnu/automake/automake-1.16.5.tar.xz
curl -fsSL --retry 3 --connect-timeout 15 --max-time 120 -o "$TOOLS_DIR/apt.tar.gz" 'https://archive.debian.org/debian/pool/main/a/apt/apt_0.9.7.9+deb7u7.tar.gz'
(
    cd "$TOOLS_DIR"
    printf '%s\n' \
        '075cef2e814642e30e10e8155e93022e4a91ca38a65aa1d5467d4e969f97f338  bison.tar.xz' \
        'cf56e0de3f335f6a22d3e8c06b8b450d858a4e7875ea1b01c9233e084b90cb52  re2c.tar.gz' \
        'f01d58cd6d9d77fbdca9eb4bbd5ead1988228fdb73d6f7a201f5f8d6b118b469  automake.tar.xz' \
        '16816387711ee428d94a940bd3223fb7149c39666dd1cdc9633fbfbbe8933cb8  apt.tar.gz' | sha256sum -c -
)
