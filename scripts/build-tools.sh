#!/bin/sh
set -eu

: "${WORK:?}"
: "${PREFIX:?}"
tool_prefix="$PREFIX/.bootstrap"
if [ -x "$tool_prefix/bin/re2c" ] && [ -x "$tool_prefix/bin/bison" ] && [ -x "$tool_prefix/bin/automake" ]; then
    exit 0
fi
mkdir -p "$WORK/tools"
cd "$WORK/tools"
tar xf /build-tools/automake.tar.xz
cd automake-1.16.5
./configure --prefix="$tool_prefix"
make -j"$NPROC"
make install
cd "$WORK/tools"
tar xf /build-tools/bison.tar.xz
cd bison-3.0.5
./configure --prefix="$tool_prefix"
make -j"$NPROC"
make install
cd "$WORK/tools"
tar xf /build-tools/re2c.tar.gz
cd re2c-1.0.3
./configure --prefix="$tool_prefix"
make -j"$NPROC"
make check
make install
