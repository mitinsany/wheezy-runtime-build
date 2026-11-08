#!/bin/sh
set -eu

export SRC=/src WORK=/work PREFIX=/stage NPROC=${NPROC:-2}
mkdir -p "$WORK" "$PREFIX"
LD_LIBRARY_PATH="$PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH
if [ "$COMPONENT" != zlib ] && [ "$COMPONENT" != openssl ]; then
    sh "$SRC/scripts/build-tools.sh"
    PATH="$PREFIX/.bootstrap/bin:$PATH"
    export PATH
    ACLOCAL_PATH=/usr/share/aclocal
    export ACLOCAL_PATH
fi
components='zlib openssl sqlite pcre2 oniguruma libxml2 curl net-snmp apr apr-util httpd php'
for component in $components; do
    echo "Building $component"
    sh "$SRC/scripts/components/$component.sh"
    if [ "$component" = "$COMPONENT" ]; then break; fi
done
