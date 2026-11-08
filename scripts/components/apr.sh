#!/bin/sh
set -eu

: "${SRC:?}"
: "${WORK:?}"
: "${PREFIX:?}"
: "${NPROC:?}"

mkdir -p "$WORK"
build_dir=$(mktemp -d "$WORK/apr.XXXXXX")
cp -R "$SRC/upstream/apr/." "$build_dir/"
cd "$build_dir"

./buildconf
LDFLAGS="${LDFLAGS:-} -Wl,-rpath,$PREFIX/lib" \
    ./configure --prefix="$PREFIX" --libdir="$PREFIX/lib"
make -j"$NPROC"
make install
