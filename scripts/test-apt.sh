#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
package_dir=${PACKAGE_DIR:-"$root/out/debs"}
for tool in docker gpg dpkg-deb dpkg-scanpackages apt-ftparchive gzip; do
    command -v "$tool" >/dev/null 2>&1 || { echo "Missing required tool: $tool" >&2; exit 1; }
done
set -- "$package_dir"/*.deb
[ -f "$1" ] || { echo "No .deb packages in $package_dir" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM
mkdir -m 700 "$tmp/gnupg"
mkdir -p "$tmp/repo/valid" "$tmp/repo/tampered" "$tmp/repo/tampered-package" "$tmp/repo/expired"
mkdir -p "$tmp/probe/DEBIAN"
printf 'Package: apt-integration-probe\nVersion: 1\nArchitecture: all\nMaintainer: Test <test@example.invalid>\nDescription: Disposable APT verification probe\n' > "$tmp/probe/DEBIAN/control"
dpkg-deb --build "$tmp/probe" "$tmp/repo/valid/apt-integration-probe.deb" >/dev/null
export GNUPGHOME="$tmp/gnupg"
gpg --batch --pinentry-mode loopback --passphrase '' --quick-generate-key \
    'APT Integration Test <apt-test@example.invalid>' rsa2048 sign 0 >/dev/null 2>&1
gpg --batch --export > "$tmp/repo/key.gpg"
cp "$@" "$tmp/repo/valid/"
(
    cd "$tmp/repo/valid"
    dpkg-scanpackages --multiversion . /dev/null > Packages
    gzip -n -c Packages > Packages.gz
    apt-ftparchive release . > Release
    gpg --batch --yes --pinentry-mode loopback --passphrase '' --digest-algo SHA256 \
        --armor --detach-sign -o Release.gpg Release
)
cp -R "$tmp/repo/valid/." "$tmp/repo/tampered/"
printf '\nX-Tampered: yes\n' >> "$tmp/repo/tampered/Release"
cp -R "$tmp/repo/valid/." "$tmp/repo/tampered-package/"
printf 'modified\n' >> "$tmp/repo/tampered-package/apt-integration-probe.deb"
cp -R "$tmp/repo/valid/." "$tmp/repo/expired/"
printf 'Valid-Until: Mon, 01 Jan 2001 00:00:00 UTC\n' >> "$tmp/repo/expired/Release"
gpg --batch --yes --pinentry-mode loopback --passphrase '' --digest-algo SHA256 \
    --armor --detach-sign -o "$tmp/repo/expired/Release.gpg" "$tmp/repo/expired/Release"
chmod -R a+rX "$tmp/repo"

docker run --rm --network none --platform linux/386 \
    --mount "type=bind,src=$tmp/repo,dst=/repo,readonly" \
    -i debian/eol@sha256:bddcd5525189f4afeb098fba34e3131c1483fe7f54aebfad9befcb481bd8f9ed /bin/sh -s <<'CONTAINER'
set -eu
export LC_ALL=C
fail() { echo "APT integration test failed: $*" >&2; exit 1; }
[ "$(dpkg --print-architecture)" = i386 ] || fail 'client is not i386'
[ "$(cat /etc/debian_version)" = 7.11 ] || fail 'client is not Debian Wheezy 7.11'
rm -f /etc/apt/sources.list.d/*
apt-key add /repo/key.gpg >/dev/null

update_repo() {
    printf 'deb file:/repo/%s ./\n' "$1" > /etc/apt/sources.list
    rm -rf /var/lib/apt/lists/*
    mkdir -p /var/lib/apt/lists/partial
    update_status=0
    apt-get -o Acquire::Check-Valid-Until=true -o Debug::Acquire::gpgv=true update > "$2" 2>&1 || update_status=$?
}

update_repo valid /tmp/valid.log
cat /tmp/valid.log
grep -q 'GOODSIG' /tmp/valid.log || fail 'valid signature was not verified'
[ "$update_status" -eq 0 ] || fail 'valid update returned a failure status'
if grep -Eiq '(^|[[:space:]])(W:|E:)|BADSIG|NO_PUBKEY|ERRSIG' /tmp/valid.log; then
    fail 'valid repository produced an APT error or warning'
fi
find /var/lib/apt/lists -maxdepth 1 -type f -name '*Packages*' > /tmp/indexes
[ -s /tmp/indexes ] || fail 'valid package index was not loaded'
apt-get -y --download-only install apt-integration-probe > /tmp/install.log 2>&1 || {
    cat /tmp/install.log
    fail 'valid repository package was not authenticated'
}
rm -f /var/cache/apt/archives/apt-integration-probe*.deb

update_repo tampered-package /tmp/tampered-package.log
grep -q 'GOODSIG' /tmp/tampered-package.log || fail 'signed package index was not verified'
if apt-get -y --download-only install apt-integration-probe > /tmp/install.log 2>&1; then
    cat /tmp/install.log
    fail 'tampered package was accepted'
fi
echo 'Tampered package rejected'

update_repo tampered /tmp/tampered.log
cat /tmp/tampered.log
grep -q 'BADSIG' /tmp/tampered.log || fail 'tampered release did not produce BADSIG'
if apt-get -y --download-only install apt-integration-probe > /tmp/install.log 2>&1; then
    cat /tmp/install.log
    fail 'tampered repository package was accepted as authenticated'
fi
cat /tmp/install.log
grep -qi 'cannot be authenticated' /tmp/install.log || fail 'package was not rejected for lack of authentication'
echo 'Tampered Release rejected with BADSIG'

update_repo expired /tmp/expired.log
cat /tmp/expired.log
grep -q 'GOODSIG' /tmp/expired.log || fail 'expired release signature was not verified'
find /var/lib/apt/lists -maxdepth 1 -type f -name '*Packages*' > /tmp/indexes
if grep -Eqi 'release file.*expired' /tmp/expired.log && [ ! -s /tmp/indexes ]; then
    echo 'Expired Valid-Until: rejected'
elif [ -s /tmp/indexes ]; then
    fail 'expired Valid-Until was accepted by this APT client'
else
    fail 'expired release outcome was inconclusive'
fi
echo 'APT integration test completed'
CONTAINER
