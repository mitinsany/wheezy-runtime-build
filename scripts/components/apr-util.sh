#!/bin/sh
set -eu

: "${SRC:?}"
: "${WORK:?}"
: "${PREFIX:?}"
: "${NPROC:?}"

mkdir -p "$WORK"
build_dir=$(mktemp -d "$WORK/apr-util.XXXXXX")
cp -R "$SRC/upstream/apr-util/." "$build_dir/"
cd "$build_dir"

./buildconf --with-apr="$SRC/upstream/apr"
LDFLAGS="${LDFLAGS:-} -Wl,-rpath,$PREFIX/lib" \
    ./configure --prefix="$PREFIX" --libdir="$PREFIX/lib" \
    --with-apr="$PREFIX/bin/apr-1-config"
make -j"$NPROC"
make install
