#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -m 700 "$tmp/gnupg"
mkdir "$tmp/repo"
export GNUPGHOME="$tmp/gnupg"
gpg --batch --import "$root/site/archive-signing.asc" >/dev/null 2>&1
sh "$root/scripts/fetch-previous.sh" https://mitinsany.github.io/wheezy-runtime-build "$tmp/repo"
chmod -R a+rX "$tmp/repo"

docker run --rm --platform linux/386 \
    --mount "type=bind,src=$tmp/repo,dst=/repo,readonly" \
    --mount "type=bind,src=$root/site/archive-signing.asc,dst=/tmp/archive-key.asc,readonly" \
    -i debian/eol@sha256:bddcd5525189f4afeb098fba34e3131c1483fe7f54aebfad9befcb481bd8f9ed /bin/sh -s <<'CONTAINER'
set -eu
export LC_ALL=C DEBIAN_FRONTEND=noninteractive
apt-get -o Acquire::Check-Valid-Until=false update
apt-get -y install ca-certificates libstdc++6 libgcc1
apt-key add /tmp/archive-key.asc
printf 'deb file:/repo ./\n' > /tmp/bootstrap.list
apt-get -o Dir::Etc::sourcelist=/tmp/bootstrap.list -o Dir::Etc::sourceparts=- \
    -o Acquire::Check-Valid-Until=true update
apt-get -y -o Dir::Etc::sourcelist=/tmp/bootstrap.list -o Dir::Etc::sourceparts=- \
    -o Acquire::Check-Valid-Until=true install wr-apt-https
printf 'deb https://mitinsany.github.io/wheezy-runtime-build/ ./\n' > /tmp/runtime.list
mkdir -p /tmp/runtime-lists/partial
apt-get -o Dir::Bin::Methods=/usr/lib/wheezy-runtime/apt/methods \
    -o Dir::Etc::sourcelist=/tmp/runtime.list -o Dir::Etc::sourceparts=- \
    -o Dir::State::lists=/tmp/runtime-lists -o Acquire::Check-Valid-Until=true update
apt-cache -o Dir::Etc::sourcelist=/tmp/runtime.list -o Dir::Etc::sourceparts=- \
    -o Dir::State::lists=/tmp/runtime-lists policy wr-apt-https > /tmp/runtime-policy
cat /tmp/runtime-policy
grep -q 'https://mitinsany.github.io/wheezy-runtime-build/' /tmp/runtime-policy
echo 'Wheezy HTTPS bootstrap succeeded'
CONTAINER
