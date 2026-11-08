#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin" "$tmp/repo" "$tmp/gnupg"
export GNUPGHOME="$tmp/gnupg" MOCK_REPO="$tmp/repo" MOCK_LOG="$tmp/curl.log"
PATH="$tmp/bin:$PATH"; export PATH
cat > "$tmp/bin/curl" <<'EOF'
#!/bin/sh
out= url= proto= redirect=
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output) out=$2; shift 2 ;;
        --write-out) shift 2 ;;
        --proto) proto=$2; shift 2 ;;
        --proto-redir) redirect=$2; shift 2 ;;
        --) shift; url=$1; shift ;;
        *) shift ;;
    esac
done
[ "$proto" = '=https' ] && [ "$redirect" = '=https' ] || exit 2
printf '%s\n' "$url" >> "$MOCK_LOG"
case "$url" in https://example.test/repo/*) name=${url#https://example.test/repo/} ;; *) exit 2 ;; esac
if [ "${MOCK_ERROR:-}" = "$name" ]; then printf 500; exit 22; fi
if [ "${MOCK_REDIRECT:-}" = "$name" ]; then printf 302; exit 0; fi
if [ ! -f "$MOCK_REPO/$name" ]; then printf 404; exit 22; fi
cp "$MOCK_REPO/$name" "$out"
printf 200
EOF
cat > "$tmp/bin/gpg" <<'EOF'
#!/bin/sh
[ "${MOCK_BAD_SIGNATURE:-0}" = 0 ] && [ "$1" = '--no-options' ] && [ "$2" = '--batch' ] && [ "$3" = '--no-auto-key-retrieve' ] && [ "$4" = '--verify' ] && [ -s "$5" ] && [ -s "$6" ]
EOF
chmod +x "$tmp/bin/curl" "$tmp/bin/gpg"
release() {
    hash=$(sha256sum "$tmp/repo/Packages" | awk '{print $1}')
    size=$(wc -c < "$tmp/repo/Packages" | tr -d ' ')
    printf 'Origin: Test\nSHA256:\n %s %s Packages\n' "$hash" "$size" > "$tmp/repo/Release"
    printf 'signature\n' > "$tmp/repo/Release.gpg"
}
package() {
    printf 'deb content\n' > "$tmp/repo/good_1.deb"
    hash=$(sha256sum "$tmp/repo/good_1.deb" | awk '{print $1}')
    size=$(wc -c < "$tmp/repo/good_1.deb" | tr -d ' ')
    printf 'Package: good\nFilename: %s\nSize: %s\nSHA256: %s\n\n' "$1" "$size" "$hash" > "$tmp/repo/Packages"
    release
}
run() { sh "$root/scripts/fetch-previous.sh" "$1" "$tmp/output" > "$tmp/log" 2>&1; }
fail() { printf 'FAIL: %s\n' "$1" >&2; cat "$tmp/log" >&2; exit 1; }
reset_output() { rm -rf "$tmp/output"; : > "$tmp/curl.log"; }
package ./good_1.deb
run https://example.test/repo || fail 'valid snapshot rejected'
cmp "$tmp/repo/good_1.deb" "$tmp/output/good_1.deb" || fail 'package differs'
for name in Release Release.gpg Packages; do cmp "$tmp/repo/$name" "$tmp/output/$name" || fail "missing $name"; done
reset_output
run http://example.test/repo && fail 'HTTP accepted'
[ ! -s "$tmp/curl.log" ] || fail 'HTTP attempted'
reset_output
MOCK_BAD_SIGNATURE=1; export MOCK_BAD_SIGNATURE
run https://example.test/repo && fail 'bad signature accepted'
unset MOCK_BAD_SIGNATURE
! grep -q '/Packages$' "$tmp/curl.log" || fail 'Packages fetched before signature verification'
reset_output
printf 'tampered\n' >> "$tmp/repo/Packages"
run https://example.test/repo && fail 'tampered Packages accepted'
! grep -q '\.deb$' "$tmp/curl.log" || fail 'package fetched before index verification'
reset_output
package ./../escape.deb
run https://example.test/repo && fail 'traversal accepted'
! grep -q '\.deb$' "$tmp/curl.log" || fail 'unsafe package requested'
reset_output
package ./good_1.deb
printf 'tampered\n' >> "$tmp/repo/good_1.deb"
run https://example.test/repo && fail 'tampered package accepted'
[ ! -e "$tmp/output/good_1.deb" ] || fail 'unverified package published'
reset_output
package ./good_1.deb
MOCK_ERROR=Packages; export MOCK_ERROR
run https://example.test/repo && fail 'server error accepted'
unset MOCK_ERROR
reset_output
MOCK_REDIRECT=Release; export MOCK_REDIRECT
run https://example.test/repo && fail 'unresolved redirect accepted'
unset MOCK_REDIRECT
reset_output
rm "$tmp/repo/Release"
run https://example.test/repo && fail 'missing release accepted by default'
ALLOW_EMPTY=1; export ALLOW_EMPTY
run https://example.test/repo || fail 'explicit empty release rejected'
unset ALLOW_EMPTY
printf 'fetch previous ok\n'
