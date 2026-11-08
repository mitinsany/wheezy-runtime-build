# Wheezy Runtime Build

Experimental source pins for building an isolated i386 runtime on Debian Wheezy.

**Status: work in progress.** There is no automated build, APT repository or
production-ready package in this repository yet. The source submodules are pinned
to specific upstream commits. They can be initialized with:

```sh
git submodule update --init --recursive
```

The intended output is a reproducible build pipeline and signed APT repository.
Upgrading individual runtime components does not make the underlying operating
system supported or secure. No package installation or deployment is performed
by this repository at present.
