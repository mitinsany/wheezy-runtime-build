#!/bin/sh
set -eu

: "${SRC:?}"
: "${WORK:?}"
: "${PREFIX:?}"
: "${NPROC:?}"

build_dir=$(mktemp -d "$WORK/redis.XXXXXX")
cp -R "$SRC/upstream/redis/." "$build_dir/"
cd "$build_dir"
make -j"$NPROC" MALLOC=libc BUILD_TLS=no
mkdir -p "$PREFIX/bin"
cp src/redis-server src/redis-cli "$PREFIX/bin/"
