#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/stage/lib/ossl-modules" "$tmp/stage/bin" "$tmp/stage/apache24/bin" \
    "$tmp/stage/apache24/modules" "$tmp/stage/share/snmp/mibs" "$tmp/bin"
for file in libz.so.1 libsqlite3.so libcrypto.so.3 libssl.so.3 libcurl.so.4 \
    libnetsnmp.so.45 libxml2.so.16 libonig.so.5 libpcre2-8.so.0 libapr-1.so.0 libaprutil-1.so.0; do
    touch "$tmp/stage/lib/$file"
done
touch "$tmp/stage/bin/php" "$tmp/stage/bin/openssl" "$tmp/stage/lib/ossl-modules/legacy.so" \
    "$tmp/stage/apache24/bin/httpd" "$tmp/stage/apache24/modules/libphp.so"
printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/patchelf"
printf '#!/bin/sh\nprintf "TEXTREL\\n"\n' > "$tmp/bin/readelf"
chmod +x "$tmp/bin/patchelf" "$tmp/bin/readelf"
if PATH="$tmp/bin:$PATH" STAGE="$tmp/stage" sh "$root/scripts/package.sh" > "$tmp/log" 2>&1; then
    echo 'A module with text relocations was accepted' >&2
    exit 1
fi
grep -q 'unsafe text relocations' "$tmp/log" || { cat "$tmp/log" >&2; exit 1; }
echo 'package guards ok'
