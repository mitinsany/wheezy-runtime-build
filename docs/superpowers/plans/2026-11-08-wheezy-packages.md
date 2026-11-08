# Wheezy Runtime Packages

1. Pin upstream source repositories to release commits as Git submodules.
2. Build i386 dependencies, PHP and Apache in a pinned Wheezy build environment.
3. Build independently versioned gzip-compressed Debian packages with explicit dependencies and isolated runtime library names.
4. Test package installation, old-runtime isolation, PHP, Apache and SNMP in a clean Wheezy environment.
5. Generate and sign an APT repository only after the build and installation checks succeed; publish via GitHub Actions and Pages.
6. Document key management, supported scope, rebuilding and application compatibility limitations.

Never publish experimental binaries as a source build. Keep private data, credentials and server configuration out of this public repository.
