#!/bin/sh
set -eu

: "${SRC:?}"
: "${WORK:?}"
: "${PREFIX:?}"
: "${NPROC:?}"

mkdir -p "$WORK"
build_dir=$(mktemp -d "$WORK/libxml2.XXXXXX")
cp -R "$SRC/upstream/libxml2/." "$build_dir/"
cd "$build_dir"

if [ ! -f configure ]; then
    autoreconf -fi
fi
CFLAGS="${CFLAGS:-} -O2 -std=c99" \
CPPFLAGS="${CPPFLAGS:-} -I$PREFIX/include" \
LDFLAGS="${LDFLAGS:-} -L$PREFIX/lib -Wl,-rpath,$PREFIX/lib" \
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" \
    ./configure --prefix="$PREFIX" --libdir="$PREFIX/lib" \
    --without-python --without-lzma --with-zlib="$PREFIX"
make -j"$NPROC"
make install
