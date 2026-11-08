#!/bin/sh
set -eu

: "${SRC:?}"
: "${WORK:?}"
: "${PREFIX:?}"
: "${NPROC:?}"

mkdir -p "$WORK"
build_dir=$(mktemp -d "$WORK/openssl.XXXXXX")
cp -R "$SRC/upstream/openssl/." "$build_dir/"
cd "$build_dir"

./Configure linux-x86 no-tests --prefix="$PREFIX" --openssldir=/etc/ssl --libdir=lib
make -j"$NPROC" MODULESDIR=/usr/lib/i386-linux-gnu/wheezy-runtime/ossl-modules
make install_sw
