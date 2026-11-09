#!/bin/sh
set -eu

: "${STAGE:?Set STAGE to the completed build output}"
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=${PACKAGE_VERSION:-0.1.0~experimental1}
case "$VERSION" in *[!A-Za-z0-9.+:~_-]*|'') echo 'Invalid package version' >&2; exit 1 ;; esac
command -v patchelf >/dev/null || { echo 'patchelf is required' >&2; exit 1; }
command -v dpkg-deb >/dev/null || { echo 'dpkg-deb is required' >&2; exit 1; }
command -v readelf >/dev/null || { echo 'readelf is required' >&2; exit 1; }
for file in lib/libz.so.1 lib/libsqlite3.so lib/libcrypto.so.3 lib/libssl.so.3 \
    lib/libcurl.so.4 lib/libnetsnmp.so.45 lib/libxml2.so.16 lib/libonig.so.5 \
    lib/libpcre2-8.so.0 lib/libapr-1.so.0 lib/libaprutil-1.so.0 \
    bin/php bin/openssl bin/apt-https-wr share/licenses/apt/COPYING lib/ossl-modules/legacy.so apache24/bin/httpd apache24/modules/libphp.so share/snmp/mibs; do
    test -e "$STAGE/$file" || { echo "Missing build output: $file" >&2; exit 1; }
done
if readelf -d "$STAGE/apache24/modules/libphp.so" | grep -q TEXTREL; then
    echo 'PHP Apache module has unsafe text relocations' >&2
    exit 1
fi
FINAL_OUT="$ROOT/out/debs"
test ! -e "$FINAL_OUT" || { echo 'Output already exists; move it before rebuilding' >&2; exit 1; }
OUT=$(mktemp -d "$ROOT/out/.debs.XXXXXX")
WORK=$(mktemp -d "$ROOT/out/packages.XXXXXX")

patch_needed() {
    patchelf --replace-needed libz.so.1 libz.so.2 \
        --replace-needed libcurl.so.4 libcurl.so.8 \
        --replace-needed libsqlite3.so libsqlite3.so.3 \
        --replace-needed libsqlite3.so.0 libsqlite3.so.3 \
        --replace-needed libapr-1.so.0 libapr-1.so.1 \
        --replace-needed libaprutil-1.so.0 libaprutil-1.so.1 \
        --remove-rpath "$1"
}
newpkg() {
    PKG=$1 DEP=$2 DESC=$3
    DIR="$WORK/$PKG"
    mkdir -p "$DIR/DEBIAN" "$DIR/usr/lib/i386-linux-gnu"
    if [ -n "${SOURCE_MANIFEST:-}" ]; then
        mkdir -p "$DIR/usr/share/doc/$PKG"
        cp "$SOURCE_MANIFEST" "$DIR/usr/share/doc/$PKG/source-revisions.txt"
    fi
    printf 'Package: %s\nVersion: %s\nArchitecture: i386\nMaintainer: Runtime Packaging <noreply@localhost>\nDepends: %s\nSection: libs\nPriority: optional\nDescription: Experimental Wheezy runtime: %s\n Not production-ready; intended for isolated compatibility testing.\n' \
        "$PKG" "$VERSION" "$DEP" "$DESC" > "$DIR/DEBIAN/control"
}
finish() {
    dpkg-deb -Zgzip -z6 --build --root-owner-group "$DIR" "$OUT/${PKG}_${VERSION}_i386.deb"
}
license() {
    mkdir -p "$DIR/usr/share/doc/$PKG"
    cp "$ROOT/upstream/$1/$2" "$DIR/usr/share/doc/$PKG/copyright"
}
libpkg() {
    newpkg "$1" "$2" "$3"
    source=$4 real=$5 soname=$6
    cp -L "$STAGE/lib/$source" "$DIR/usr/lib/i386-linux-gnu/$real"
    patchelf --set-soname "$soname" "$DIR/usr/lib/i386-linux-gnu/$real"
    patch_needed "$DIR/usr/lib/i386-linux-gnu/$real"
    if [ "$real" != "$soname" ]; then ln -s "$real" "$DIR/usr/lib/i386-linux-gnu/$soname"; fi
}

libpkg wr-zlib 'libc6 (>= 2.13)' 'zlib' libz.so.1 libz.so.1.4 libz.so.2; license zlib LICENSE; finish
libpkg wr-sqlite "libc6 (>= 2.13), wr-zlib (= $VERSION)" 'SQLite' libsqlite3.so libsqlite3.so.3.54.1 libsqlite3.so.3; license sqlite LICENSE.md; finish
newpkg wr-openssl 'libc6 (>= 2.13)' 'OpenSSL'
for lib in libcrypto.so.3 libssl.so.3; do cp -L "$STAGE/lib/$lib" "$DIR/usr/lib/i386-linux-gnu/$lib"; patch_needed "$DIR/usr/lib/i386-linux-gnu/$lib"; done
mkdir -p "$DIR/usr/local/bin"
cp "$STAGE/bin/openssl" "$DIR/usr/local/bin/openssl-wheezy"
patch_needed "$DIR/usr/local/bin/openssl-wheezy"
mkdir -p "$DIR/usr/lib/i386-linux-gnu/wheezy-runtime/ossl-modules"
cp "$STAGE/lib/ossl-modules/legacy.so" "$DIR/usr/lib/i386-linux-gnu/wheezy-runtime/ossl-modules/legacy.so"
patch_needed "$DIR/usr/lib/i386-linux-gnu/wheezy-runtime/ossl-modules/legacy.so"
license openssl LICENSE.txt
finish
libpkg wr-curl "libc6 (>= 2.13), wr-zlib (= $VERSION), wr-openssl (= $VERSION)" 'cURL' libcurl.so.4 libcurl.so.4.8.0 libcurl.so.8; license curl COPYING; finish
newpkg wr-apt-https "libc6 (>= 2.13), libgcc1, libstdc++6, libapt-pkg4.12, ca-certificates, wr-curl (= $VERSION)" 'Optional APT HTTPS method'
mkdir -p "$DIR/usr/lib/wheezy-runtime/apt/methods" "$DIR/usr/share/doc/$PKG"
cp "$STAGE/bin/apt-https-wr" "$DIR/usr/lib/wheezy-runtime/apt/methods/https"
patch_needed "$DIR/usr/lib/wheezy-runtime/apt/methods/https"
for method in bzip2 cdrom copy file ftp gpgv gzip http lzma mirror rred rsh ssh xz; do
    ln -s "/usr/lib/apt/methods/$method" "$DIR/usr/lib/wheezy-runtime/apt/methods/$method"
done
cp "$STAGE/share/licenses/apt/COPYING" "$DIR/usr/share/doc/$PKG/copyright"
finish
libpkg wr-snmp "libc6 (>= 2.13), wr-openssl (= $VERSION)" 'Net-SNMP' libnetsnmp.so.45 libnetsnmp.so.45 libnetsnmp.so.45
mkdir -p "$DIR/usr/share/wheezy-runtime/snmp"
cp -a "$STAGE/share/snmp/mibs" "$DIR/usr/share/wheezy-runtime/snmp/"
mkdir -p "$DIR/var/lib/wheezy-runtime/snmp"
mkdir -p "$DIR/etc/wheezy-runtime/snmp"
license net-snmp COPYING
finish
libpkg wr-xml "libc6 (>= 2.13), wr-zlib (= $VERSION)" 'libxml2' libxml2.so.16 libxml2.so.16 libxml2.so.16; license libxml2 Copyright; finish
libpkg wr-oniguruma 'libc6 (>= 2.13)' 'Oniguruma' libonig.so.5 libonig.so.5 libonig.so.5; license oniguruma COPYING; finish
libpkg wr-pcre2 'libc6 (>= 2.13)' 'PCRE2' libpcre2-8.so.0 libpcre2-8.so.0 libpcre2-8.so.0; license pcre2 LICENCE.md; finish
libpkg wr-apr 'libc6 (>= 2.13), libuuid1' 'APR' libapr-1.so.0 libapr-1.so.0.7.6 libapr-1.so.1; license apr LICENSE; finish
libpkg wr-aprutil "libc6 (>= 2.13), libexpat1, wr-apr (= $VERSION)" 'APR-util' libaprutil-1.so.0 libaprutil-1.so.0.6.6 libaprutil-1.so.1; license apr-util LICENSE; finish

PHP_DEPS="libc6 (>= 2.13), libbz2-1.0, wr-zlib (= $VERSION), wr-sqlite (= $VERSION), wr-openssl (= $VERSION), wr-curl (= $VERSION), wr-snmp (= $VERSION), wr-xml (= $VERSION), wr-oniguruma (= $VERSION)"
newpkg wr-php84 "$PHP_DEPS" 'PHP CLI'
mkdir -p "$DIR/usr/local/bin"
mkdir -p "$DIR/etc/wheezy-php84/conf.d" "$DIR/usr/local/wheezy-php84/lib"
cp "$STAGE/bin/php" "$DIR/usr/local/bin/php84-wheezy"
patch_needed "$DIR/usr/local/bin/php84-wheezy"
license php LICENSE
finish

newpkg wr-apache24 "libc6 (>= 2.13), libexpat1, libuuid1, wr-apr (= $VERSION), wr-aprutil (= $VERSION), wr-pcre2 (= $VERSION)" 'Apache HTTP Server; no service is enabled'
mkdir -p "$DIR/opt/wheezy-httpd/bin" "$DIR/opt/wheezy-httpd/modules"
cp "$STAGE/apache24/bin/httpd" "$DIR/opt/wheezy-httpd/bin/httpd"
patch_needed "$DIR/opt/wheezy-httpd/bin/httpd"
for mod in mod_unixd.so mod_authz_core.so mod_mime.so mod_dir.so mod_rewrite.so; do
    cp "$STAGE/apache24/modules/$mod" "$DIR/opt/wheezy-httpd/modules/$mod"
    patch_needed "$DIR/opt/wheezy-httpd/modules/$mod"
done
license httpd LICENSE
finish

newpkg wr-apache-php84 "wr-apache24 (= $VERSION), $PHP_DEPS" 'PHP Apache module'
mkdir -p "$DIR/opt/wheezy-httpd/modules"
cp "$STAGE/apache24/modules/libphp.so" "$DIR/opt/wheezy-httpd/modules/libphp.so"
patch_needed "$DIR/opt/wheezy-httpd/modules/libphp.so"
license php LICENSE
finish
mv "$OUT" "$FINAL_OUT"
echo "Packages: $FINAL_OUT"
