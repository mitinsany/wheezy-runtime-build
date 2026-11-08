#!/bin/sh
set -eu
export LC_ALL=C

fail() { echo "retain-packages: $*" >&2; exit 1; }
[ "$#" -eq 3 ] || fail 'usage: retain-packages.sh PREVIOUS_DIR NEW_DEBS_DIR OUTPUT_DIR'
[ -n "${GNUPGHOME:-}" ] && [ -d "$GNUPGHOME" ] || fail 'GNUPGHOME must contain the trusted signer key'
for dir in "$1" "$2" "$3"; do
    [ -d "$dir" ] && [ ! -L "$dir" ] || fail "directory missing or symbolic link: $dir"
done
previous=$(CDPATH= cd -- "$1" && pwd -P)
new=$(CDPATH= cd -- "$2" && pwd -P)
output=$(CDPATH= cd -- "$3" && pwd -P)
case "$previous/" in "$output/"*) fail 'output overlaps previous directory';; esac
case "$output/" in "$previous/"*) fail 'output overlaps previous directory';; esac
case "$new/" in "$output/"*) fail 'output overlaps new directory';; esac
case "$output/" in "$new/"*) fail 'output overlaps new directory';; esac
[ -z "$(ls -A "$output")" ] || fail 'output directory must be empty'
tmp=$(mktemp -d "${TMPDIR:-/tmp}/retain-packages.XXXXXXXX")
publish=''
trap 'rm -rf "$tmp"; if [ -n "$publish" ]; then rm -rf "$publish"; fi' EXIT HUP INT TERM
mkdir "$tmp/packages"

if [ -n "$(ls -A "$previous")" ]; then
    for file in Release Release.gpg Packages; do
        [ -f "$previous/$file" ] && [ ! -L "$previous/$file" ] || fail "missing or unsafe $file"
        cp "$previous/$file" "$tmp/$file"
    done
    gpg --batch --no-auto-key-retrieve --verify "$tmp/Release.gpg" "$tmp/Release" >/dev/null 2>&1 || fail 'invalid Release signature'
    awk '
        /^SHA256:$/ { if (++sections != 1) exit 1; in_sha = 1; next }
        /^[^ \t]/ { in_sha = 0 }
        in_sha && NF && ($3 == "Packages" || $3 == "./Packages") {
            if (NF != 3 || ++count != 1 || length($1) != 64 || $1 ~ /[^0-9a-fA-F]/ || $2 !~ /^[0-9]+$/) exit 1
            print tolower($1), $2
        }
        END { if (sections != 1 || count != 1) exit 1 }
    ' "$tmp/Release" > "$tmp/index-hash" || fail 'invalid Packages checksum in Release'
    read -r expected_hash expected_size < "$tmp/index-hash"
    actual_hash=$(sha256sum "$tmp/Packages")
    actual_hash=${actual_hash%% *}
    actual_size=$(wc -c < "$tmp/Packages" | tr -d ' ')
    [ "$actual_hash" = "$expected_hash" ] && [ "$actual_size" = "$expected_size" ] || fail 'Packages checksum or size mismatch'

    awk '
        function finish() {
            if (!fields) return
            if (filenames != 1 || hashes != 1 || filename !~ /^\.\/[A-Za-z0-9][A-Za-z0-9.+_~:-]*\.deb$/ ||
                length(hash) != 64 || hash ~ /[^0-9a-fA-F]/ || seen[filename]++) exit 1
            print substr(filename, 3), tolower(hash)
            fields = filenames = hashes = 0; filename = hash = ""
        }
        /\r/ { exit 1 }
        /^[ \t]/ { if (last == "Filename" || last == "SHA256") exit 1; next }
        /^$/ { finish(); last = ""; next }
        !/^[A-Za-z0-9][A-Za-z0-9-]*: / { exit 1 }
        { fields++; last = substr($1, 1, length($1)-1) }
        /^Filename: / { filenames++; if (NF != 2) exit 1; filename = $2 }
        /^SHA256: / { hashes++; if (NF != 2) exit 1; hash = $2 }
        END { finish() }
    ' "$tmp/Packages" > "$tmp/manifest" || fail 'invalid Packages index'
    while read -r name hash; do
        [ -f "$previous/$name" ] && [ ! -L "$previous/$name" ] || fail "missing or unsafe package: $name"
        cp "$previous/$name" "$tmp/packages/$name"
        actual=$(sha256sum "$tmp/packages/$name")
        [ "${actual%% *}" = "$hash" ] || fail "package checksum mismatch: $name"
    done < "$tmp/manifest"
fi

for file in "$new"/*.deb; do
    [ -e "$file" ] || [ -L "$file" ] || continue
    [ -f "$file" ] && [ ! -L "$file" ] || fail "unsafe new package: $file"
    name=${file##*/}
    case "$name" in [A-Za-z0-9]*) ;; *) fail "unsafe package name: $name";; esac
    case "$name" in *[!A-Za-z0-9.+_~:-]*) fail "unsafe package name: $name";; esac
    if [ -e "$tmp/packages/$name" ]; then
        cmp -s "$file" "$tmp/packages/$name" || fail "conflicting package: $name"
    else
        cp "$file" "$tmp/packages/$name"
    fi
done
publish=$(mktemp -d "${output}.retain.XXXXXXXX")
chmod 755 "$publish"
for file in "$tmp/packages"/*.deb; do
    [ -f "$file" ] || continue
    cp "$file" "$publish/${file##*/}"
done
mv -T "$publish" "$output"
publish=''
