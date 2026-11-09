#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test -f "$root/site/index.html"
test -f "$root/site/archive-signing.asc"
grep -q 'site/index.html' "$root/.github/workflows/ci.yml"
grep -q 'fetch-previous.sh' "$root/.github/workflows/pages-only.yml"
if grep -q 'scripts/build.sh' "$root/.github/workflows/pages-only.yml"; then
    echo 'Pages-only deployment must not build packages' >&2
    exit 1
fi
