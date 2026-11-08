#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test -f "$root/scripts/build.sh"
components=$(sh "$root/scripts/build.sh" --list)
for name in zlib openssl sqlite pcre2 oniguruma libxml2 curl net-snmp apr apr-util httpd php; do
    printf '%s\n' "$components" | grep -Fx "$name" >/dev/null || {
        echo "missing build component: $name" >&2
        exit 1
    }
done
if sh "$root/scripts/build.sh" --component invalid >/dev/null 2>&1; then
    echo 'unknown component accepted' >&2
    exit 1
fi
echo 'build contract ok'
