#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/empty" "$tmp/packages" "$tmp/bin"
printf 'not a package\n' > "$tmp/packages/example.deb"
cat > "$tmp/bin/docker" <<'EOF'
#!/bin/sh
exit 42
EOF
chmod +x "$tmp/bin/docker"

if PACKAGE_DIR="$tmp/empty" sh "$root/scripts/test-packages.sh" >"$tmp/log" 2>&1; then
    echo 'Empty package directory unexpectedly succeeded' >&2
    exit 1
fi
if ! grep -q 'No .deb packages' "$tmp/log"; then
    echo 'Missing package diagnostic was not reported' >&2
    exit 1
fi

status=0
PATH="$tmp/bin:$PATH" PACKAGE_DIR="$tmp/packages" sh "$root/scripts/test-packages.sh" >"$tmp/log" 2>&1 || status=$?
if [ "$status" -ne 42 ]; then
    echo "Docker failure was not propagated: $status" >&2
    exit 1
fi
echo 'Package smoke-test launcher checks passed'
