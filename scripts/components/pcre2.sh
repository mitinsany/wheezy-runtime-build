#!/bin/sh
set -eu

: "${SRC:?}"
: "${WORK:?}"
: "${PREFIX:?}"
: "${NPROC:?}"

mkdir -p "$WORK"
build_dir=$(mktemp -d "$WORK/pcre2.XXXXXX")
cp -R "$SRC/upstream/pcre2/." "$build_dir/"
cd "$build_dir"

if [ ! -f configure ]; then
    sh ./autogen.sh
fi
CFLAGS="${CFLAGS:-} -O2 -m32 -march=i386 -mtune=generic" \
    ./configure --prefix="$PREFIX" --libdir="$PREFIX/lib"
make -j"$NPROC"
make install
