#!/bin/sh
set -eu

: "${SRC:?}"
: "${WORK:?}"
: "${PREFIX:?}"
: "${NPROC:?}"

mkdir -p "$WORK"
build_dir=$(mktemp -d "$WORK/sqlite.XXXXXX")
cd "$build_dir"

CFLAGS="${CFLAGS:-} -O2 -m32 -march=i386 -mtune=generic -DSQLITE_ENABLE_COLUMN_METADATA" \
    "$SRC/upstream/sqlite/configure" --prefix="$PREFIX" --disable-readline
make -j"$NPROC"
make install
