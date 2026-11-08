#!/bin/sh
set -eu

: "${SRC:?}"
: "${WORK:?}"
: "${PREFIX:?}"
: "${NPROC:?}"

mkdir -p "$WORK"
build_dir=$(mktemp -d "$WORK/oniguruma.XXXXXX")
cp -R "$SRC/upstream/oniguruma/." "$build_dir/"
cd "$build_dir"

if [ ! -f configure ]; then
    autoreconf -fi
fi
CFLAGS="${CFLAGS:-} -O2 -std=c99" \
    ./configure --prefix="$PREFIX" --libdir="$PREFIX/lib"
make -j"$NPROC"
make install
