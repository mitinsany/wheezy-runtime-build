#!/bin/sh
set -eu

mkdir -p "$WORK/apt-https"
tar -xzf /build-tools/apt.tar.gz --strip-components=1 -C "$WORK/apt-https"
cd "$WORK/apt-https"
patch -p1 < "$SRC/scripts/apt-https-redirect.patch"
CPPFLAGS="-I$PREFIX/include" LDFLAGS="-L$PREFIX/lib" ./configure --build=i686-pc-linux-gnu
mkdir -p "$PREFIX/bin" "$PREFIX/share/licenses/apt"
g++ -Iinclude -I"$PREFIX/include" methods/https.cc -o "$PREFIX/bin/apt-https-wr" \
    -L"$PREFIX/lib" -lapt-pkg -lcurl
cp COPYING "$PREFIX/share/licenses/apt/COPYING"
