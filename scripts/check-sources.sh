#!/bin/sh
set -eu

repo=${1:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
status=$(git -C "$repo" submodule status) || exit 1
[ -n "$status" ] || { echo 'No source submodules' >&2; exit 1; }
if printf '%s\n' "$status" | grep -Eq '^[-+U]'; then
    echo 'Source submodules are missing or do not match their pins' >&2
    exit 1
fi
if [ -n "$(git -C "$repo" status --porcelain -- .gitmodules upstream)" ]; then
    echo 'Source pins or submodules have uncommitted changes' >&2
    exit 1
fi
git -C "$repo" submodule foreach --quiet \
    'test -z "$(git status --porcelain --untracked-files=all)" || { echo "Dirty source: $displaypath" >&2; exit 1; }'
printf '%s\n' "$status"
