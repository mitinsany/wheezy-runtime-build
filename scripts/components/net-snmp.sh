#!/bin/sh
set -eu

src="$WORK/net-snmp"
cp -R "$SRC/upstream/net-snmp" "$src"
cd "$src"
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" \
CPPFLAGS="-I$PREFIX/include" \
LDFLAGS="-L$PREFIX/lib -Wl,-rpath,$PREFIX/lib" \
./configure --prefix="$PREFIX" --sysconfdir=/etc/wheezy-runtime --datadir=/usr/share/wheezy-runtime --with-openssl \
    --disable-agent --disable-applications --disable-embedded-perl \
    --without-perl-modules --disable-manuals \
    --with-default-snmp-version=2 --with-sys-contact=admin@localhost \
    --with-sys-location=local --with-logfile=/dev/null \
    --with-persistent-directory=/var/lib/wheezy-runtime/snmp
make -j"$NPROC"
dest="$WORK/net-snmp-install"
make install DESTDIR="$dest"
cp -a "$dest$PREFIX/." "$PREFIX/"
mkdir -p "$PREFIX/share/snmp"
cp -a "$dest/usr/share/wheezy-runtime/snmp/mibs" "$PREFIX/share/snmp/"
