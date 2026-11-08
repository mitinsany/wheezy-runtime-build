#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
git init -q "$tmp/upstream"
printf 'source\n' > "$tmp/upstream/source.txt"
git -C "$tmp/upstream" add source.txt
git -C "$tmp/upstream" -c user.name=Test -c user.email=test@example.invalid commit -qm source
git init -q "$tmp/super"
git -C "$tmp/super" -c protocol.file.allow=always submodule add -q "$tmp/upstream" upstream/test
git -C "$tmp/super" -c user.name=Test -c user.email=test@example.invalid commit -qm pins
sh "$root/scripts/check-sources.sh" "$tmp/super" >/dev/null
printf 'unexpected\n' > "$tmp/super/upstream/test/untracked.txt"
if sh "$root/scripts/check-sources.sh" "$tmp/super" >/dev/null 2>&1; then
    echo 'Dirty source submodule was accepted' >&2
    exit 1
fi
echo 'source pin checks ok'
