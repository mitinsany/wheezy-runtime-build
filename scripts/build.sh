#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
COMPONENTS='zlib openssl sqlite pcre2 oniguruma libxml2 curl apt-https net-snmp apr apr-util httpd php'
COMPONENT=all
case "${1:-}" in
    --list) printf '%s\n' $COMPONENTS; exit 0 ;;
    --component)
        test "$#" -eq 2 || { echo 'Expected one component' >&2; exit 2; }
        COMPONENT=$2
        case " $COMPONENTS " in *" $COMPONENT "*) ;; *) echo 'Unknown component' >&2; exit 2 ;; esac
        ;;
    '') ;;
    *) echo 'Usage: build.sh [--list | --component NAME]' >&2; exit 2 ;;
esac

for name in $COMPONENTS; do
    test -f "$ROOT/scripts/components/$name.sh" || {
        echo "Build is incomplete: missing $name component" >&2
        exit 1
    }
    [ "$name" = "$COMPONENT" ] && break
done
if [ "$COMPONENT" = all ]; then
    test -f "$ROOT/scripts/package.sh" || { echo 'Packaging is incomplete' >&2; exit 1; }
    command -v patchelf >/dev/null || { echo 'patchelf is required for packaging' >&2; exit 1; }
    command -v dpkg-deb >/dev/null || { echo 'dpkg-deb is required for packaging' >&2; exit 1; }
    sh "$ROOT/scripts/check-sources.sh" "$ROOT" >/dev/null
fi

mkdir -p "$ROOT/out"
build_dir=$(mktemp -d "$ROOT/out/build.XXXXXX")
if [ "$COMPONENT" = all ]; then
    sh "$ROOT/scripts/check-sources.sh" "$ROOT" > "$build_dir/source-revisions.txt"
    printf '%s\n' 'apt 0.9.7.9+deb7u7 sha256:16816387711ee428d94a940bd3223fb7149c39666dd1cdc9633fbfbbe8933cb8' >> "$build_dir/source-revisions.txt"
fi
mkdir -p "$build_dir/stage" "$build_dir/tools"
if [ "$COMPONENT" != zlib ] && [ "$COMPONENT" != openssl ]; then
    TOOLS_DIR="$build_dir/tools" sh "$ROOT/scripts/fetch-build-tools.sh"
fi
docker build --platform linux/386 -t wheezy-runtime-builder -f "$ROOT/docker/Dockerfile" "$ROOT"
docker run --rm --platform linux/386 --user "$(id -u):$(id -g)" \
    --tmpfs /work:rw,exec,mode=1777 -v "$ROOT:/src:ro" -v "$build_dir/stage:/stage" \
    -v "$build_dir/tools:/build-tools:ro" \
    -e COMPONENT="$COMPONENT" wheezy-runtime-builder sh /src/scripts/in-container.sh
if [ "$COMPONENT" = all ]; then
    SOURCE_MANIFEST="$build_dir/source-revisions.txt" STAGE="$build_dir/stage" sh "$ROOT/scripts/package.sh"
else
    echo "Build output: $build_dir/stage"
fi
