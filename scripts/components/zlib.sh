#!/bin/sh
set -eu

: "${SRC:?}"
: "${WORK:?}"
: "${PREFIX:?}"
: "${NPROC:?}"

mkdir -p "$WORK"
build_dir=$(mktemp -d "$WORK/zlib.XXXXXX")
cp -R "$SRC/upstream/zlib/." "$build_dir/"
cd "$build_dir"

CFLAGS="-O2 -std=c99" ./configure --prefix="$PREFIX"
make -j"$NPROC"
make test
make install
