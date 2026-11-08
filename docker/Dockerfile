FROM debian/eol@sha256:bddcd5525189f4afeb098fba34e3131c1483fe7f54aebfad9befcb481bd8f9ed

RUN apt-get -o Acquire::Check-Valid-Until=false update && \
    printf '%s\n' \
      'bf3b1df44c6b8a752c270c22b0057af6fcb301b814f9c594e249f86ccaec6a63  /var/lib/apt/lists/archive.debian.org_debian_dists_wheezy_Release' \
      'a52b27ca2ac5b0b2bdbbae2444ca857c819b0116120df40dba2ee45d949381bd  /var/lib/apt/lists/archive.debian.org_debian-security_dists_wheezy_updates_Release' \
      '4ae2e7ccb87e74d8f2ca09fbc2641d2f9fedbc8b31a33c7cc81e3bac4d418714  /var/lib/apt/lists/archive.debian.org_debian_dists_wheezy_main_binary-i386_Packages.gz' \
      'cab43f54c0c371be2d938c7354cac5225e001bc1bd2b3cdaf2b88504080321d9  /var/lib/apt/lists/archive.debian.org_debian-security_dists_wheezy_updates_main_binary-i386_Packages.gz' | sha256sum -c - && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install \
      build-essential autoconf automake libtool pkg-config perl file xz-utils \
      libexpat1-dev libbz2-dev uuid-dev libdb-dev gawk ca-certificates \
      bison re2c tcl8.5 zlib1g-dev python && \
    rm -rf /var/lib/apt/lists/*
