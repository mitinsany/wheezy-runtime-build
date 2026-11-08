#!/bin/sh
set -eu

: "${SRC:?}"
: "${WORK:?}"
: "${PREFIX:?}"
: "${NPROC:?}"

mkdir -p "$WORK"
build_dir=$(mktemp -d "$WORK/httpd.XXXXXX")
cp -R "$SRC/upstream/httpd/." "$build_dir/"
cd "$build_dir"

./buildconf --with-apr="$SRC/upstream/apr" --with-apr-util="$SRC/upstream/apr-util"
LDFLAGS="${LDFLAGS:-} -Wl,-rpath,$PREFIX/lib" \
    ./configure --prefix="$PREFIX/apache24" \
    --with-apr="$PREFIX/bin/apr-1-config" \
    --with-apr-util="$PREFIX/bin/apu-1-config" \
    --with-pcre="$PREFIX/bin/pcre2-config" \
    --with-mpm=prefork --enable-so --enable-mods-shared=most
make -j"$NPROC"
make install
