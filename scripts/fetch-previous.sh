#!/bin/sh
set -eu

die() { printf '%s\n' "$*" >&2; exit 1; }
[ "$#" -eq 2 ] || die 'Usage: fetch-previous.sh BASE_URL OUTPUT_DIR'
base=${1%/}
output=$2
case "$base" in
    https://?*) ;;
    *) die 'BASE_URL must use HTTPS' ;;
esac
case "$base" in
    *[![:print:]]*|*' '*|*'?'*|*'#'*|*'@'*|*'\'*) die 'Invalid BASE_URL' ;;
esac
[ -n "$output" ] || die 'OUTPUT_DIR is required'
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fetch() {
    curl_status=0
    status=$(curl -q --fail --silent --show-error --location --proto '=https' \
        --proto-redir '=https' --output "$2" --write-out '%{http_code}' -- "$base/$1") || curl_status=$?
    [ "$curl_status" = 0 ] && [ "$status" = 200 ] && return 0
    [ "$1" = Release ] && [ "$curl_status" = 22 ] && [ "$status" = 404 ] && [ "${ALLOW_EMPTY:-0}" = 1 ] && return 2
    die "Failed to fetch $1 (HTTP ${status:-unknown})"
}

empty=0
fetch Release "$tmp/Release" || empty=$?
if [ "$empty" -eq 2 ]; then
    [ ! -L "$output" ] || die 'OUTPUT_DIR must not be a symlink'
    mkdir -p -- "$output"
    [ -d "$output" ] && [ -z "$(ls -A -- "$output")" ] || die 'OUTPUT_DIR must be empty'
    exit 0
fi
fetch Release.gpg "$tmp/Release.gpg"
gpg --no-options --batch --no-auto-key-retrieve --verify "$tmp/Release.gpg" "$tmp/Release" || die 'Release signature verification failed'
fetch Packages "$tmp/Packages"

awk '
    /^SHA256:$/ { section=1; next }
    /^[^[:space:]]/ { section=0 }
    section && $3 == "Packages" {
        if (NF != 3 || length($1) != 64 || $1 !~ /^[[:xdigit:]]+$/ || $2 !~ /^[0-9]+$/) exit 1
        count++; hash=tolower($1); size=$2
    }
    END { if (count != 1) exit 1; print hash, size }
' "$tmp/Release" > "$tmp/index-check" || die 'Invalid Packages checksum in Release'
read -r expected_hash expected_size < "$tmp/index-check"
actual_hash=$(sha256sum "$tmp/Packages" | awk '{print $1}')
actual_size=$(wc -c < "$tmp/Packages" | tr -d '[:space:]')
[ "$actual_hash" = "$expected_hash" ] && [ "$actual_size" = "$expected_size" ] || die 'Packages checksum or size mismatch'

awk '
    function finish( name) {
        if (!active) return
        if (filename_count != 1 || hash_count != 1 || size_count != 1) exit 1
        if (filename !~ /^\.\/[A-Za-z0-9][A-Za-z0-9+._~-]*\.deb$/) exit 1
        name=substr(filename, 3)
        if (seen[name]++) exit 1
        if (length(hash) != 64 || hash !~ /^[[:xdigit:]]+$/ || size !~ /^[0-9]+$/) exit 1
        print tolower(hash), size, name
        active=filename_count=hash_count=size_count=0; filename=hash=size=""
    }
    /^$/ { finish(); next }
    { active=1 }
    /^Filename:/ { filename_count++; if (NF != 2) exit 1; filename=$2 }
    /^SHA256:/ { hash_count++; if (NF != 2) exit 1; hash=$2 }
    /^Size:/ { size_count++; if (NF != 2) exit 1; size=$2 }
    END { finish() }
' "$tmp/Packages" > "$tmp/manifest" || die 'Invalid package index'
awk '{ total += $2 } END { if (total > 850000000) exit 1 }' "$tmp/manifest" || die 'Existing snapshot exceeds the retention limit'

while read -r hash size name; do
    fetch "$name" "$tmp/$name"
    actual_hash=$(sha256sum "$tmp/$name" | awk '{print $1}')
    actual_size=$(wc -c < "$tmp/$name" | tr -d '[:space:]')
    [ "$actual_hash" = "$hash" ] && [ "$actual_size" = "$size" ] || die "Checksum or size mismatch: $name"
done < "$tmp/manifest"

[ ! -L "$output" ] || die 'OUTPUT_DIR must not be a symlink'
mkdir -p -- "$output"
[ -d "$output" ] && [ -z "$(ls -A -- "$output")" ] || die 'OUTPUT_DIR must be empty'
cp -- "$tmp/Release" "$tmp/Release.gpg" "$tmp/Packages" "$output/"
while read -r hash size name; do cp -- "$tmp/$name" "$output/"; done < "$tmp/manifest"
