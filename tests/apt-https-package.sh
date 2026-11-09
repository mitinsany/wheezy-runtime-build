#!/bin/sh
set -eu

dir=${PACKAGE_DIR:-"$(CDPATH= cd -- "$(dirname -- "$0")/../out/debs" && pwd)"}
set -- "$dir"/wr-apt-https_*.deb
[ -f "$1" ] || { echo 'Missing wr-apt-https package' >&2; exit 1; }
test "$#" -eq 1
deb=$1
dpkg-deb -f "$deb" Depends | grep -q 'wr-curl'
contents=$(dpkg-deb -c "$deb")
printf '%s\n' "$contents" | grep -q './usr/lib/wheezy-runtime/apt/methods/https$'
if printf '%s\n' "$contents" | grep -q './usr/lib/apt/methods/https$'; then
    echo 'Package must not replace the system HTTPS method' >&2
    exit 1
fi
