#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
export GNUPGHOME="$tmp/gnupg"
mkdir -m 700 "$GNUPGHOME"
gpg --batch --quiet --passphrase '' --quick-generate-key 'Retention test <test@example.invalid>' default sign 1d
mkdir "$tmp/previous" "$tmp/new" "$tmp/output"
script="$root/scripts/retain-packages.sh"

run() { sh "$script" "$tmp/previous" "$tmp/new" "$tmp/output"; }
reject() {
    if run >"$tmp/log" 2>&1; then
        echo "Unexpected acceptance: $1" >&2
        exit 1
    fi
    test -z "$(ls -A "$tmp/output")" || { echo "Output changed on failure: $1" >&2; exit 1; }
}
sign_index() {
    (cd "$tmp/previous" && apt-ftparchive release . > Release)
    gpg --batch --quiet --yes --armor --detach-sign -o "$tmp/previous/Release.gpg" "$tmp/previous/Release"
}
printf 'new package\n' > "$tmp/new/new_1_all.deb"
run
cmp "$tmp/new/new_1_all.deb" "$tmp/output/new_1_all.deb"
rm "$tmp/output/new_1_all.deb"

# apt-ftparchive needs valid .deb metadata, so construct the mock index directly.
printf 'old package\n' > "$tmp/previous/old_1_all.deb"
hash=$(sha256sum "$tmp/previous/old_1_all.deb" | awk '{print $1}')
printf 'Package: old\nFilename: ./old_1_all.deb\nSHA256: %s\n\n' "$hash" > "$tmp/previous/Packages"
sign_index
printf 'unindexed\n' > "$tmp/previous/secret.deb"
run
cmp "$tmp/previous/old_1_all.deb" "$tmp/output/old_1_all.deb"
cmp "$tmp/new/new_1_all.deb" "$tmp/output/new_1_all.deb"
test ! -e "$tmp/output/secret.deb"
rm "$tmp/output/old_1_all.deb" "$tmp/output/new_1_all.deb"

printf 'tampered\n' >> "$tmp/previous/Release"
reject signature
sign_index
printf 'tampered\n' >> "$tmp/previous/Packages"
reject index
printf 'Package: old\nFilename: ./old_1_all.deb\nSHA256: %s\n\n' "$hash" > "$tmp/previous/Packages"
sign_index
printf 'tampered\n' >> "$tmp/previous/old_1_all.deb"
reject package
printf 'old package\n' > "$tmp/previous/old_1_all.deb"
printf 'different\n' > "$tmp/new/old_1_all.deb"
reject conflict
cp "$tmp/previous/old_1_all.deb" "$tmp/new/old_1_all.deb"
run
rm "$tmp/output/old_1_all.deb" "$tmp/output/new_1_all.deb" "$tmp/new/old_1_all.deb"
printf 'Package: old\nFilename: ./../escape.deb\nSHA256: %s\n\n' "$hash" > "$tmp/previous/Packages"
sign_index
reject traversal
printf 'Package: old\nFilename: ./old_1_all.deb\nFilename: ./secret.deb\nSHA256: %s\n\n' "$hash" > "$tmp/previous/Packages"
sign_index
reject duplicate-field
printf 'Package: old\nFilename: ./old_1_all.deb\nSHA256: %s\n\n' "$hash" > "$tmp/previous/Packages"
sign_index
mv "$tmp/previous/Release.gpg" "$tmp/signature"
reject missing-signature
mv "$tmp/signature" "$tmp/previous/Release.gpg"
mv "$tmp/previous/old_1_all.deb" "$tmp/old"
ln -s "$tmp/old" "$tmp/previous/old_1_all.deb"
reject symlink-package
rm "$tmp/previous/old_1_all.deb"
mv "$tmp/old" "$tmp/previous/old_1_all.deb"
ln -s "$tmp/old" "$tmp/new/link_1_all.deb"
reject symlink-new-package
rm "$tmp/new/link_1_all.deb"
mkdir -m 700 "$tmp/untrusted"
GNUPGHOME="$tmp/untrusted" gpg --batch --quiet --passphrase '' --quick-generate-key 'Other <other@example.invalid>' default sign 1d
GNUPGHOME="$tmp/untrusted" gpg --batch --quiet --yes --armor --detach-sign -o "$tmp/previous/Release.gpg" "$tmp/previous/Release"
reject untrusted-signature
sign_index
printf 'SHA256:\n' > "$tmp/previous/Release"
gpg --batch --quiet --yes --armor --detach-sign -o "$tmp/previous/Release.gpg" "$tmp/previous/Release"
reject missing-index-hash
echo 'retain-packages tests passed'
