# Wheezy Runtime Build

Experimental source pins for building an isolated i386 runtime on Debian Wheezy.

**Status: work in progress.** The source-build and release pipeline has not yet
passed end-to-end verification. Do not use these packages on production systems.
The source submodules are pinned to specific upstream commits. Initialize them with:

```sh
git submodule update --init
```

Build experiments require Docker with i386 support, `curl`, `sha256sum`,
`patchelf` and `dpkg-deb`. The builder downloads the pinned archives of the
bootstrap generators Bison, re2c and Automake; runtime components are compiled
from the submodules. Start an isolated component build with:

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

The proposed GitHub Actions flow signs APT metadata using a dedicated signing
key, but release is disabled unless `RELEASE_APPROVED` is explicitly set and the
signing environment is configured. APT clients on Wheezy need specific TLS and
key-bootstrap verification. The archive is not configured or published yet.
Upgrading runtime components does not make the underlying OS supported or
secure. PHP 8.4 compatibility with existing applications is a separate concern.
