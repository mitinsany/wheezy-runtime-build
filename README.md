# Wheezy Runtime Build

Experimental source pins for building an isolated i386 runtime on Debian Wheezy.

**Status: experimental.** The source-build and release pipeline has passed its
isolated package and APT checks. Do not use these packages on production systems
without application compatibility and deployment testing.
The source submodules are pinned to specific upstream commits. Initialize them with:

```sh
git submodule update --init
```

Build experiments require Docker with i386 support, `curl`, `sha256sum`,
`patchelf` and `dpkg-deb`. The builder downloads the pinned archives of the
bootstrap generators Bison, re2c and Automake; runtime components are compiled
from the submodules. The APT HTTPS method uses the checksum-pinned Debian Wheezy
APT 0.9.7.9+deb7u7 source archive instead. Start an isolated component build with:

```sh
sh scripts/build.sh --component zlib
```

`sh scripts/build.sh` attempts the whole build; it fails rather than producing
packages if a component is missing or fails. `sh scripts/test-packages.sh`
installs generated packages in a disposable container. Build output is under
`out/` and is not committed.

The builder uses Debian's historical archive and disables expiry checks for
archived release metadata. It retains APT signature verification and pins the
historically signed Release files and i386 package indexes by SHA-256. Bootstrap
tool archives are checksum-pinned; their checksums have been cross-checked with
independent mirrors, but upstream signatures have not been verified. The scripts aim to make builds
repeatable, but bit-for-bit reproducibility has not been verified.

GitHub Actions signs APT metadata using a dedicated signing key. Releases require
`RELEASE_APPROVED` and a configured signing environment. The experimental archive
is available at https://mitinsany.github.io/wheezy-runtime-build/. APT clients on
Wheezy need specific TLS and key-bootstrap verification before use.
The optional `wr-apt-https` package installs a separate APT method; it does not
replace the system method. To opt in for a command, pass
`-o Dir::Bin::Methods=/usr/lib/wheezy-runtime/apt/methods` to `apt-get`.
Removing the package leaves the system HTTPS method unchanged. Do not disable
signature or `Valid-Until` checks for the runtime archive.
For the initial installation on a host without working HTTPS, obtain the package
and its dependencies on a trusted HTTPS-capable host, verify them against the
signed repository metadata using a separately trusted signing key, and transfer
the verified files. The package itself does not bootstrap repository trust.
Upgrading runtime components does not make the underlying OS supported or
secure. PHP 8.4 compatibility with existing applications is a separate concern.
